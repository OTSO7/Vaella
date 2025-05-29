import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

enum HikeStatus { planned, upcoming, completed, cancelled }

class HikePlan {
  final String id;
  final String hikeName;
  final String location;
  final DateTime startDate;
  final DateTime? endDate;
  final double? lengthKm;
  final String? notes;
  final HikeStatus status;

  HikePlan({
    String? id,
    required this.hikeName,
    required this.location,
    required this.startDate,
    this.endDate,
    this.lengthKm,
    this.notes,
    HikeStatus? status,
  })  : id = id ?? const Uuid().v4(),
        status = status ??
            (startDate.isBefore(DateTime.now())
                ? HikeStatus.completed
                : HikeStatus.planned);

  factory HikePlan.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return HikePlan(
      id: doc.id,
      hikeName: data['hikeName'] ?? '',
      location: data['location'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      lengthKm: (data['lengthKm'] as num?)?.toDouble(),
      notes: data['notes'],
      status: HikeStatus.values.firstWhere(
        (e) => e.toString() == 'HikeStatus.${data['status']}',
        orElse: () => HikeStatus.planned,
      ),
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
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  HikePlan copyWith({
    String? id,
    String? hikeName,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    double? lengthKm,
    String? notes,
    HikeStatus? status,
  }) {
    return HikePlan(
      id: id ?? this.id,
      hikeName: hikeName ?? this.hikeName,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      lengthKm: lengthKm ?? this.lengthKm,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}
