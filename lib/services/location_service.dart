// lib/services/location_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocationSuggestion extends Equatable {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final bool isPopular;

  const LocationSuggestion({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.isPopular = false,
  });

  @override
  List<Object?> get props => [title, subtitle, latitude, longitude, isPopular];
}

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<LocationSuggestion>> getPopularLocations() async {
    try {
      final snapshot = await _firestore
          .collection('popular_locations')
          .orderBy('name')
          .get();
      if (snapshot.docs.isEmpty) return [];

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return LocationSuggestion(
          title: data['name'] ?? 'N/A',
          subtitle: data['area'] ?? 'N/A',
          latitude: (data['lat'] as num?)?.toDouble() ?? 0.0,
          longitude: (data['lon'] as num?)?.toDouble() ?? 0.0,
          isPopular: true,
        );
      }).toList();
    } catch (e) {
      debugPrint("Error fetching popular locations: $e");
      return [];
    }
  }

  Future<List<LocationSuggestion>> searchLocations(String query) async {
    // KORJATTU: Poistettu 'lang': 'fi' -parametri, jota Photon API ei tue.
    final uri = Uri.https(
      'photon.komoot.io',
      '/api/',
      {
        'q': query,
        'limit': '5',
      },
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint(
            "Photon API error: ${response.statusCode}, Body: ${response.body}");
        return [];
      }

      final data = json.decode(utf8.decode(response.bodyBytes));
      final features = data['features'] as List;

      return features
          .map<LocationSuggestion?>((feature) {
            try {
              final properties = feature['properties'] as Map<String, dynamic>;
              final geometry = feature['geometry'] as Map<String, dynamic>;
              final coordinates = geometry['coordinates'] as List;
              final title = properties['name'] as String?;

              if (title == null || title.isEmpty) {
                return null;
              }

              final subtitleParts = [
                properties['city'],
                properties['state'],
                properties['country']
              ].whereType<String>().toSet().toList();

              return LocationSuggestion(
                title: title,
                subtitle: subtitleParts.join(', '),
                latitude: (coordinates[1] as num).toDouble(),
                longitude: (coordinates[0] as num).toDouble(),
              );
            } catch (e) {
              debugPrint(
                  "Failed to parse a single Photon feature, skipping it. Error: $e");
              return null;
            }
          })
          .whereType<LocationSuggestion>()
          .toList();
    } catch (e) {
      debugPrint("Photon search failed with exception: $e");
      return [];
    }
  }
}
