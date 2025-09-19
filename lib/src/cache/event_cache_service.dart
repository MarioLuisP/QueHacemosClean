import 'cache_models.dart';
import '../data/repositories/event_repository.dart';

class EventCacheService {
  static final EventCacheService _instance = EventCacheService._internal();
  factory EventCacheService() => _instance;
  EventCacheService._internal();

  List<EventCacheItem> _cache = [];
  bool _isLoaded = false;
  DateTime? _lastLoadTime;

  Map<String, List<EventCacheItem>> _eventsByDate = {};
  Map<String, int> _eventCountsByDate = {};

  List<EventCacheItem> get allEvents => List.unmodifiable(_cache);
  bool get isLoaded => _isLoaded;
  int get eventCount => _cache.length;
  DateTime? get lastLoadTime => _lastLoadTime;

  Future<void> loadCache({String theme = 'normal'}) async {
    if (_isLoaded) {
      return;
    }

    try {

      final repository = EventRepository();
      final mockData = await repository.getAllEvents();

      _cache = mockData.map((map) => EventCacheItem.fromMap(map, theme: theme)).toList();

      _cache.sort((a, b) => a.date.compareTo(b.date));
      _precalculateGroups();

      _isLoaded = true;
      _lastLoadTime = DateTime.now();

    } catch (e) {
      _cache = [];
      _isLoaded = false;
      rethrow;
    }
  }

  void _precalculateGroups() {

    _eventsByDate.clear();
    _eventCountsByDate.clear();

    for (final event in _cache) {
      final dateKey = event.date.length >= 10
          ? event.date.substring(0, 10)
          : event.date;

      _eventsByDate.putIfAbsent(dateKey, () => []).add(event);
    }

    _eventCountsByDate = _eventsByDate.map((date, events) =>
        MapEntry(date, events.length));

  }

  FilteredEvents filter({
    Set<String>? categories,
    String? searchQuery,
    DateTime? selectedDate,
  }) {
    if (!_isLoaded) {
      return FilteredEvents.empty;
    }

    List<EventCacheItem> filtered = _cache;

    if (categories != null && categories.isNotEmpty) {
      filtered = filtered.where((event) {
        return categories.contains(event.type.toLowerCase());
      }).toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((event) {
        return event.title.toLowerCase().contains(query) ||
            event.location.toLowerCase().contains(query) ||
            event.district.toLowerCase().contains(query);
      }).toList();
    }

    if (selectedDate != null) {
      final dateString = selectedDate.toIso8601String().substring(0, 10);
      filtered = filtered.where((event) {
        return event.date.startsWith(dateString);
      }).toList();
    }
    filtered.sort((a, b) {
      final ratingComparison = b.rating.compareTo(a.rating);
      if (ratingComparison != 0) return ratingComparison;

      final categoryComparison = a.type.compareTo(b.type);
      if (categoryComparison != 0) return categoryComparison;

      return a.date.compareTo(b.date);
    });

    final groupedByDate = getGroupedByDate(filtered);

    final filterParts = <String>[];
    if (categories != null && categories.isNotEmpty) {
      filterParts.add('${categories.length} categorías');
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      filterParts.add('Búsqueda: "$searchQuery"');
    }
    if (selectedDate != null) {
      filterParts.add('Fecha específica');
    }
    final description = filterParts.isEmpty ? 'Sin filtros' : filterParts.join(', ');

    return FilteredEvents(
      events: filtered,
      groupedByDate: groupedByDate,
      totalCount: filtered.length,
      appliedFilters: description,
    );
  }

  FilteredEvents applyFilters(MemoryFilters filters) {
    return filter(
      categories: filters.categories.isEmpty ? null : filters.categories,
      searchQuery: filters.searchQuery.isEmpty ? null : filters.searchQuery,
      selectedDate: filters.selectedDate,
    );
  }

  EventCacheItem? getEventById(int id) {
    if (!_isLoaded) return null;

    try {
      return _cache.firstWhere((event) => event.id == id);
    } catch (e) {
      return null;
    }
  }

  List<EventCacheItem> getEventsForDate(String dateString) {
    if (!_isLoaded) {
      return [];
    }

    return _eventsByDate[dateString] ?? [];
  }

