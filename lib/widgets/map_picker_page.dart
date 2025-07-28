// lib/widgets/map_picker_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapPickerPage extends StatefulWidget {
  final LatLng initialLocation;

  const MapPickerPage({super.key, required this.initialLocation});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  late LatLng _pickedLocation;
  String _pickedAddress = 'Liikuta karttaa valitaksesi sijainnin...';
  bool _isLoadingAddress = false;
  final MapController _mapController = MapController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
    _reverseGeocodeWithPhoton(_pickedLocation);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _handleMapMoved(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _pickedLocation = camera.center;
        _pickedAddress = 'Haetaan nimeä...';
        _isLoadingAddress = true;
      });

      if (_debounce?.isActive ?? false) _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 750), () {
        _reverseGeocodeWithPhoton(_pickedLocation);
      });
    }
  }

  // --- KOKONAAN UUSITTU LOGIIKKA ÄLYKKÄÄMMÄLLÄ HAULLA ---
  Future<void> _reverseGeocodeWithPhoton(LatLng location) async {
    if (!mounted) return;
    setState(() => _isLoadingAddress = true);

    final uri = Uri.https('photon.komoot.io', '/reverse', {
      'lon': location.longitude.toString(),
      'lat': location.latitude.toString(),
    });

    try {
      final response = await http.get(uri);
      String displayAddress = 'Tuntematon sijainti';

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final features = data['features'] as List;

        if (features.isNotEmpty) {
          final properties =
              features.first['properties'] as Map<String, dynamic>;

          final name = properties['name'];
          final city = properties['city'];
          final county = properties['county'];
          final country = properties['country'];

          // Muodostetaan älykkäästi paras mahdollinen nimi
          if (name != null) {
            displayAddress =
                (city != null && city != name) ? '$name, $city' : name;
          } else if (city != null) {
            displayAddress = city;
          } else if (county != null) {
            displayAddress = county;
          } else if (country != null) {
            displayAddress = country;
          }
        }
      }

      if (mounted) {
        setState(() {
          _pickedAddress = displayAddress;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pickedAddress = 'Nimen haku epäonnistui';
        });
      }
      debugPrint("Photon reverse geocoding failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Valitse sijainti kartalta'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickedLocation,
              initialZoom: 10.0,
              minZoom: 2.0,
              maxZoom: 18.0,
              onTap: (tapPosition, latlng) {
                _mapController.move(latlng, _mapController.camera.zoom);
              },
              onPositionChanged: _handleMapMoved,
              keepAlive: true,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.treknoteflutter',
              ),
            ],
          ),
          Center(
            child: Icon(
              Icons.location_on,
              color: theme.colorScheme.primary,
              size: 48,
              shadows: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24.0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _pickedAddress,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_isLoadingAddress)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: LinearProgressIndicator(),
                      )
                    else
                      Text(
                        'Lat: ${_pickedLocation.latitude.toStringAsFixed(4)}, Lon: ${_pickedLocation.longitude.toStringAsFixed(4)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Vahvista sijainti'),
                        onPressed: !_isLoadingAddress
                            ? () {
                                Navigator.pop(context, {
                                  'location': _pickedLocation,
                                  'name': _pickedAddress
                                });
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
