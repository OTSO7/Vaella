// lib/pages/full_screen_map_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/daily_route_model.dart';

class FullScreenMapPage extends StatelessWidget {
  final List<DailyRoute> routes;

  const FullScreenMapPage({super.key, required this.routes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Kerätään kaikki reittien pisteet yhteen listaan, jotta voimme sovittaa ne kartalle.
    final List<LatLng> allPoints =
        routes.expand((route) => route.points).toList();
    final LatLngBounds bounds = LatLngBounds.fromPoints(allPoints);

    return Scaffold(
      // extendBodyBehindAppBar: true tekee AppBarista läpinäkyvän ja kelluvan kartan päällä.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Lisätään musta, puoliläpinäkyvä tausta napille, jotta se näkyy aina.
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
            padding: const EdgeInsets.all(40.0), // Lisätään reunoille tilaa
          ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all, // Sallitaan kaikki interaktiot
          ),
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
                      color: route.routeColor,
                      strokeWidth: 5.0,
                      borderColor: Colors.black.withOpacity(0.5),
                      borderStrokeWidth: 1.5,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
