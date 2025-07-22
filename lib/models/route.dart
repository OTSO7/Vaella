// KORJATTU: Oikea importti flutter_map-yhteensopivuutta varten
import 'package:latlong2/latlong.dart';

class HikingRoute {
  final String? name;
  final List<LatLng> waypoints;
  final double distanceMeters;

  // Lisätty 'const' konstruktoriin hyvän ohjelmointitavan mukaisesti
  const HikingRoute({
    this.name,
    required this.waypoints,
    required this.distanceMeters,
  });

  HikingRoute copyWith({
    String? name,
    List<LatLng>? waypoints,
    double? distanceMeters,
  }) {
    return HikingRoute(
      name: name ?? this.name,
      waypoints: waypoints ?? this.waypoints,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }
}
