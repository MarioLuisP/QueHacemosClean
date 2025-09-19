import 'package:flutter/material.dart';
import '../utils/colors.dart';
class EventCacheItem {
  final int id;
  final String spacecode;
  final String title;
  final String type;
  final String location;
  final String date;
  final String price;
  final String district;
  final int rating;
  final bool favorite;
  final String formattedDateForCard;
  final String categoryWithEmoji;
  final Color baseColor;
  final Color darkColor;
  final Color textColor;
  final Color textFaded90;
  final Color textFaded70;
  final Color textFaded30;
  final String premiumEmoji;

  const EventCacheItem({
    required this.id,
    required this.spacecode,
    required this.title,
    required this.type,
    required this.location,
    required this.date,
    required this.price,
    required this.district,
    required this.rating,
    required this.favorite,
    required this.formattedDateForCard,
    required this.categoryWithEmoji,
    required this.baseColor,
    required this.darkColor,
    required this.textColor,
    required this.textFaded90,
    required this.textFaded70,
    required this.textFaded30,
    required this.premiumEmoji,
  });



  factory EventCacheItem.fromMap(Map<String, dynamic> map, {String theme = 'normal'}) {
    final String dateString = map['date'] as String? ?? '';
    final String typeString = map['type'] as String? ?? '';
    final int eventId = (map['id'] is int)
        ? map['id'] as int
        : int.tryParse(map['id']?.toString() ?? '') ?? 0;

    final int eventRating = (map['rating'] is int)
        ? map['rating'] as int
        : int.tryParse(map['rating']?.toString() ?? '') ?? 0;

    final bool isFavorite = (map['favorite'] is int)
        ? (map['favorite'] as int) == 1
        : (int.tryParse(map['favorite']?.toString() ?? '') ?? 0) == 1;
    final String formattedDate = _formatDateForCard(dateString);
    final String categoryEmoji = CategoryDisplayNames.getCategoryWithEmoji(typeString);
    final String premiumEmoji = _calculatePremiumEmoji(eventRating);
    final optimizedColors = EventCardColorPalette.getOptimizedColors(theme, typeString);

    return EventCacheItem(
      id: eventId,
      spacecode: map['code'] as String? ?? '',
      title: map['title'] as String? ?? '',
      type: typeString,
      location: map['location'] as String? ?? '',
      date: dateString,
      price: map['price'] as String? ?? '',
      district: map['district'] as String? ?? '',
      rating: eventRating,
      favorite: isFavorite,
      formattedDateForCard: formattedDate,
      categoryWithEmoji: categoryEmoji,
      baseColor: optimizedColors.base,
      darkColor: optimizedColors.dark,
      textColor: optimizedColors.text,
      textFaded90: optimizedColors.textFaded90,
      textFaded70: optimizedColors.textFaded70,
      textFaded30: optimizedColors.textFaded30,
      premiumEmoji: premiumEmoji,
    );
  }
  static String _formatDateForCard(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final monthAbbrev = _getMonthAbbrev(date.month);
      final timeString = _getTimeString(date);
      return "${date.day} $monthAbbrev$timeString";
    } catch (e) {
      return dateString;
    }
  }
  static String _calculatePremiumEmoji(int rating) {
    if (rating >= 400) return ' 💎💎💎💎';
    if (rating >= 300) return ' 💎💎💎';
    if (rating >= 200) return ' 💎💎';
    if (rating >= 100) return ' 💎';
    return '';
  }

  static String _getMonthAbbrev(int month) {
    const months = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return months[month] ?? 'mes';
  }

  static String _getTimeString(DateTime date) {
    if (date.hour != 0 || date.minute != 0) {
      return " - ${date.hour}:${date.minute.toString().padLeft(2, '0')} hs";
    }
    return "";
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'location': location,
      'date': date,
      'price': price,
      'district': district,
      'rating': rating,
      'favorite': favorite,
    };
  }

  EventCacheItem copyWith({
    int? id,
    String? spacecode,
    String? title,
    String? type,
    String? location,
    String? date,
    String? price,
    String? district,
    int? rating,
    bool? favorite,
    String? theme,
  }) {
    final String newType = type ?? this.type;
    final String newDate = date ?? this.date;
    final bool needsRecalculation = (type != null || date != null || theme != null);

    if (needsRecalculation) {
      final String formattedDate = _formatDateForCard(newDate);
      final String categoryEmoji = CategoryDisplayNames.getCategoryWithEmoji(newType);
      final optimizedColors = EventCardColorPalette.getOptimizedColors(theme ?? 'normal', newType);

      return EventCacheItem(
        id: id ?? this.id,
        spacecode: spacecode ?? this.spacecode,
        title: title ?? this.title,
        type: newType,
        location: location ?? this.location,
        date: newDate,
        price: price ?? this.price,
        district: district ?? this.district,
        rating: rating ?? this.rating,
        favorite: favorite ?? this.favorite,
        formattedDateForCard: formattedDate,
        categoryWithEmoji: categoryEmoji,
        baseColor: optimizedColors.base,
        darkColor: optimizedColors.dark,
        textColor: optimizedColors.text,
        textFaded90: optimizedColors.textFaded90,
        textFaded70: optimizedColors.textFaded70,
        textFaded30: optimizedColors.textFaded30,
        premiumEmoji: this.premiumEmoji,
      );
    } else {
      return EventCacheItem(
        id: id ?? this.id,
        spacecode: spacecode ?? this.spacecode,
        title: title ?? this.title,
        type: this.type,
        location: location ?? this.location,
        date: this.date,
        price: price ?? this.price,
        district: district ?? this.district,
        rating: rating ?? this.rating,
        favorite: favorite ?? this.favorite,
        formattedDateForCard: this.formattedDateForCard,
        categoryWithEmoji: this.categoryWithEmoji,
        baseColor: this.baseColor,
        darkColor: this.darkColor,
        textColor: this.textColor,
        textFaded90: this.textFaded90,
        textFaded70: this.textFaded70,
        textFaded30: this.textFaded30,
        premiumEmoji: this.premiumEmoji,
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventCacheItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'EventCacheItem(id: $id, title: $title, type: $type)';
  }
}

class FilteredEvents {
  final List<EventCacheItem> events;
  final Map<String, List<EventCacheItem>> groupedByDate;
  final int totalCount;
  final String appliedFilters;

  const FilteredEvents({
    required this.events,
    required this.groupedByDate,
    required this.totalCount,
    required this.appliedFilters,
  });

  static const FilteredEvents empty = FilteredEvents(
    events: [],
    groupedByDate: {},
    totalCount: 0,
    appliedFilters: 'Sin filtros',
  );
}

class MemoryFilters {
  final Set<String> categories;
  final String searchQuery;
  final DateTime? selectedDate;

  const MemoryFilters({
    this.categories = const {},
    this.searchQuery = '',
    this.selectedDate,
  });

  static const MemoryFilters empty = MemoryFilters();


  MemoryFilters copyWith({
    Set<String>? categories,
    String? searchQuery,
    DateTime? selectedDate,
    bool clearDate = false,
  }) {
    return MemoryFilters(
      categories: categories ?? this.categories,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedDate: clearDate ? null : (selectedDate ?? this.selectedDate),
    );
  }

  bool get hasActiveFilters {
    return categories.isNotEmpty ||
        searchQuery.isNotEmpty ||
        selectedDate != null;
  }

  String get description {
    final parts = <String>[];

    if (categories.isNotEmpty) {
      parts.add('${categories.length} categorías');
    }

    if (searchQuery.isNotEmpty) {
      parts.add('Búsqueda: "$searchQuery"');
    }

    if (selectedDate != null) {
      parts.add('Fecha específica');
    }

    return parts.isEmpty ? 'Sin filtros' : parts.join(', ');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemoryFilters &&
        other.categories == categories &&
        other.searchQuery == searchQuery &&
        other.selectedDate == selectedDate;
  }

  @override
  int get hashCode {
    return Object.hash(categories, searchQuery, selectedDate);
  }
}