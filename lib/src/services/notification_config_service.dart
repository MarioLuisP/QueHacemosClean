import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'notification_service.dart';
import '../models/user_preferences.dart';
import 'notification_manager.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

enum NotificationConfigState {
  idle,
  detectingPlatform,
  requestingPermissions,
  initializingService,
  configuringWorkManager,
  savingPreferences,
  success,
  errorPermissionDenied,
  errorInitializationFailed,
  errorWorkManagerFailed,
  errorUnknown
}

class NotificationConfigurationService {
  static bool _isConfiguring = false;

  static Future<NotificationConfigState> configureNotifications() async {
    if (_isConfiguring) {
      return NotificationConfigState.idle;
    }

    _isConfiguring = true;

    try {

      final platformInfo = await _detectPlatform();
      if (platformInfo == null) {
        return _finishWithState(NotificationConfigState.errorUnknown);
      }

      final permissionsResult = await _handlePermissions(platformInfo);
      if (permissionsResult != NotificationConfigState.initializingService) {
        return _finishWithState(permissionsResult);
      }

      final initResult = await _initializeNotificationService();
      if (initResult != NotificationConfigState.configuringWorkManager) {
        return _finishWithState(initResult);
      }

      final workManagerResult = await _configureNotificationManager();
      if (workManagerResult != NotificationConfigState.savingPreferences) {
        return _finishWithState(workManagerResult);
      }

      final prefsResult = await _saveNotificationState();
      if (prefsResult != NotificationConfigState.success) {
        return _finishWithState(prefsResult);
      }
      final fcmResult = await _initializeFCM();
      if (fcmResult != NotificationConfigState.success) {
        return _finishWithState(fcmResult);
      }

      return _finishWithState(NotificationConfigState.success);

    } catch (e, stackTrace) {
      return _finishWithState(NotificationConfigState.errorUnknown);
    }
  }

  static NotificationConfigState _finishWithState(NotificationConfigState state) {
    _isConfiguring = false;
    return state;
  }

  static Future<_PlatformInfo?> _detectPlatform() async {
    try {

      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        if (sdkInt >= 33) {
          return _PlatformInfo(PlatformType.androidNew, sdkInt);
        } else {
          return _PlatformInfo(PlatformType.androidOld, sdkInt);
        }
      } else if (Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        return _PlatformInfo(PlatformType.ios, 0);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<NotificationConfigState> _handlePermissions(_PlatformInfo platformInfo) async {
    try {

      switch (platformInfo.type) {
        case PlatformType.androidOld:
          return NotificationConfigState.initializingService;

        case PlatformType.androidNew:
          return await _requestAndroidPermissions();

        case PlatformType.ios:
          return NotificationConfigState.initializingService;
      }
    } catch (e) {
      return NotificationConfigState.errorUnknown;
    }
  }

  static Future<NotificationConfigState> _requestAndroidPermissions() async {
    try {

      final android = NotificationService.resolveAndroid();
      if (android == null) {
        return NotificationConfigState.errorUnknown;
      }

      final permissionGranted = await android.requestNotificationsPermission();

      if (permissionGranted == true) {
        return NotificationConfigState.initializingService;
      } else if (permissionGranted == false) {
        return NotificationConfigState.errorPermissionDenied;
      } else {
        return NotificationConfigState.initializingService;
      }
    } catch (e) {
      return NotificationConfigState.errorPermissionDenied;
    }
  }

  static Future<NotificationConfigState> _initializeNotificationService() async {
    try {

      final initialized = await NotificationService.initialize();

      if (initialized) {
        return NotificationConfigState.configuringWorkManager;
      } else {
        return NotificationConfigState.errorInitializationFailed;
      }
    } catch (e) {
      return NotificationConfigState.errorInitializationFailed;
    }
  }

  static Future<NotificationConfigState> _configureNotificationManager() async {
    try {

      final notificationManager = NotificationManager();
      await notificationManager.initialize();

      return NotificationConfigState.savingPreferences;
    } catch (e) {
      return NotificationConfigState.errorWorkManagerFailed;
    }
  }

  static Future<NotificationConfigState> _saveNotificationState() async {
    try {

      await UserPreferences.setNotificationsReady(true);

      final verification = await UserPreferences.getNotificationsReady();

      if (verification) {
        return NotificationConfigState.success;
      } else {
        return NotificationConfigState.errorUnknown;
      }
    } catch (e) {
      return NotificationConfigState.errorUnknown;
    }
  }
  static Future<NotificationConfigState> _initializeFCM() async {
    try {

      final existingToken = await FirebaseMessaging.instance.getToken();

      if (existingToken != null) {
        await FirebaseMessaging.instance.subscribeToTopic('eventos_cordoba');
        return NotificationConfigState.success;
      }

      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();

      await FirebaseMessaging.instance.subscribeToTopic('eventos_cordoba');

      return NotificationConfigState.success;
    } catch (e) {
      return NotificationConfigState.errorUnknown;
    }
  }


  static Future<bool> isAlreadyConfigured() async {
    try {
      final isReady = await UserPreferences.getNotificationsReady();
      return isReady;
    } catch (e) {
      return false;
    }
  }

  static Future<void> disableNotifications() async {
    try {

      await UserPreferences.setNotificationsReady(false);

      final verification = await UserPreferences.getNotificationsReady();
    } catch (e) {
    }
  }
}

class _PlatformInfo {
  final PlatformType type;
  final int androidSdk;

  _PlatformInfo(this.type, this.androidSdk);
}

enum PlatformType {
  androidOld,   // Android <13
  androidNew,   // Android 13+
  ios
}