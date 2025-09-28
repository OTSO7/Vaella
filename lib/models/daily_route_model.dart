import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';

// TÄRKEÄÄ: RouteSummary-luokka on nyt määritelty tässä tiedostossa.
class RouteSummary {
  final double distance;
  final double duration;
  final double ascent;
  final double descent;

  RouteSummary({
    this.distance = 0.0,
    this.duration = 0.0,
    this.ascent = 0.0,
    this.descent = 0.0,
  });

  RouteSummary operator +(RouteSummary other) {
    return RouteSummary(
      distance: distance + other.distance,
      duration: duration + other.duration,
      ascent: ascent + other.ascent,
      descent: descent + other.descent,
    );
  }

  factory RouteSummary.fromMap(Map<String, dynamic> map) {
    return RouteSummary(
      distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (map['duration'] as num?)?.toDouble() ?? 0.0,
      ascent: (map['ascent'] as num?)?.toDouble() ?? 0.0,
      descent: (map['descent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'distance': distance,
      'duration': duration,
      'ascent': ascent,
      'descent': descent,
    };
  }
}

class DailyRoute {
  final int dayIndex;
  final List<LatLng> points; // Reitityspalvelun palauttamat tarkat pisteet
  final String? notes;
  final int colorValue;
  final RouteSummary summary;
  final List<double> elevationProfile; // Elevation data for each point
  final List<double> distances; // Cumulative distances for each point

  // MUUTOS: Lisätty lista käyttäjän klikkaamille pisteille.
  // Tämä on väliaikaista dataa kartan muokkausta varten, EI tallenneta Firestoreen.
  List<LatLng> userClickedPoints;

  DailyRoute({
    required this.dayIndex,
    required this.points,
    this.notes,
    required this.colorValue,
    RouteSummary? summary,
    List<LatLng>? userClickedPoints,
    List<double>? elevationProfile,
    List<double>? distances,
  })  : summary = summary ?? RouteSummary(),
        userClickedPoints = userClickedPoints ?? [],
        elevationProfile = elevationProfile ?? [],
        distances = distances ?? [];

  Color get routeColor => Color(colorValue);

  DailyRoute copyWith({
    int? dayIndex,
    List<LatLng>? points,
    String? notes,
    int? colorValue,
    RouteSummary? summary,
    List<LatLng>? userClickedPoints,
    List<double>? elevationProfile,
    List<double>? distances,
  }) {
    return DailyRoute(
      dayIndex: dayIndex ?? this.dayIndex,
      points: points ?? List.from(this.points),
      notes: notes ?? this.notes,
      colorValue: colorValue ?? this.colorValue,
      summary: summary ?? this.summary,
      userClickedPoints: userClickedPoints ?? List.from(this.userClickedPoints),
      elevationProfile: elevationProfile ?? List.from(this.elevationProfile),
      distances: distances ?? List.from(this.distances),
    );
  }

  factory DailyRoute.fromFirestore(Map<String, dynamic> data) {
    List<LatLng> points = [];
    if (data['points'] != null && data['points'] is String) {
      final decoded = json.decode(data['points']) as List;
      points =
          decoded.map((p) => LatLng(p[0] as double, p[1] as double)).toList();
    }

    // userClickedPoints ladataan samoista pisteistä aluksi, jotta muokkaus voi alkaa
    List<LatLng> userPoints = [];
    if (data['userClickedPoints'] != null &&
        data['userClickedPoints'] is String) {
      final decoded = json.decode(data['userClickedPoints']) as List;
      userPoints =
          decoded.map((p) => LatLng(p[0] as double, p[1] as double)).toList();
    }

    // Load elevation profile
    List<double> elevationProfile = [];
    if (data['elevationProfile'] != null && data['elevationProfile'] is String) {
      final decoded = json.decode(data['elevationProfile']) as List;
      elevationProfile = decoded.map((e) => (e as num).toDouble()).toList();
    }

    // Load distances
    List<double> distances = [];
    if (data['distances'] != null && data['distances'] is String) {
      final decoded = json.decode(data['distances']) as List;
      distances = decoded.map((d) => (d as num).toDouble()).toList();
    }

    return DailyRoute(
      dayIndex: data['dayIndex'] ?? 0,
      points: points,
      summary: data['summary'] != null
          ? RouteSummary.fromMap(data['summary'])
          : RouteSummary(),
      notes: data['notes'],
      colorValue: data['colorValue'] ?? Colors.blue.value,
      userClickedPoints: userPoints,
      elevationProfile: elevationProfile,
      distances: distances,
    );
  }

  Map<String, dynamic> toFirestore() {
    final encodedPoints =
        json.encode(points.map((p) => [p.latitude, p.longitude]).toList());
    final encodedUserPoints = json.encode(
        userClickedPoints.map((p) => [p.latitude, p.longitude]).toList());
    final encodedElevationProfile = json.encode(elevationProfile);
    final encodedDistances = json.encode(distances);

    return {
      'dayIndex': dayIndex,
      'points': encodedPoints,
      'summary': summary.toMap(),
      'notes': notes,
      'colorValue': colorValue,
      'userClickedPoints':
          encodedUserPoints, // Tallenetaan myös klikatut pisteet
      'elevationProfile': encodedElevationProfile,
      'distances': encodedDistances,
    };
  }
}
