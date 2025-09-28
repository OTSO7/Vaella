import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ElevationService {
  // Using Open-Elevation API (free, no key required)
  static const String _openElevationUrl = 'https://api.open-elevation.com/api/v1/lookup';
  
  // Alternative: MapBox Terrain API (requires free API key)
  static const String _mapboxTerrainUrl = 'https://api.mapbox.com/v4/mapbox.terrain-rgb';
  
  // Get elevation data for a list of points
  static Future<List<ElevationPoint>> getElevations(List<LatLng> points) async {
    if (points.isEmpty) return [];
    
    try {
      // Batch process points (Open-Elevation supports up to 100 points per request)
      List<ElevationPoint> allElevations = [];
      const int batchSize = 100;
      
      for (int i = 0; i < points.length; i += batchSize) {
        final end = (i + batchSize < points.length) ? i + batchSize : points.length;
        final batch = points.sublist(i, end);
        
        final elevations = await _fetchElevationBatch(batch);
        allElevations.addAll(elevations);
      }
      
      return allElevations;
    } catch (e) {
      print('Error fetching elevation data: $e');
      // Return points with zero elevation as fallback
      return points.map((p) => ElevationPoint(
        latitude: p.latitude,
        longitude: p.longitude,
        elevation: 0,
      )).toList();
    }
  }
  
  static Future<List<ElevationPoint>> _fetchElevationBatch(List<LatLng> points) async {
    final locations = points.map((p) => {
      'latitude': p.latitude,
      'longitude': p.longitude,
    }).toList();
    
    final response = await http.post(
      Uri.parse(_openElevationUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'locations': locations}),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;
      
      return results.map((r) => ElevationPoint(
        latitude: r['latitude'].toDouble(),
        longitude: r['longitude'].toDouble(),
        elevation: r['elevation'].toDouble(),
      )).toList();
    } else {
      throw Exception('Failed to fetch elevation data: ${response.statusCode}');
    }
  }
  
  // Calculate elevation profile statistics
  static ElevationProfile calculateProfile(List<ElevationPoint> points) {
    if (points.isEmpty) {
      return ElevationProfile(
        minElevation: 0,
        maxElevation: 0,
        totalAscent: 0,
        totalDescent: 0,
        averageElevation: 0,
      );
    }
    
    double minElevation = points.first.elevation;
    double maxElevation = points.first.elevation;
    double totalAscent = 0;
    double totalDescent = 0;
    double elevationSum = points.first.elevation;
    
    for (int i = 1; i < points.length; i++) {
      final current = points[i].elevation;
      final previous = points[i - 1].elevation;
      final diff = current - previous;
      
      if (diff > 0) {
        totalAscent += diff;
      } else {
        totalDescent += diff.abs();
      }
      
      if (current < minElevation) minElevation = current;
      if (current > maxElevation) maxElevation = current;
      elevationSum += current;
    }
    
    return ElevationProfile(
      minElevation: minElevation,
      maxElevation: maxElevation,
      totalAscent: totalAscent,
      totalDescent: totalDescent,
      averageElevation: elevationSum / points.length,
    );
  }
  
  // Get terrain tiles URL for MapLibre GL
  static String getTerrainTilesUrl() {
    // Using Terrarium tiles (free, no key required)
    return 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png';
  }
  
  // Get hillshade tiles URL for visual enhancement
  static String getHillshadeTilesUrl() {
    // Using ESRI hillshade tiles (free)
    return 'https://services.arcgisonline.com/ArcGIS/rest/services/Elevation/World_Hillshade/MapServer/tile/{z}/{y}/{x}';
  }
}

class ElevationPoint {
  final double latitude;
  final double longitude;
  final double elevation;
  
  ElevationPoint({
    required this.latitude,
    required this.longitude,
    required this.elevation,
  });
  
  LatLng toLatLng() => LatLng(latitude, longitude);
}

class ElevationProfile {
  final double minElevation;
  final double maxElevation;
  final double totalAscent;
  final double totalDescent;
  final double averageElevation;
  
  ElevationProfile({
    required this.minElevation,
    required this.maxElevation,
    required this.totalAscent,
    required this.totalDescent,
    required this.averageElevation,
  });
  
  double get elevationGain => maxElevation - minElevation;
}