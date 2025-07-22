import 'package:latlong2/latlong.dart';

class DailyRoute {
  final int dayIndex;
  List<LatLng> points;

  DailyRoute({required this.dayIndex, required this.points});

  Map<String, dynamic> toMap() {
    return {
      'dayIndex': dayIndex,
      'points':
          points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    };
  }

  factory DailyRoute.fromMap(Map<String, dynamic> map) {
    return DailyRoute(
      dayIndex: map['dayIndex'] as int,
      points: (map['points'] as List)
          .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
          .toList(),
    );
  }
}
