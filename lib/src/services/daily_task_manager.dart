import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import '../sync/sync_service.dart';
import '../providers/notifications_provider.dart';

class DailyTaskManager {
  static final DailyTaskManager _instance = DailyTaskManager._internal();
  factory DailyTaskManager() => _instance;
  DailyTaskManager._internal();

  bool _isInitialized = false;
  Timer? _connectivityTimer;
  StreamSubscription<SyncResult>? _syncSubscription;

  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _lastNoInternetNotificationKey = 'last_no_internet_notification_date';
  static const Duration _retryInterval = Duration(minutes: 20);

  Future<void> initialize() async {
    if (_isInitialized) return;

    _syncSubscription ??= SyncService.onSyncComplete.listen((result) {
      if (result.success) {
        _cancelConnectivityTimer();
      }
    });

    _isInitialized = true;
  }

  Future<void> checkOnAppOpen() async {
    if (!_isInitialized) await initialize();

    final now = DateTime.now();

    try {
      if (now.hour >= 2) {
        await _performRecoveryCheck();
      } else if (now.hour == 0 || now.hour == 1) {
        if (await _needsSyncToday()) {
          await _performRecoveryCheck();
        }
      }
    } catch (e) {
    }
  }

  Future<void> _performRecoveryCheck() async {

    if (!await _needsSyncToday()) {
      return;
    }

    final hasInternet = await _checkConnectivity();

    if (hasInternet) {
      await _executeRecovery();
    } else {
      _startConditionalTimer();
    }
  }

  Future<void> _executeRecovery() async {
    try {
      final success = await _performSyncTask();

      if (success) {
        _cancelConnectivityTimer();
      } else {
      }
    } catch (e) {
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final hasInternet = await InternetConnection().hasInternetAccess;

      if (!hasInternet) {
        await _notifyNoInternetIfNeeded();
      }

      return hasInternet;
    } catch (e) {
      await _notifyNoInternetIfNeeded();
      return false;
    }
  }

  Future<void> _notifyNoInternetIfNeeded() async {
    try {
      if (await _shouldNotifyNoInternet()) {
        final notificationsProvider = NotificationsProvider.instance;

        notificationsProvider.addNotification(
          title: 'Sin conexión a internet',
          message: 'Se reintentará automáticamente cada 20 minutos',
          type: 'no_internet',
        );

        await _markNoInternetNotified();
      }
    } catch (e) {
    }
  }

  Future<bool> _shouldNotifyNoInternet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastNotificationDate = prefs.getString(_lastNoInternetNotificationKey);
      final today = _getTodayString();

      return lastNotificationDate != today;
    } catch (e) {
      return false;
    }
  }

  Future<void> _markNoInternetNotified() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayString();
      await prefs.setString(_lastNoInternetNotificationKey, today);
    } catch (e) {
    }
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _startConditionalTimer() {
    _cancelConnectivityTimer();

    final now = DateTime.now();

    _connectivityTimer = Timer.periodic(_retryInterval, (timer) async {
      final currentHour = DateTime.now().hour;

      if (currentHour >= 1) {
        await _performRecoveryCheck();
        _cancelConnectivityTimer();
      } else {
      }
    });
  }

  void _cancelConnectivityTimer() {
    if (_connectivityTimer != null) {
      _connectivityTimer!.cancel();
      _connectivityTimer = null;
    }
  }

  Future<bool> _performSyncTask() async {
    try {
      final syncResult = await SyncService().performAutoSync();
      return syncResult.success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _needsSyncToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString(_lastSyncKey);
      final now = DateTime.now();

      if (lastSyncString == null) {
        return true;
      }

      final lastSync = DateTime.parse(lastSyncString);
      final hoursSinceLastSync = now.difference(lastSync).inHours;

      if (now.hour == 0 && hoursSinceLastSync >= 24) {
        return true;
      }

      final today = DateTime(now.year, now.month, now.day);
      final lastSyncDay = DateTime(lastSync.year, lastSync.month, lastSync.day);

      if (today.isAfter(lastSyncDay) && now.hour >= 1) {
        return true;
      }

      return false;
    } catch (e) {
      return true;
    }
  }

  void onAppPause() {
    _cancelConnectivityTimer();
  }

  void onAppResume() {
  }

  Future<void> testExecuteRecovery() async {
    await _performRecoveryCheck();
  }

  void testStartTimer() {
    _startConditionalTimer();
  }

  Map<String, dynamic> getTimerState() {
    final now = DateTime.now();

    if (_connectivityTimer == null) {
      return {
        'status': 'TIMER DESACTIVADO',
        'active': false,
        'next_check': null,
        'cycles_completed': 0,
        'last_connectivity_check': null,
      };
    }

    final nextCheckApprox = '~${_retryInterval.inMinutes}min';

    return {
      'status': 'TIMER CORRIENDO - Próximo: $nextCheckApprox',
      'active': true,
      'interval_minutes': _retryInterval.inMinutes,
      'current_hour': now.hour,
      'timer_valid_window': now.hour < 1 ? 'SÍ' : 'NO (hora >= 1am)',
    };
  }

  Map<String, dynamic> getDebugState() {
    final now = DateTime.now();
    return {
      'initialized': _isInitialized,
      'workmanager_active': false,
      'connectivity_timer_active': _connectivityTimer != null,
      'current_time': '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      'today': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'approach': 'connectivity_based_recovery',
    };
  }

  void dispose() {
    _cancelConnectivityTimer();
    _syncSubscription?.cancel();
    _syncSubscription = null;
    _isInitialized = false;
  }
}