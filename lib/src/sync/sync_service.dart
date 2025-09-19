import 'dart:async';
import '../data/repositories/event_repository.dart';
import '../data/database/database_helper.dart';
import '../providers/notifications_provider.dart';
import 'firestore_client.dart';
import '../providers/simple_home_provider.dart';

class SyncService {
  SimpleHomeProvider? _homeProvider;
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  void setHomeProvider(SimpleHomeProvider provider) {
    _homeProvider = provider;
  }

  static final StreamController<SyncResult> _syncCompleteController =
  StreamController<SyncResult>.broadcast();

  static Stream<SyncResult> get onSyncComplete => _syncCompleteController.stream;

  final EventRepository _eventRepository = EventRepository();
  final FirestoreClient _firestoreClient = FirestoreClient();
  NotificationsProvider get _notificationsProvider => NotificationsProvider.instance;

  bool _isSyncing = false;
  static bool _globalSyncInProgress = false;

  Future<SyncResult> performAutoSync() async {

    if (_isSyncing) {
      return SyncResult.notNeeded();
    }


    if (!await _firestoreClient.shouldSync()) {
      return SyncResult.notNeeded();
    }


    _isSyncing = true;
    _globalSyncInProgress = true;

    try {
      final syncStatus = await _firestoreClient.getSyncStatus();
      final currentBatchVersion = syncStatus['batchVersion'] as String?;
      final events = await _firestoreClient.downloadDailyBatches();


      if (events.isEmpty) {
        _notificationsProvider.addNotification(
          title: '✅ Todo actualizado',
          message: 'La app está al día, no hay eventos nuevos',
          type: 'sync_up_to_date',
        );
        return SyncResult.noNewData();
      }

      final eventCountBefore = await _eventRepository.getTotalEvents();

      await _processEvents(events);
      final cleanupResults = await _performCleanup();

      await _firestoreClient.updateSyncTimestamp();

      final newBatchVersion = await _getNewBatchVersion();
      final isSameBatch = currentBatchVersion != null &&
          newBatchVersion != null &&
          currentBatchVersion == newBatchVersion;

      if (isSameBatch) {
        _notificationsProvider.addNotification(
          title: '✅ Todo actualizado',
          message: 'La app está al día, no hay eventos nuevos',
          type: 'sync_up_to_date',
        );
      } else {
        final eventCountAfter = await _eventRepository.getTotalEvents();
        final netChange = eventCountAfter - eventCountBefore;

        if (netChange > 0) {
          await _sendSyncNotifications(netChange, cleanupResults);
        } else {
          _notificationsProvider.addNotification(
            title: '✅ Todo actualizado',
            message: 'La app está al día, no hay eventos nuevos',
            type: 'sync_up_to_date',
          );
        }
      }

      if (_homeProvider != null) {
        _homeProvider!.refresh();
      }

      final result = SyncResult.success(
        eventsAdded: events.length,
        eventsRemoved: cleanupResults.eventsRemoved,
        favoritesRemoved: cleanupResults.favoritesRemoved,
      );
      _syncCompleteController.add(result);
      return result;

    } catch (e) {
      return SyncResult.error(e.toString());
    } finally {
      _isSyncing = false;
      _globalSyncInProgress = false;
    }
  }

  Future<SyncResult> forceSync() async {
    return await performAutoSync();
  }

