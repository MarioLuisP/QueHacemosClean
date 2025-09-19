import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cache/event_cache_service.dart';
import '../cache/cache_models.dart';
import '../utils/colors.dart';
import 'favorites_provider.dart';
import '../data/repositories/event_repository.dart';

class SimpleHomeProvider with ChangeNotifier {
  final EventCacheService _cacheService = EventCacheService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitializing = false;
  bool _isInitialized = false;
  String _currentSearchQuery = '';
  DateTime? _currentSelectedDate;
  Set<String> _selectedCategories = {};
  String _theme = 'normal';
  DateTime? _lastSelectedDate;
  int _eventCleanupDays = 3;
  int _favoriteCleanupDays = 7;

  SimpleHomeProvider() {
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Set<String> get selectedCategories => _selectedCategories;
  String get theme => _theme;
  DateTime? get lastSelectedDate => _lastSelectedDate;
  int get eventCleanupDays => _eventCleanupDays;
  int get favoriteCleanupDays => _favoriteCleanupDays;
  String get currentSearchQuery => _currentSearchQuery;
  DateTime? get currentSelectedDate => _currentSelectedDate;
  List<EventCacheItem> get events => _cacheService.allEvents;
  Map<String, List<EventCacheItem>> get groupedEvents => _cacheService.getGroupedByDate(_cacheService.allEvents);
  int get eventCount => _cacheService.eventCount;

  Future<void> initialize() async {
    if (_isInitializing || _isInitialized) {
      return;
    }

    _isInitializing = true;

    try {
      await _loadAllPreferences();

      if (_cacheService.isLoaded) {
        _isInitialized = true;
        return;
      }

      _setLoading(true);

      await _cacheService.loadCache(theme: _theme);

      _setLoading(false);
      _isInitialized = true;

    } catch (e) {
      _setError('Error cargando eventos: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  void setupFavoritesSync(FavoritesProvider favoritesProvider) {
    favoritesProvider.setOnFavoriteChangedCallback((eventId, isFavorite) {
      syncFavoriteInCache(eventId, isFavorite);
    });
  }

  List<EventCacheItem> getEventsWithoutDateFilter() {
    return _cacheService.filter(
      searchQuery: _currentSearchQuery.isEmpty ? null : _currentSearchQuery,
    ).events;
  }

  Future<void> _loadAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final selectedList = prefs.getStringList('selectedCategories') ?? [
      'musica', 'teatro', 'standup', 'arte', 'cine', 'mic',
      'cursos', 'ferias', 'calle', 'redes', 'ninos', 'danza'
    ];
    _selectedCategories = selectedList.toSet();

    _theme = prefs.getString('app_theme') ?? 'normal';

    final repository = EventRepository();
    _eventCleanupDays = await repository.getCleanupDays('cleanup_events_days');
    _favoriteCleanupDays = await repository.getCleanupDays('cleanup_favorites_days');
  }

  Future<void> _saveAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selectedCategories', _selectedCategories.toList());
    await prefs.setString('app_theme', _theme);
  }

  Future<void> toggleCategory(String category) async {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }

    await _saveAllPreferences();
    notifyListeners();
  }

  Future<void> resetCategories() async {
    _selectedCategories = {
      'musica', 'teatro', 'standup', 'arte', 'cine', 'mic',
      'cursos', 'ferias', 'calle', 'redes', 'ninos', 'danza'
    };

    await _saveAllPreferences();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _currentSearchQuery = query;
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    if (_theme != theme) {
      _theme = theme;

      _cacheService.recalculateColorsForTheme(theme);

      await _saveAllPreferences();

      notifyListeners();
    }
  }

  void setLastSelectedDate(DateTime date) {
    _lastSelectedDate = date;
  }

  void setSelectedDate(DateTime? date) {
    _currentSelectedDate = date;
    notifyListeners();
  }

  void clearAllFilters() {
    _currentSearchQuery = '';
    _currentSelectedDate = null;
    notifyListeners();
  }

