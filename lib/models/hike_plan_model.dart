// lib/models/hike_plan_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'packing_list_item.dart'; // Import the new model

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
    // These colors align with a dark theme where primary/accent are vivid
    switch (this) {
      case HikeDifficulty.easy:
        return Colors.green.shade400; // Bright green for easy
      case HikeDifficulty.moderate:
        return Colors.blue.shade300; // Muted blue for moderate
      case HikeDifficulty.challenging:
        return Colors.orange.shade400; // Orange for challenging
      case HikeDifficulty.expert:
        return Colors.red.shade400; // Red for expert
      case HikeDifficulty.unknown:
      default:
        return Colors.white
            .withOpacity(0.6); // Subtle for unknown (like hintColor)
    }
  }
}

// Keys for preparation items
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
        return 'Sää tarkistettu';
      case dayPlanner:
        return 'Päiväsuunnitelma tehty';
      case foodPlanner:
        return 'Ruokasuunnitelma valmis';
      case packingList:
        return 'Pakkauslista laadittu';
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
  final String? imageUrl;
  final HikeDifficulty difficulty;
  final List<PackingListItem> packingList; // ADDED: Packing list items

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
    this.imageUrl,
    this.difficulty = HikeDifficulty.unknown,
    List<PackingListItem>? packingList, // ADDED
  })  : id = id ?? const Uuid().v4(),
        status = status ?? _calculateStatus(startDate, endDate, null),
        preparationItems = preparationItems ??
            {
              PrepItemKeys.weather: false,
              PrepItemKeys.dayPlanner: false,
              PrepItemKeys.foodPlanner: false,
              PrepItemKeys.packingList: false,
            },
        packingList = packingList ?? []; // Initialize with empty list

  static HikeStatus _calculateStatus(
      DateTime startDate, DateTime? endDate, HikeStatus? currentStatusIfAny) {
    if (currentStatusIfAny == HikeStatus.cancelled) return HikeStatus.cancelled;
    if (currentStatusIfAny == HikeStatus.completed) return HikeStatus.completed;

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
      return HikeStatus.ongoing;
    }
    if (sDate.isAfter(today) &&
        sDate.isBefore(today.add(const Duration(days: 7)))) {
      return HikeStatus.upcoming;
    }
    if (sDate.isAfter(today)) {
      return HikeStatus.planned;
    }
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

    // Parse packing list
    List<PackingListItem> packingListFromDb = [];
    if (data['packingList'] != null && data['packingList'] is List) {
      packingListFromDb = (data['packingList'] as List)
          .map((item) => PackingListItem.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    HikeStatus status;
    if (data['status'] != null) {
      status = HikeStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => _calculateStatus(
            (data['startDate'] as Timestamp).toDate(),
            (data['endDate'] as Timestamp?)?.toDate(),
            null),
      );
    } else {
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
      status: status,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      preparationItems: prepItemsFromDb,
      imageUrl: data['imageUrl'] as String?,
      difficulty: difficulty,
      packingList: packingListFromDb, // ADDED
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
      'imageUrl': imageUrl,
      'difficulty': difficulty.toString().split('.').last,
      'packingList': packingList.map((item) => item.toMap()).toList(), // ADDED
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
    String? imageUrl,
    bool setImageUrlToNull = false,
    HikeDifficulty? difficulty,
    List<PackingListItem>? packingList, // ADDED
  }) {
    HikeStatus newStatus;
    if (status != null) {
      newStatus = status;
    } else if (startDate != null || endDate != null || setEndDateToNull) {
      DateTime effectiveStartDate = startDate ?? this.startDate;
      DateTime? effectiveEndDate =
          setEndDateToNull ? null : (endDate ?? this.endDate);
      newStatus =
          _calculateStatus(effectiveStartDate, effectiveEndDate, this.status);
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
      status: newStatus,
      latitude: setLatitudeToNull ? null : (latitude ?? this.latitude),
      longitude: setLongitudeToNull ? null : (longitude ?? this.longitude),
      preparationItems: preparationItems ?? this.preparationItems,
      imageUrl: setImageUrlToNull ? null : (imageUrl ?? this.imageUrl),
      difficulty: difficulty ?? this.difficulty,
      packingList: packingList ?? this.packingList, // ADDED
    );
  }
}
