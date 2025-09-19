import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('theme') ?? 'normal';
  }

  static Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme);
  }

  static Future<Set<String>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('categories') ?? []).toSet();
  }

  static Future<void> setCategories(Set<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('categories', categories.toList());
  }

  static Future<Set<String>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('favorite_ids') ?? []).toSet();
  }

  static Future<void> setFavoriteIds(Set<String> favoriteIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_ids', favoriteIds.toList());
  }
// ✅ AGREGAR - sistema de 3 flags por fecha
  static Future<void> setHasFavoritesForDate(String date, bool hasFavorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_favorites_$date', hasFavorites);
  }

  static Future<bool> getHasFavoritesForDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_favorites_$date') ?? false;
  }

  static Future<Set<String>> getActiveFilterCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('activeFilterCategories') ?? []).toSet();
  }

  static Future<void> setActiveFilterCategories(Set<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('activeFilterCategories', categories.toList());
  }
  static Future<int> getEventCleanupDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('event_cleanup_days') ?? 3;
  }

  static Future<void> setEventCleanupDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('event_cleanup_days', days);
  }

  static Future<int> getFavoriteCleanupDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('favorite_cleanup_days') ?? 7;
  }

  static Future<void> setFavoriteCleanupDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('favorite_cleanup_days', days);
  }
  static Future<bool> getNotificationsReady() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_ready') ?? false;
  }

  static Future<void> setNotificationsReady(bool ready) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_ready', ready);
  }
// Prompt management for weekly reminders
  static Future<String> getLoginPromptData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('login_prompt_data') ?? '${DateTime.now().millisecondsSinceEpoch}_0';
  }

  static Future<void> setLoginPromptData(String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('login_prompt_data', data);
  }

  static Future<String> getNotificationPromptData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notification_prompt_data') ?? '${DateTime.now().millisecondsSinceEpoch}_0';
  }

  static Future<void> setNotificationPromptData(String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_prompt_data', data);
  }

  static Future<String?> getLastFCMInitVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_fcm_init_version');
  }

  static Future<void> setLastFCMInitVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_fcm_init_version', version);
  }
}
