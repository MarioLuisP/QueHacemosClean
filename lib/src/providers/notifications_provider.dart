import 'package:flutter/material.dart';
import '../data/repositories/event_repository.dart';

class NotificationsProvider extends ChangeNotifier {
  static NotificationsProvider? _instance;
  static NotificationsProvider get instance {
    _instance ??= NotificationsProvider._internal();
    return _instance!;
  }

  final EventRepository _eventRepository = EventRepository();

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _cacheLoaded = false;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get hasUnreadNotifications => _unreadCount > 0;

  NotificationsProvider._internal() {
    _initializeNotifications();
  }

  void _initializeNotifications() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await loadNotifications();
      } catch (e) {
      }
    });
  }

  factory NotificationsProvider() => instance;

  Future<void> _updateUnreadCount() async {
    try {
      _unreadCount = await _eventRepository.getUnreadNotificationsCount();
      notifyListeners();
    } catch (e) {
      _unreadCount = _notifications.where((n) => !n['isRead']).length;
      notifyListeners();
    }
  }

  Future<void> markAsRead(dynamic notificationId) async {
    try {
      final id = notificationId is String ? int.parse(notificationId) : notificationId as int;

      await _eventRepository.markNotificationAsRead(id);

      final index = _notifications.indexWhere((n) => n['id'] == id);
      if (index != -1) {
        _notifications[index]['isRead'] = true;
        _updateUnreadCount();
      }
    } catch (e) {
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _eventRepository.markAllNotificationsAsRead();

      for (var notification in _notifications) {
        notification['isRead'] = true;
      }
      _updateUnreadCount();
    } catch (e) {
    }
  }

  Future<void> removeNotification(dynamic notificationId) async {
    try {
      final id = notificationId is String ? int.parse(notificationId) : notificationId as int;

      await _eventRepository.deleteNotification(id);

      _notifications.removeWhere((n) => n['id'] == id);
      _updateUnreadCount();
    } catch (e) {
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      await _eventRepository.clearAllNotifications();

      _notifications.clear();
      await _updateUnreadCount();
    } catch (e) {
    }
  }

  Future<void> addNotification({
    required String title,
    required String message,
    required String type,
    String? eventCode,
  }) async {
    try {
      final notificationId = await _eventRepository.insertNotification(
        title: title,
        message: message,
        type: type,
        eventCode: eventCode,
      );

      final notification = {
        'id': notificationId.toString(),
        'title': title,
        'message': message,
        'timestamp': DateTime.now(),
        'isRead': false,
        'type': type,
        'icon': _getIconForType(type),
        'event_code': eventCode,
      };

      _notifications.insert(0, notification);
      _updateUnreadCount();
    } catch (e) {
    }
  }

  Future<void> loadNotifications() async {
    if (_cacheLoaded) return;

    _isLoading = true;
    notifyListeners();

    try {
      final dbNotifications = await _eventRepository.getAllNotifications();

      _notifications = dbNotifications.map((dbNotif) => {
        'id': dbNotif['id'].toString(),
        'title': dbNotif['title'],
        'message': dbNotif['message'],
        'timestamp': DateTime.parse(dbNotif['created_at']),
        'isRead': (dbNotif['is_read'] as int) == 1,
        'type': dbNotif['type'],
        'icon': _getIconForType(dbNotif['type']),
        'event_code': dbNotif['event_code'],
      }).toList();

      _cacheLoaded = true;
      _updateUnreadCount();

    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _getIconForType(String type) {
    switch (type) {
      case 'favorite_added':
        return '❤️';
      case 'favorite_removed':
        return '💔';
      case 'first_install_complete':
        return '🎉';
      case 'new_events':
        return '🎭';
      case 'sync_up_to_date':
        return '📡';
      case 'auto_sync_error':
      case 'first_install_error':
        return '⚠️';
      case 'high_activity':
        return '🔥';
      case 'cleanup':
        return '🧹';
      case 'sync':
        return '🔄';
      case 'login_success':
        return '🎈';
      case 'login_error':
        return '🚩';
      default:
        return '🔔';
    }
  }

  String getNotificationTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}