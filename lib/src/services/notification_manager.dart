import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import '../providers/favorites_provider.dart';
import '../models/user_preferences.dart';
import '../data/repositories/event_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final notificationsEnabled = await UserPreferences.getNotificationsReady();
    if (notificationsEnabled) {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        if (message.data['action'] == 'daily_recovery') {

          if (await _needsExecutionToday()) {
            await executeRecovery();
            await _markExecutedToday();
          } else {
          }
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        if (message.data['action'] == 'daily_recovery') {
          if (await _needsExecutionToday()) {
            await executeRecovery();
            await _markExecutedToday();
          } else {
          }
        }
      });

    }

    _isInitialized = true;
  }

  Future<void> checkOnAppOpen() async {
    if (!_isInitialized) await initialize();
    await _updateFlagsOnStartup();
    final notificationsReady = await UserPreferences.getNotificationsReady();
    if (notificationsReady) {
      final token = await FirebaseMessaging.instance.getToken();
    }
    final now = DateTime.now();

    try {
      if (now.hour >= 6 && await _needsExecutionToday()) {
        await executeRecovery();
        await _markExecutedToday();
      } else {
      }
    } catch (e) {
    }
  }

  Future<bool> executeRecovery() async {
    try {
      final ready = await UserPreferences.getNotificationsReady();
      if (!ready) {
        return true;
      }

      await NotificationService.waitForInitialization();

      final now = DateTime.now();
      final favoritesProvider = FavoritesProvider();

      if (now.hour >= 11) {
        await favoritesProvider.sendImmediateNotificationForToday();
      } else {
        await favoritesProvider.scheduleNotificationsForToday();
      }
      await _calculateTomorrowFavorites();
      return true;

    } catch (e) {
      return false;
    }
  }

  Future<bool> _needsExecutionToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastExecution = prefs.getString('last_notification_recovery');

      if (lastExecution == null) return true;

      final lastDate = DateTime.parse(lastExecution);
      final today = DateTime.now();

      return !_isSameDay(lastDate, today);
    } catch (e) {
      return true;
    }
  }

  Future<void> _markExecutedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_notification_recovery', DateTime.now().toIso8601String());
    } catch (e) {
    }
  }

  Future<void> _calculateTomorrowFavorites() async {
    try {
      final favoritesProvider = FavoritesProvider();
      await favoritesProvider.init();

      final repository = EventRepository();
      final favorites = await repository.getAllFavorites();

      final tomorrow = DateTime.now().add(Duration(days: 1)).toIso8601String().split('T')[0];

      bool hasFavorites = false;
      for (final favorite in favorites) {
        final dateStr = favorite['date']?.toString().split('T')[0];
        if (dateStr == tomorrow) {
          hasFavorites = true;
          break;
        }
      }

      await UserPreferences.setHasFavoritesForDate(tomorrow, hasFavorites);

    } catch (e) {
    }
  }
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
  Future<void> _updateFlagsOnStartup() async {
    try {


      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];
      final tomorrowStr = today.add(Duration(days: 1)).toIso8601String().split('T')[0];
      final dayAfterStr = today.add(Duration(days: 2)).toIso8601String().split('T')[0];
      await _cleanupOldFlags(todayStr);

      await _recalculateFlagForDate(todayStr);
      await _recalculateFlagForDate(tomorrowStr);
      await _recalculateFlagForDate(dayAfterStr);

    } catch (e) {
    }
  }
  Future<void> _cleanupOldFlags(String todayStr) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith('has_favorites_') && key != 'has_favorites_$todayStr') {
        final dateStr = key.replaceFirst('has_favorites_', '');
        if (dateStr.length == 10) {
          try {
            final date = DateTime.parse(dateStr);
            final today = DateTime.parse(todayStr);
            if (date.isBefore(today)) {
              await prefs.remove(key);
            }
          } catch (e) {
            await prefs.remove(key);
          }
        }
      }
    }
  }

  Future<void> _recalculateFlagForDate(String date) async {
    final repository = EventRepository();
    final favorites = await repository.getAllFavorites();

    final favoritesForDate = favorites.where((favorite) =>
    favorite['date']?.toString().split('T')[0] == date
    ).toList();

    await UserPreferences.setHasFavoritesForDate(date, favoritesForDate.isNotEmpty);
  }

  Future<void> testExecuteRecovery() async {
    await executeRecovery();
  }

  Future<void> resetRecoveryTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_notification_recovery');
  }

  Future<Map<String, dynamic>> getDebugState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastExecution = prefs.getString('last_notification_recovery');
    final needsExecution = await _needsExecutionToday();

    return {
      'initialized': _isInitialized,
      'current_time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      'notifications_ready': await UserPreferences.getNotificationsReady(),
      'last_recovery': lastExecution ?? 'never',
      'needs_execution': needsExecution,
      'hour_check': DateTime.now().hour >= 6,
    };
  }

  void dispose() {
  }
}