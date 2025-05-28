// lib/models/hike_plan_model.dart
enum HikeStatus { planned, upcoming, completed, cancelled }

class HikePlan {
  final String id;
  final String hikeName;
  final String location;
  final DateTime startDate;
  final DateTime? endDate;
  final double? lengthKm;
  final String? notes;
  // final String? imageUrl; // POISTETTU

  final HikeStatus status;

  HikePlan({
    required this.id,
    required this.hikeName,
    required this.location,
    required this.startDate,
    this.endDate,
    this.lengthKm,
    this.notes,
    // this.imageUrl, // POISTETTU konstruktorista
    this.status = HikeStatus.planned,
  });
}