  int getEventCountForDate(String dateString) {
    if (!_isLoaded) {
      return 0;
    }

    return _eventCountsByDate[dateString] ?? 0;
  }

  bool updateFavoriteInCache(int eventId, bool isFavorite) {
    if (!_isLoaded) return false;

    final index = _cache.indexWhere((event) => event.id == eventId);
    if (index == -1) return false;

    _cache[index] = _cache[index].copyWith(favorite: isFavorite);

    return true;
  }
  bool toggleFavorite(int eventId) {
    if (!_isLoaded) return false;

    final index = _cache.indexWhere((event) => event.id == eventId);
    if (index == -1) return false;

    final currentEvent = _cache[index];
    final newFavoriteState = !currentEvent.favorite;

    _cache[index] = currentEvent.copyWith(favorite: newFavoriteState);

    return newFavoriteState;
  }

  Map<String, List<EventCacheItem>> getGroupedByDate(List<EventCacheItem> events) {
    final grouped = <String, List<EventCacheItem>>{};

    for (final event in events) {
      final dateKey = event.date.length >= 10
          ? event.date.substring(0, 10)
          : event.date;

      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(event);
    }

    grouped.forEach((date, events) {
      events.sort((a, b) {
        final ratingComparison = b.rating.compareTo(a.rating);
        if (ratingComparison != 0) return ratingComparison;

        final categoryComparison = a.type.compareTo(b.type);
        if (categoryComparison != 0) return categoryComparison;

        return a.date.compareTo(b.date);
      });
    });

    return grouped;
  }
  List<String> getSortedDateKeys(Map<String, List<EventCacheItem>> grouped) {
    final today = DateTime.now();
    final todayString = today.toIso8601String().substring(0, 10);
    final tomorrowString = today.add(Duration(days: 1)).toIso8601String().substring(0, 10);
    final dates = grouped.keys.where((date) => date.compareTo(todayString) >= 0).toList();
    dates.sort((a, b) {
      if (a == todayString) return -2;
      if (b == todayString) return 2;

      if (a == tomorrowString) return -1;
      if (b == tomorrowString) return 1;

      return a.compareTo(b);
    });

    return dates;
  }

  String getSectionTitle(String dateKey) {
    final today = DateTime.now();
    final todayString = today.toIso8601String().substring(0, 10);
    final tomorrowString = today.add(Duration(days: 1)).toIso8601String().substring(0, 10);

    if (dateKey == todayString) {
      return 'Hoy';
    } else if (dateKey == tomorrowString) {
      return 'Mañana';
    } else {
      try {
        final date = DateTime.parse(dateKey);
        final weekdays = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
        final months = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
          'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

        final weekday = weekdays[date.weekday];
        final day = date.day;
        final month = months[date.month];

        return '$weekday, $day de $month';
      } catch (e) {
        return dateKey;
      }
    }
  }

  Future<void> reloadCache() async {
    _isLoaded = false;
    _cache.clear();
    _eventsByDate.clear();
    _eventCountsByDate.clear();
    await loadCache();
  }

  void recalculateColorsForTheme(String theme) {
    if (!_isLoaded) {
      return;
    }

    for (int i = 0; i < _cache.length; i++) {
      _cache[i] = _cache[i].copyWith(theme: theme);
    }

  }

  void clearCache() {
    _cache.clear();
    _isLoaded = false;
    _lastLoadTime = null;
  }

  Map<String, dynamic> getStats() {
    if (!_isLoaded) {
      return {
        'loaded': false,
        'eventCount': 0,
        'memoryUsage': 0,
      };
    }

    final categoryCount = <String, int>{};
    for (final event in _cache) {
      categoryCount[event.type] = (categoryCount[event.type] ?? 0) + 1;
    }

    return {
      'loaded': true,
      'eventCount': _cache.length,
      'memoryUsage': '${_cache.length * 203} bytes',
      'lastLoadTime': _lastLoadTime?.toIso8601String(),
      'categories': categoryCount,
      'favoriteCount': _cache.where((e) => e.favorite).length,
    };
  }

  void debugPrintCache() {
    if (!_isLoaded) {
      return;
    }

    for (int i = 0; i < _cache.length; i++) {
      final event = _cache[i];
    }
  }
}