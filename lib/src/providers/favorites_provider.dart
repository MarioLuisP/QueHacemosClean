import 'package:flutter/foundation.dart';
import '../data/repositories/event_repository.dart';
import 'notifications_provider.dart';
import '../services/notification_service.dart';
import '../models/user_preferences.dart';

class FavoritesProvider with ChangeNotifier {
  final EventRepository _repository = EventRepository();
  Set<String> _favoriteIds = {};
  bool _isInitialized = false;
  Function(int eventId, bool isFavorite)? _onFavoriteChanged;

  FavoritesProvider() {
    _initializeAsync();
  }

  bool get isInitialized => _isInitialized;

  void _initializeAsync() {
    init();
  }

  Future<void> init() async {
    await _loadFavoritesFromRepository();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> scheduleNotificationsForToday() async {
    try {
      final favorites = await _repository.getAllFavorites();

      if (favorites.isEmpty) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final List<Map<String, dynamic>> todayFavorites = [];

      for (final favorite in favorites) {
        final dateStr = favorite['date']?.toString().split('T')[0];

        if (dateStr != null && dateStr == todayStr) {
          todayFavorites.add(favorite);
        }
      }

      if (todayFavorites.isNotEmpty) {
        await NotificationService.scheduleDailyNotification(todayStr, todayFavorites);

        await NotificationService.setBadge();

      } else {

      }

    } catch (e) {

    }
  }

  Future<void> sendImmediateNotificationForToday() async {
    try {
      final favorites = await _repository.getAllFavorites();
      if (favorites.isEmpty) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final List<Map<String, dynamic>> todayFavorites = [];
      for (final favorite in favorites) {
        final dateStr = favorite['date']?.toString().split('T')[0];
        if (dateStr != null && dateStr == todayStr) {
          todayFavorites.add(favorite);
        }
      }

      if (todayFavorites.isNotEmpty) {
        final message = NotificationService.generateDailyMessage(todayFavorites);
        await NotificationService.showNotification(
          id: "daily_$todayStr".hashCode,
          title: '❤️ Favoritos de hoy ⭐',
          message: message,
          payload: 'daily_reminder:$todayStr',
        );
        await NotificationService.setBadge();

      }
    } catch (e) {

    }
  }

  Future<void> _loadFavoritesFromRepository() async {
    try {
      final favorites = await _repository.getAllFavorites();
      _favoriteIds = favorites.map((e) => e['id'].toString()).toSet();

    } catch (e) {

      _favoriteIds = {};
    }
  }

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  bool isFavorite(String eventId) => _favoriteIds.contains(eventId);

  Future<void> toggleFavorite(String eventId, {String? eventTitle}) async {
    try {

      final numericId = int.tryParse(eventId) ?? 0;


      if (numericId == 0) {

        return;
      }

      final wasAdded = await _repository.toggleFavorite(numericId);

      if (wasAdded) {
        _favoriteIds.add(eventId);

      } else {
        _favoriteIds.remove(eventId);

      }

      _syncWithSimpleHomeProvider(numericId, wasAdded);

      await _sendFavoriteNotification(eventId, wasAdded, eventTitle);

      await _updateTodayFavoritesFlag();

      notifyListeners();

    } catch (e) {

    }
  }

  Future<void> _updateTodayFavoritesFlag() async {
    try {
      final favorites = await _repository.getAllFavorites();
      final today = DateTime.now().toIso8601String().split('T')[0];

      bool hasFavoritesToday = false;
      for (final favorite in favorites) {
        final dateStr = favorite['date']?.toString().split('T')[0];
        if (dateStr == today) {
          hasFavoritesToday = true;
          break;
        }
      }

      await UserPreferences.setHasFavoritesForDate(today, hasFavoritesToday);


    } catch (e) {

    }
  }

  Future<void> addFavorite(String eventId) async {
    if (!_favoriteIds.contains(eventId)) {
      await toggleFavorite(eventId);
    }
  }

  Future<void> removeFavorite(String eventId) async {
    if (_favoriteIds.contains(eventId)) {
      await toggleFavorite(eventId);
    }
  }

  Future<void> clearFavorites() async {
    try {
      for (final eventId in _favoriteIds.toList()) {
        await _repository.removeFromFavorites(int.tryParse(eventId) ?? 0);
      }

      _favoriteIds.clear();
      notifyListeners();

    } catch (e) {

    }
  }

  void setOnFavoriteChangedCallback(Function(int eventId, bool isFavorite) callback) {
    _onFavoriteChanged = callback;
  }

  void _syncWithSimpleHomeProvider(int eventId, bool isFavorite) {

    _onFavoriteChanged?.call(eventId, isFavorite);

  }

  Future<void> _sendFavoriteNotification(String eventId, bool isAdded, String? eventTitle) async {
    try {
      final notificationsProvider = NotificationsProvider.instance;
      final title = eventTitle ?? 'Evento';

      if (isAdded) {
        await notificationsProvider.addNotification(
          title: '❤️ Evento guardado en favoritos',
          message: title,
          type: 'favorite_added',
          eventCode: eventId,
        );
      } else {
        await notificationsProvider.addNotification(
          title: '💔 Favorito removido',
          message: '$title removido de favoritos',
          type: 'favorite_removed',
          eventCode: eventId,
        );
      }


    } catch (e) {

    }
  }

  List<Map<String, dynamic>> filterFavoriteEvents(List<Map<String, dynamic>> allEvents) {
    return allEvents.where((event) => isFavorite(event['id']?.toString() ?? '')).toList();
  }
}