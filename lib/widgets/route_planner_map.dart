import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Varmista, että käytät latlong2-pakettia

class RoutePlannerMap extends StatefulWidget {
  const RoutePlannerMap({super.key});

  @override
  _RoutePlannerMapState createState() => _RoutePlannerMapState();
}

class _RoutePlannerMapState extends State<RoutePlannerMap> {
  // MapControlleria ei enää suositella peruskäyttöön, mutta se toimii edelleen.
  // Voit halutessasi poistaa sen, jos et ohjaa karttaa koodista käsin.
  final MapController _mapController = MapController();

  final List<LatLng> _routePath = [
    const LatLng(65.0, 25.0),
    const LatLng(66.0, 26.0),
    const LatLng(67.0, 27.0),
  ];

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        // KORJATTU: 'center' ja 'zoom' on päivitetty uusiin nimiin
        initialCenter: const LatLng(65.0, 25.0),
        initialZoom: 5,
        onTap: _handleTap,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app', // Muista vaihtaa tämä omaan
        ),
        PolylineLayer(polylines: [
          Polyline(
            points: _routePath,
            color: Colors.blue,
            strokeWidth: 4.0,
          ),
        ]),
        MarkerLayer(markers: _buildMarkers()),
      ],
    );
  }

  void _handleTap(TapPosition position, LatLng latLng) {
    // Tähän voit lisätä logiikan reittipisteiden lisäämiselle
    print('Tapped at: $latLng');
    setState(() {
       _routePath.add(latLng);
    });
  }

  List<Marker> _buildMarkers() {
    return _routePath.map((point) {
      return Marker(
        width: 80.0,
        height: 80.0,
        point: point,
        // KORJATTU: 'builder' on päivitetty 'child'-nimeen
        child: const Icon(
          Icons.location_on,
          color: Colors.red,
          size: 40.0,
        ),
      );
    }).toList();
  }
}