  Future<void> _processEvents(List<Map<String, dynamic>> completeBatches) async {
    if (completeBatches.length > 1) {

      completeBatches.sort((a, b) {
        final fechaA = a['metadata']?['fecha_subida'] as String? ?? '';
        final fechaB = b['metadata']?['fecha_subida'] as String? ?? '';
        return fechaA.compareTo(fechaB);
      });


      for (int i = 0; i < completeBatches.length; i++) {
        final batch = completeBatches[i];
        final eventos = (batch['eventos'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ?? [];

        final nombreLote = batch['metadata']?['nombre_lote'] ?? 'lote_${i + 1}';

        if (eventos.isNotEmpty) {
          await _eventRepository.insertEvents(eventos);
          await _eventRepository.removeDuplicatesByCodes();
          await _eventRepository.cleanOldEvents();
        }
      }

    } else {

      final allEvents = <Map<String, dynamic>>[];
      for (final batch in completeBatches) {
        final eventos = (batch['eventos'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ?? [];
        allEvents.addAll(eventos);
      }

      await _eventRepository.insertEvents(allEvents);
    }
  }

  Future<CleanupResult> _performCleanup() async {
    final cleanupStats = await _eventRepository.cleanOldEvents();
    final duplicatesRemoved = await _eventRepository.removeDuplicatesByCodes();

    return CleanupResult(
      eventsRemoved: cleanupStats['normalEvents']! + duplicatesRemoved,
      favoritesRemoved: cleanupStats['favoriteEvents']!,
      duplicatesRemoved: duplicatesRemoved,
    );
  }

  Future<Map<String, dynamic>> getSyncStatus() async {
    return await _firestoreClient.getSyncStatus();
  }

  Future<CleanupResult> forceCleanup() async {
    return await _performCleanup();
  }

  Future<void> resetSync() async {
    await _firestoreClient.resetSyncState();
    await _eventRepository.clearAllData();
  }

  Future<void> _sendSyncNotifications(int newEventsCount, CleanupResult cleanupResults) async {
    try {
      if (newEventsCount > 0) {
        final notificationsProvider = _notificationsProvider;

        notificationsProvider.addNotification(
          title: '🎭 ¡Eventos nuevos en Córdoba!',
          message: 'Se agregaron $newEventsCount eventos culturales',
          type: 'new_events',
        );

        if (newEventsCount >= 10) {
          notificationsProvider.addNotification(
            title: '🔥 ¡Semana cargada de cultura!',
            message: 'Más de $newEventsCount eventos esperándote',
            type: 'high_activity',
          );
        }

        if (cleanupResults.eventsRemoved > 5) {
          notificationsProvider.addNotification(
            title: '🗑️ Base de datos optimizada',
            message: 'Se limpiaron ${cleanupResults.eventsRemoved} eventos pasados',
            type: 'cleanup',
          );
        }
      }
    } catch (e) {}
  }

  Future<void> _maintainNotificationSchedules() async {
    try {
      final pendingNotifications = await _eventRepository.getPendingScheduledNotifications();

      for (final notification in pendingNotifications) {
        final eventCode = notification['event_code'] as String?;

        if (eventCode == null) continue;

        final db = await DatabaseHelper.database;
        final eventResults = await db.query(
          'eventos',
          where: 'code = ?',
          whereArgs: [eventCode],
          limit: 1,
        );

        if (eventResults.isEmpty) {
          await _eventRepository.deleteNotification(notification['id'] as int);
          continue;
        }

        final event = eventResults.first;
        final currentEventDate = event['date'] as String;
        final notificationScheduled = notification['scheduled_datetime'] as String?;

        if (notificationScheduled != null) {
          final newScheduledTime = _calculateScheduledTime(
            currentEventDate,
            notification['type'] as String,
          );

          if (newScheduledTime != notificationScheduled) {
            await db.update(
              'notifications',
              {'scheduled_datetime': newScheduledTime},
              where: 'id = ?',
              whereArgs: [notification['id']],
            );
          }
        }
      }
    } catch (e) {}
  }

  String? _calculateScheduledTime(String eventDate, String notificationType) {
    try {
      final eventDateTime = DateTime.parse(eventDate);

      switch (notificationType) {
        case 'event_reminder_tomorrow':
          return eventDateTime.subtract(Duration(days: 1, hours: 6)).toIso8601String();
        case 'event_reminder_today':
          return DateTime(eventDateTime.year, eventDateTime.month, eventDateTime.day, 9).toIso8601String();
        case 'event_reminder_hour':
          return eventDateTime.subtract(Duration(hours: 1)).toIso8601String();
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }
  Future<String?> _getNewBatchVersion() async {
    final syncStatus = await _firestoreClient.getSyncStatus();
    return syncStatus['batchVersion'] as String?;
  }
}

class SyncResult {
  final bool success;
  final String? error;
  final int eventsAdded;
  final int eventsRemoved;
  final int favoritesRemoved;
  final SyncResultType type;

  SyncResult._({
    required this.success,
    this.error,
    this.eventsAdded = 0,
    this.eventsRemoved = 0,
    this.favoritesRemoved = 0,
    required this.type,
  });

  factory SyncResult.success({
    required int eventsAdded,
    required int eventsRemoved,
    required int favoritesRemoved,
  }) =>
      SyncResult._(
        success: true,
        eventsAdded: eventsAdded,
        eventsRemoved: eventsRemoved,
        favoritesRemoved: favoritesRemoved,
        type: SyncResultType.success,
      );

  factory SyncResult.notNeeded() => SyncResult._(
    success: true,
    type: SyncResultType.notNeeded,
  );

  factory SyncResult.noNewData() => SyncResult._(
    success: true,
    type: SyncResultType.noNewData,
  );

  factory SyncResult.error(String error) => SyncResult._(
    success: false,
    error: error,
    type: SyncResultType.error,
  );
}

enum SyncResultType { success, notNeeded, noNewData, error }

class CleanupResult {
  final int eventsRemoved;
  final int favoritesRemoved;
  final int duplicatesRemoved;

  CleanupResult({
    required this.eventsRemoved,
    required this.favoritesRemoved,
    required this.duplicatesRemoved,
  });
}