  void syncFavoriteInCache(int eventId, bool isFavorite) {
    final updated = _cacheService.updateFavoriteInCache(eventId, isFavorite);
    if (updated) {
      notifyListeners();
    }
  }

  bool isEventFavorite(int eventId) {
    final event = _cacheService.getEventById(eventId);
    return event?.favorite ?? false;
  }

  Future<void> refresh() async {
    _setLoading(true);

    try {
      await _cacheService.reloadCache();
      _setLoading(false);
    } catch (e) {
      _setError('Error refrescando: $e');
    }
  }

  List<EventCacheItem> getFavoriteEvents() {
    if (!_cacheService.isLoaded) {
      return [];
    }

    final favoriteEvents = _cacheService.allEvents
        .where((event) => event.favorite)
        .toList();

    favoriteEvents.sort((a, b) {
      final ratingComparison = b.rating.compareTo(a.rating);
      if (ratingComparison != 0) return ratingComparison;

      final categoryComparison = a.type.compareTo(b.type);
      if (categoryComparison != 0) return categoryComparison;

      return a.date.compareTo(b.date);
    });

    return favoriteEvents;
  }

  String getSectionTitle(String dateKey) {
    return _cacheService.getSectionTitle(dateKey);
  }

  List<String> getSortedDateKeys() {
    final grouped = _cacheService.getGroupedByDate(_cacheService.allEvents);
    return _cacheService.getSortedDateKeys(grouped);
  }

  String getCategoryWithEmoji(String type) {
    return CategoryDisplayNames.getCategoryWithEmoji(type);
  }

  String formatEventDate(String dateString, {String format = 'card'}) {
    try {
      final date = DateTime.parse(dateString);
      switch (format) {
        case 'card':
          return "${date.day} ${_getMonthAbbrev(date.month)}${_getTimeString(date)}";
        default:
          return dateString;
      }
    } catch (e) {
      return dateString;
    }
  }

  Map<DateTime, int> getEventCountsForDateRange(DateTime start, DateTime end) {
    if (!_cacheService.isLoaded) {
      return {};
    }

    final counts = <DateTime, int>{};

    for (DateTime date = start; date.isBefore(end.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
      final dateString = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final count = _cacheService.getEventCountForDate(dateString);
      if (count > 0) {
        final cacheKey = DateTime(date.year, date.month, date.day);
        counts[cacheKey] = count;
      }
    }

    return counts;
  }

  String _getMonthAbbrev(int month) {
    const months = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return months[month] ?? 'mes';
  }

  String _getTimeString(DateTime date) {
    if (date.hour != 0 || date.minute != 0) {
      return " - ${date.hour}:${date.minute.toString().padLeft(2, '0')} hs";
    }
    return "";
  }

  bool hasEventsForDate(String dateKey) {
    return _cacheService.getEventCountForDate(dateKey) > 0;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String error) {
    _isLoading = false;
    _errorMessage = error;
    notifyListeners();
  }

  Map<String, dynamic> getDebugStats() {
    return {
      'cacheLoaded': _cacheService.isLoaded,
      'cacheEventCount': _cacheService.eventCount,
      'currentSearchQuery': _currentSearchQuery,
      'currentSelectedDate': _currentSelectedDate?.toString(),
      'isLoading': _isLoading,
      'hasError': _errorMessage != null,
      'selectedCategoriesCount': _selectedCategories.length,
      'selectedCategories': _selectedCategories.toList(),
    };
  }

  void debugPrint() {
    final stats = getDebugStats();
  }

  Future<void> setEventCleanupDays(int days) async {
    if (_eventCleanupDays != days) {
      _eventCleanupDays = days;

      final repository = EventRepository();
      await repository.updateSetting('cleanup_events_days', days.toString());

      notifyListeners();
    }
  }

  Future<void> setFavoriteCleanupDays(int days) async {
    if (_favoriteCleanupDays != days) {
      _favoriteCleanupDays = days;

      final repository = EventRepository();
      await repository.updateSetting('cleanup_favorites_days', days.toString());

      notifyListeners();
    }
  }
}