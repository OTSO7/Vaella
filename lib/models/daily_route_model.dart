// lib/models/daily_route_model.dart

import 'package:flutter/material.dart'; // LISÄTTY
import 'package:latlong2/latlong.dart';
import '../pages/route_planner_page.dart';

class DailyRoute {
  final int dayIndex;
  List<LatLng> points;
  List<LatLng> userClickedPoints;
  RouteSummary summary;
  String notes;
  int colorValue; // LISÄTTY: Tallenentaan värin arvo kokonaislukuna

  // LISÄTTY: Kätevä getteri, joka muuntaa tallennetun luvun takaisin väriksi
  Color get routeColor => Color(colorValue);

  DailyRoute({
    required this.dayIndex,
    required this.points,
    List<LatLng>? userClickedPoints,
    RouteSummary? summary,
    this.notes = '',
    int? colorValue, // LISÄTTY
  })  : userClickedPoints = userClickedPoints ?? [],
        summary = summary ?? RouteSummary(),
        // LISÄTTY: Annetaan oletusväri, jos mitään ei ole määritelty
        colorValue = colorValue ?? Colors.blue.value;

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
      notes: data['notes'] ?? '',
      colorValue: data['colorValue'] as int?, // LISÄTTY
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
      'notes': notes,
      'colorValue': colorValue, // LISÄTTY
    };
  }

  DailyRoute copyWith({
    List<LatLng>? points,
    List<LatLng>? userClickedPoints,
    RouteSummary? summary,
    String? notes,
    int? colorValue, // LISÄTTY
  }) {
    return DailyRoute(
      dayIndex: dayIndex,
      points: points ?? List.from(this.points),
      userClickedPoints: userClickedPoints ?? List.from(this.userClickedPoints),
      summary: summary ?? this.summary,
      notes: notes ?? this.notes,
      colorValue: colorValue ?? this.colorValue, // LISÄTTY
    );
  }
}
