// lib/models/hike_plan_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Added for Color
import 'package:uuid/uuid.dart';

// Enum for Hike Status
enum HikeStatus { planned, upcoming, ongoing, completed, cancelled }

// Enum for Hike Difficulty
enum HikeDifficulty { unknown, easy, moderate, challenging, expert }

// Extension for HikeDifficulty to get a user-friendly string and color
extension HikeDifficultyExtension on HikeDifficulty {
  String toShortString() {
    switch (this) {
      case HikeDifficulty.easy:
        return 'Easy';
      case HikeDifficulty.moderate:
        return 'Moderate';
      case HikeDifficulty.challenging:
        return 'Challenging';
      case HikeDifficulty.expert:
        return 'Expert';
      case HikeDifficulty.unknown:
      default:
        return 'Not set';
    }
  }

  Color getColor(BuildContext context) {
    // Using Theme colors for difficulty indication
    final theme = Theme.of(context);
    switch (this) {
      case HikeDifficulty.easy:
        return Colors.green.shade400;
      case HikeDifficulty.moderate:
        return Colors.blue.shade400;
      case HikeDifficulty.challenging:
        return Colors.orange.shade400;
      case HikeDifficulty.expert:
        return Colors.red.shade400;
      case HikeDifficulty.unknown:
      default:
        return theme.hintColor;
    }
  }
}

// Keys for preparation items (remains in Finnish as per your original model)
class PrepItemKeys {
  static const String weather = 'weather';
  static const String dayPlanner = 'day_planner';
  static const String foodPlanner = 'food_planner';
  static const String packingList = 'packing_list';

  static List<String> get allKeys =>
      [weather, dayPlanner, foodPlanner, packingList];

  static String getDisplayName(String key) {
    switch (key) {
      case weather:
        return 'Sää tarkistettu'; // Weather checked
      case dayPlanner:
        return 'Päiväsuunnitelma tehty'; // Day plan made
      case foodPlanner:
        return 'Ruokasuunnitelma valmis'; // Food plan ready
      case packingList:
        return 'Pakkauslista laadittu'; // Packing list compiled
      default:
        return key;
    }
  }
}

class HikePlan {
  final String id;
  final String hikeName;
  final String location;
  final DateTime startDate;
  final DateTime? endDate;
  final double? lengthKm;
  final String? notes;
  final HikeStatus status;
  final double? latitude;
  final double? longitude;
  final Map<String, bool> preparationItems;
  final String? imageUrl; // ADDED: For the Hub Page AppBar background
  final HikeDifficulty difficulty; // ADDED: For displaying hike difficulty

  HikePlan({
    String? id,
    required this.hikeName,
    required this.location,
    required this.startDate,
    this.endDate,
    this.lengthKm,
    this.notes,
    HikeStatus? status,
    this.latitude,
    this.longitude,
    Map<String, bool>? preparationItems,
    this.imageUrl, // ADDED
    this.difficulty = HikeDifficulty.unknown, // ADDED with default
  })  : id = id ?? const Uuid().v4(),
        status = status ??
            _calculateStatus(startDate, endDate,
                null), // Pass null for externally set status if not provided
        preparationItems = preparationItems ??
            {
              PrepItemKeys.weather: false,
              PrepItemKeys.dayPlanner: false,
              PrepItemKeys.foodPlanner: false,
              PrepItemKeys.packingList: false,
            };

  // Helper method to calculate status
  static HikeStatus _calculateStatus(
      DateTime startDate, DateTime? endDate, HikeStatus? currentStatusIfAny) {
    // If a status (like 'cancelled') is already definitively set, respect it.
    if (currentStatusIfAny == HikeStatus.cancelled) return HikeStatus.cancelled;
    if (currentStatusIfAny == HikeStatus.completed)
      return HikeStatus.completed; // If manually set to completed

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sDate = DateTime(startDate.year, startDate.month, startDate.day);
    final eDate = endDate != null
        ? DateTime(endDate.year, endDate.month, endDate.day)
        : null;

    if (eDate != null && eDate.isBefore(today)) {
      return HikeStatus.completed;
    }
    if (sDate.isAtSameMomentAs(today) ||
        (sDate.isBefore(today) && (eDate == null || !eDate.isBefore(today)))) {
      // Starts today OR started in past and not yet ended (or no end date)
      return HikeStatus.ongoing;
    }
    if (sDate.isAfter(today) &&
        sDate.isBefore(today.add(const Duration(days: 7)))) {
      // Starts within the next week (but not today)
      return HikeStatus.upcoming;
    }
    if (sDate.isAfter(today)) {
      // Starts further in the future
      return HikeStatus.planned;
    }
    // Default fallback if other conditions aren't met (e.g., past start without end date, might be considered ongoing or needs review)
    return HikeStatus.planned;
  }

