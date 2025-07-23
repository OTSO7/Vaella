// lib/models/daily_route_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../pages/route_planner_page.dart';

class DailyRoute {
  final int dayIndex;
  List<LatLng> points;
  List<LatLng> userClickedPoints;
  RouteSummary summary;
  String notes; // LISÄTTY: Kenttä päiväkohtaisille muistiinpanoille

  DailyRoute({
    required this.dayIndex,
    required this.points,
    List<LatLng>? userClickedPoints,
    RouteSummary? summary,
    this.notes = '', // LISÄTTY: Oletusarvo
  })  : userClickedPoints = userClickedPoints ?? [],
        summary = summary ?? RouteSummary();

  factory DailyRoute.fromFirestore(Map<String, dynamic> data) {
    List<dynamic> pointsData = data['points'] ?? [];
    List<dynamic> userClickedPointsData = data['userClickedPoints'] ?? [];

    return DailyRoute(
      dayIndex: data['dayIndex'] ?? 0,
      points:
          pointsData.map((p) => LatLng(p['latitude'], p['longitude'])).toList(),
      userClickedPoints: userClickedPointsData
          .map((p) => LatLng(p['latitude'], p['longitude']))
          .toList(),
      summary: data['summary'] != null
          ? RouteSummary(
              distance:
                  (data['summary']['distance'] as num?)?.toDouble() ?? 0.0,
              duration:
                  (data['summary']['duration'] as num?)?.toDouble() ?? 0.0,
              ascent: (data['summary']['ascent'] as num?)?.toDouble() ?? 0.0,
              descent: (data['summary']['descent'] as num?)?.toDouble() ?? 0.0,
            )
          : RouteSummary(),
      notes: data['notes'] ?? '', // LISÄTTY
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'dayIndex': dayIndex,
      'points': points
          .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
          .toList(),
      'userClickedPoints': userClickedPoints
          .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
          .toList(),
      'summary': {
        'distance': summary.distance,
        'duration': summary.duration,
        'ascent': summary.ascent,
        'descent': summary.descent,
      },
      'notes': notes, // LISÄTTY
    };
  }

  // Apumetodi kopiointiin
  DailyRoute copyWith({
    List<LatLng>? points,
    List<LatLng>? userClickedPoints,
    RouteSummary? summary,
    String? notes,
  }) {
    return DailyRoute(
      dayIndex: dayIndex,
      points: points ?? this.points,
      userClickedPoints: userClickedPoints ?? this.userClickedPoints,
      summary: summary ?? this.summary,
      notes: notes ?? this.notes,
    );
  }
}
