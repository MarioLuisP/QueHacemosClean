import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class EventRepository {
  static final EventRepository _instance = EventRepository._internal();
  factory EventRepository() => _instance;
  EventRepository._internal();

  Future<List<Map<String, dynamic>>> getAllEvents() async {
    final db = await DatabaseHelper.database;
    return await db.query(
      'eventos',
      orderBy: 'date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getEventsByCategory(String category) async {
    final db = await DatabaseHelper.database;
    return await db.query(
      'eventos',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> searchEvents(String query) async {
    final db = await DatabaseHelper.database;
    return await db.query(
      'eventos',
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getEventsByDate(String date) async {
    final db = await DatabaseHelper.database;
    return await db.query(
      'eventos',
      where: 'DATE(date) = ?',
      whereArgs: [date],
      orderBy: 'date ASC',
    );
  }
  Future<Map<String, int>> getEventCountsForDateRange(String startDate, String endDate) async {
    final db = await DatabaseHelper.database;
    final results = await db.rawQuery('''
      SELECT DATE(date) as day, COUNT(*) as count 
      FROM eventos 
      WHERE DATE(date) BETWEEN ? AND ? 
      GROUP BY DATE(date)
    ''', [startDate, endDate]);

    final Map<String, int> counts = {};
    for (final row in results) {
      counts[row['day']?.toString() ?? ''] = (row['count'] is int)
          ? row['count'] as int
          : int.tryParse(row['count']?.toString() ?? '') ?? 0;
    }

    return counts;
  }

  Future<Map<String, dynamic>?> getEventById(int id) async {
    final db = await DatabaseHelper.database;
    final results = await db.query(
      'eventos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertEvents(List<Map<String, dynamic>> events) async {
    final db = await DatabaseHelper.database;
    final batch = db.batch();

    for (var event in events) {
      batch.insert(
        'eventos',
        event,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }
  Future<Map<String, int>> cleanOldEvents() async {
    final db = await DatabaseHelper.database;

    final eventsDays = await getCleanupDays('cleanup_events_days');
    final favoritesDays = await getCleanupDays('cleanup_favorites_days');

    final events_cutoff = DateTime.now().subtract(Duration(days: eventsDays));
    final favorites_cutoff = DateTime.now().subtract(Duration(days: favoritesDays));

    final normalDeleted = await db.delete(
      'eventos',
      where: 'DATE(date) < ? AND (favorite = ? OR favorite = ?)',
      whereArgs: [events_cutoff.toIso8601String().split('T')[0], 0, "FALSE"],
    );

    final favoritesDeleted = await db.delete(
      'eventos',
      where: 'DATE(date) < ? AND (favorite = ? OR favorite = ?)',
      whereArgs: [favorites_cutoff.toIso8601String().split('T')[0], 1, "TRUE"],
    );

    return {
      'normalEvents': normalDeleted,
      'favoriteEvents': favoritesDeleted,
      'total': normalDeleted + favoritesDeleted,
    };
  }

  Future<int> removeDuplicatesByCodes() async {
    final db = await DatabaseHelper.database;

    final deletedDuplicates = await db.rawDelete('''              
        DELETE FROM eventos 
        WHERE id NOT IN (
          SELECT MAX(id) 
          FROM eventos 
          GROUP BY code
          HAVING code IS NOT NULL
        ) 
        AND code IS NOT NULL
      ''');

    return deletedDuplicates;
  }
  Future<List<Map<String, dynamic>>> getAllFavorites() async {
    final db = await DatabaseHelper.database;
    return await db.query(
      'eventos',
      where: 'favorite = ?',
      whereArgs: [1],
      orderBy: 'date ASC',
    );
  }

  Future<bool> favorite(int eventoId) async {
    final db = await DatabaseHelper.database;
    final results = await db.query(
      'eventos',
      where: 'id = ?',
      whereArgs: [eventoId],
      limit: 1,
    );
    if (results.isEmpty) return false;
    final int rawValue = (results.first['favorite'] is int)
        ? results.first['favorite'] as int
        : int.tryParse(results.first['favorite']?.toString() ?? '') ?? 0;
    return rawValue == 1;
  }
  Future<void> addToFavorites(int eventoId) async {
    final db = await DatabaseHelper.database;

    await db.update(
      'eventos',
      {'favorite': 1},
      where: 'id = ?',
      whereArgs: [eventoId],
    );
  }

  Future<void> removeFromFavorites(int eventoId) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'eventos',
      {'favorite': 0},
      where: 'id = ?',
      whereArgs: [eventoId],
    );
  }

  Future<bool> toggleFavorite(int eventoId) async {
    final isFav = await favorite(eventoId);

    if (isFav) {
      await removeFromFavorites(eventoId);
      return false;
    } else {
      await addToFavorites(eventoId);
      return true;
    }
  }

  Future<String?> getSetting(String key) async {
    final db = await DatabaseHelper.database;
    final results = await db.query(
      'app_settings',
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return results.isNotEmpty ? results.first['setting_value'] as String : null;
  }

  Future<void> updateSetting(String key, String value) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'app_settings',
      {
        'setting_value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'setting_key = ?',
      whereArgs: [key],
    );
  }

  Future<int> getCleanupDays(String settingKey) async {
    final value = await getSetting(settingKey);
    return value != null ? int.parse(value) : (settingKey.contains('events') ? 3 : 7);
  }

  Future<Map<String, dynamic>?> getSyncInfo() async {
    final db = await DatabaseHelper.database;
    final results = await db.query('sync_info', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateSyncInfo({
    required String batchVersion,
    required int totalEvents,
  }) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'sync_info',
      {
        'last_sync': DateTime.now().toIso8601String(),
        'batch_version': batchVersion,
        'total_events': totalEvents,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<int> getTotalEvents() async {
    final db = await DatabaseHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM eventos');
    return result.first['count'] as int;
  }

  Future<int> getTotalFavorites() async {
    final db = await DatabaseHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM eventos WHERE favorite = 1');
    return result.first['count'] as int;
  }

  Future<int> insertNotification({
    required String title,
    required String message,
    required String type,
    String? eventCode,
    String? scheduledDatetime,
    int? localNotificationId,
  }) async {
    final db = await DatabaseHelper.database;

    return await db.insert('notifications', {
      'title': title,
      'message': message,
      'type': type,
      'event_code': eventCode,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': 0,
      'scheduled_datetime': scheduledDatetime,
      'local_notification_id': localNotificationId,
    });
  }

  Future<List<Map<String, dynamic>>> getAllNotifications({
    bool unreadOnly = false,
  }) async {
    final db = await DatabaseHelper.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (unreadOnly) {
      whereClause = 'WHERE is_read = ?';
      whereArgs = [0];
    }

    return await db.rawQuery('''                   
      SELECT * FROM notifications 
      $whereClause
      ORDER BY created_at DESC
    ''', whereArgs);
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    final db = await DatabaseHelper.database;

    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  Future<void> markAllNotificationsAsRead() async {
    final db = await DatabaseHelper.database;

    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'is_read = ?',
      whereArgs: [0],
    );
  }

  Future<void> deleteNotification(int notificationId) async {
    final db = await DatabaseHelper.database;

    await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  Future<void> clearAllNotifications() async {
    final db = await DatabaseHelper.database;
    await db.delete('notifications');
  }

  Future<int> getUnreadNotificationsCount() async {
    final db = await DatabaseHelper.database;

    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notifications WHERE is_read = 0'
    );

    return result.first['count'] as int;
  }

  Future<List<Map<String, dynamic>>> getPendingScheduledNotifications() async {
    final db = await DatabaseHelper.database;

    return await db.query(
      'notifications',
      where: 'scheduled_datetime IS NOT NULL AND is_read = 0',
      orderBy: 'scheduled_datetime ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getNotificationsByEventCode(String eventCode) async {
    final db = await DatabaseHelper.database;

    return await db.query(
      'notifications',
      where: 'event_code = ? AND is_read = 0',
      whereArgs: [eventCode],
    );
  }

  Future<void> clearAllData() async {
    final db = await DatabaseHelper.database;
    final batch = db.batch();

    batch.delete('eventos');
    batch.update('sync_info', {
      'last_sync': null,
      'batch_version': '',
      'total_events': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [1]);

    await batch.commit(noResult: true);
  }
}