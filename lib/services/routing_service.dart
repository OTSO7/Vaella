// lib/services/routing_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  final String apiKey;

  RoutingService({required this.apiKey});

  Future<List<LatLng>> getRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) {
      return [];
    }

    final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/foot-hiking/geojson');

    final body = {
      'coordinates': waypoints.map((p) => [p.longitude, p.latitude]).toList()
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': apiKey,
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to get route (${response.statusCode}): ${response.body}');
    }

    final data = json.decode(response.body);

    final features = data['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      throw Exception('No route found between the selected points.');
    }

    final coords = features[0]['geometry']['coordinates'] as List<dynamic>;

    return coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }
}
