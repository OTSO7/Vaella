// lib/utils/map_helpers.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../models/daily_route_model.dart';

/// Generoi modernit, tyylitellyt nuolimerkit reiteille.
/// Tämä funktio on keskitetty paikka nuolten ulkoasun hallintaan koko sovelluksessa.
List<Marker> generateArrowMarkersForDays(List<DailyRoute> dailyRoutes) {
  final List<Marker> markers = [];
  const distance = Distance();

  // Muunnetaan DailyRoute-oliot FlutterMapin vaatimiksi Polyline-olioiksi.
  final polylines = dailyRoutes
      .where((route) => route.points.isNotEmpty)
      .map((route) => Polyline(
            points: route.points,
            color: Colors
                .transparent, // Väriä ei käytetä tässä, mutta se vaaditaan.
            strokeWidth: 0,
          ))
      .toList();

  for (final polyline in polylines) {
    if (polyline.points.length < 2) continue;

    // Asetetaan nuolia reitin varrelle 30%, 60% ja 90% kohdille.
    final List<double> arrowPositions = [0.3, 0.6, 0.9];

    for (final position in arrowPositions) {
      final index = (polyline.points.length * position).floor();
      if (index >= polyline.points.length - 1) continue;

      final startPoint = polyline.points[index];
      final endPoint = polyline.points[index + 1];

      if (startPoint == endPoint) continue;

      // Lasketaan suuntakulma ja muunnetaan se radiaaneiksi rotaatiota varten.
      final bearing = distance.bearing(startPoint, endPoint);
      final angle = (bearing * (pi / 180.0));

      markers.add(
        Marker(
          point: startPoint,
          width: 24,
          height: 24,
          child: Transform.rotate(
            angle: angle,
            // Käytetään siroa, varjostettua ikonia nuolena.
            child: Icon(
              Icons.keyboard_arrow_up,
              color: Colors.white,
              size: 22,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
  return markers;
}