  int get completedPreparationItems {
    return preparationItems.values.where((done) => done == true).length;
  }

  int get totalPreparationItems {
    return PrepItemKeys.allKeys.length;
  }

  factory HikePlan.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    Map<String, bool> prepItemsFromDb = {
      PrepItemKeys.weather: false,
      PrepItemKeys.dayPlanner: false,
      PrepItemKeys.foodPlanner: false,
      PrepItemKeys.packingList: false,
    };
    if (data['preparationItems'] != null && data['preparationItems'] is Map) {
      final Map<String, dynamic> itemsMap =
          data['preparationItems'] as Map<String, dynamic>;
      itemsMap.forEach((key, value) {
        if (value is bool && prepItemsFromDb.containsKey(key)) {
          prepItemsFromDb[key] = value;
        }
      });
    }

    HikeStatus status;
    if (data['status'] != null) {
      status = HikeStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => _calculateStatus(
            // Fallback calculation if status string is invalid
            (data['startDate'] as Timestamp).toDate(),
            (data['endDate'] as Timestamp?)?.toDate(),
            null), // Pass null as no specific pre-set status
      );
    } else {
      // If status field is missing entirely
      status = _calculateStatus((data['startDate'] as Timestamp).toDate(),
          (data['endDate'] as Timestamp?)?.toDate(), null);
    }

    HikeDifficulty difficulty = HikeDifficulty.unknown;
    if (data['difficulty'] != null && data['difficulty'] is String) {
      difficulty = HikeDifficulty.values.firstWhere(
          (e) => e.toString().split('.').last == data['difficulty'],
          orElse: () => HikeDifficulty.unknown);
    }

    return HikePlan(
      id: doc.id,
      hikeName: data['hikeName'] ?? '',
      location: data['location'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      lengthKm: (data['lengthKm'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
      status: status, // Use the determined status
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      preparationItems: prepItemsFromDb,
      imageUrl: data['imageUrl'] as String?, // ADDED
      difficulty: difficulty, // ADDED
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hikeName': hikeName,
      'location': location,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'lengthKm': lengthKm,
      'notes': notes,
      'status': status.toString().split('.').last,
      'latitude': latitude,
      'longitude': longitude,
      'preparationItems': preparationItems,
      'imageUrl': imageUrl, // ADDED
      'difficulty': difficulty.toString().split('.').last, // ADDED
      // Consider adding 'createdAt' and 'updatedAt' using FieldValue.serverTimestamp()
    };
  }

  HikePlan copyWith({
    String? id,
    String? hikeName,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    bool setEndDateToNull = false,
    double? lengthKm,
    bool setLengthKmToNull = false,
    String? notes,
    bool setNotesToNull = false,
    HikeStatus? status,
    double? latitude,
    bool setLatitudeToNull = false,
    double? longitude,
    bool setLongitudeToNull = false,
    Map<String, bool>? preparationItems,
    String? imageUrl, // ADDED
    bool setImageUrlToNull = false, // ADDED
    HikeDifficulty? difficulty, // ADDED
  }) {
    // Recalculate status if relevant dates change and no explicit status is provided
    HikeStatus newStatus;
    if (status != null) {
      newStatus = status;
    } else if (startDate != null || endDate != null || setEndDateToNull) {
      DateTime effectiveStartDate = startDate ?? this.startDate;
      DateTime? effectiveEndDate =
          setEndDateToNull ? null : (endDate ?? this.endDate);
      newStatus = _calculateStatus(effectiveStartDate, effectiveEndDate,
          this.status); // Pass current status for context
    } else {
      newStatus = this.status;
    }

    return HikePlan(
      id: id ?? this.id,
      hikeName: hikeName ?? this.hikeName,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: setEndDateToNull ? null : (endDate ?? this.endDate),
      lengthKm: setLengthKmToNull ? null : (lengthKm ?? this.lengthKm),
      notes: setNotesToNull ? null : (notes ?? this.notes),
      status: newStatus, // Use the potentially recalculated status
      latitude: setLatitudeToNull ? null : (latitude ?? this.latitude),
      longitude: setLongitudeToNull ? null : (longitude ?? this.longitude),
      preparationItems: preparationItems ?? this.preparationItems,
      imageUrl: setImageUrlToNull ? null : (imageUrl ?? this.imageUrl), // ADDED
      difficulty: difficulty ?? this.difficulty, // ADDED
    );
  }
}
