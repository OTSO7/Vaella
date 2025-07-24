// lib/pages/full_screen_map_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/daily_route_model.dart';
import '../utils/map_helpers.dart';

class FullScreenMapPage extends StatelessWidget {
  final List<DailyRoute> routes;

  const FullScreenMapPage({super.key, required this.routes});

  @override
  Widget build(BuildContext context) {
    final allPoints = routes.expand((route) => route.points).toList();
    final bounds = LatLngBounds.fromPoints(allPoints);
    // Käytetään keskitettyä funktiota nuolten luomiseen.
    final arrowMarkers = generateArrowMarkersForDays(routes);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Takaisin',
          ),
        ),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(40.0),
          ),
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.all),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
          ),
          PolylineLayer(
            polylines: routes
                .map((route) => Polyline(
                      points: route.points,
                      // Yhtenäistetty tyyli.
                      color: route.routeColor.withOpacity(0.8),
                      strokeWidth: 5.0,
                      borderColor: Colors.black.withOpacity(0.2),
                      borderStrokeWidth: 1.0,
                    ))
                .toList(),
          ),
          // Lisätty MarkerLayer nuolille.
          MarkerLayer(markers: arrowMarkers),
        ],
      ),
    );
  }
}
