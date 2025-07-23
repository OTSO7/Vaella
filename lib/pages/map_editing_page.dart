// lib/pages/map_editing_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

import '../models/daily_route_model.dart';
import 'route_planner_page.dart'; // Tarvitaan RouteSummary-luokkaa varten

class MapEditingPage extends StatefulWidget {
  final DailyRoute initialRoute;
  const MapEditingPage({super.key, required this.initialRoute});

  @override
  State<MapEditingPage> createState() => _MapEditingPageState();
}

class _MapEditingPageState extends State<MapEditingPage> {
  final MapController _mapController = MapController();
  late DailyRoute _currentRoute;
  bool _isLoading = false;

  final String _orsApiKey = 'LIITÄ_OMA_OPENROUTESERVICE_API_AVAIMESI_TÄHÄN';

  @override
  void initState() {
    super.initState();
    // Tehdään kopio, jotta alkuperäinen ei muutu ennen tallennusta
    _currentRoute = widget.initialRoute.copyWith();
  }

  void _handleLongPress(LatLng point) {
    HapticFeedback.mediumImpact();
    _addPointToRoute(point);
  }

  Future<(List<LatLng>, RouteSummary)?> _fetchRouteFromORS(
      LatLng start, LatLng end) async {
    if (_orsApiKey.contains('YOUR_') || _orsApiKey.isEmpty) {
      return null;
    }
    final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/foot-hiking/geojson');
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': _orsApiKey
    };
    final body = json.encode({
      "coordinates": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude]
      ],
      "extra_info": ["steepness"],
      "elevation": true
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['features'][0]['geometry']['coordinates'] as List;
        final summaryData = data['features'][0]['properties']['summary'];
        final points = coords.map((c) => LatLng(c[1], c[0])).toList();
        final summary = RouteSummary(
          distance: (summaryData['distance'] as num?)?.toDouble() ?? 0.0,
          duration: (summaryData['duration'] as num?)?.toDouble() ?? 0.0,
          ascent: (data['features'][0]['properties']['ascent'] as num?)
                  ?.toDouble() ??
              0.0,
          descent: (data['features'][0]['properties']['descent'] as num?)
                  ?.toDouble() ??
              0.0,
        );
        return (points, summary);
      }
    } catch (e) {
      print("ORS Exception: $e");
    }
    return null;
  }

  Future<void> _recalculateCurrentDayRoute() async {
    setState(() => _isLoading = true);
    _currentRoute.points.clear();
    _currentRoute.summary = RouteSummary();

    if (_currentRoute.userClickedPoints.length < 2) {
      _currentRoute.points.addAll(_currentRoute.userClickedPoints);
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    for (int i = 0; i < _currentRoute.userClickedPoints.length - 1; i++) {
      final start = _currentRoute.userClickedPoints[i];
      final end = _currentRoute.userClickedPoints[i + 1];
      final result = await _fetchRouteFromORS(start, end);
      if (result != null) {
        final (points, summary) = result;
        if (_currentRoute.points.isEmpty) {
          _currentRoute.points.addAll(points);
        } else {
          points.removeAt(0);
          _currentRoute.points.addAll(points);
        }
        _currentRoute.summary += summary;
      } else {
        if (_currentRoute.points.isEmpty) _currentRoute.points.add(start);
        _currentRoute.points.add(end);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _addPointToRoute(LatLng point) {
    setState(() => _currentRoute.userClickedPoints.add(point));
    _recalculateCurrentDayRoute();
  }

  void _clearCurrentDayRoute() {
    setState(() {
      _currentRoute.points.clear();
      _currentRoute.userClickedPoints.clear();
      _currentRoute.summary = RouteSummary();
    });
  }

  void _undoLastPoint() {
    if (_currentRoute.userClickedPoints.isNotEmpty) {
      setState(() => _currentRoute.userClickedPoints.removeLast());
      _recalculateCurrentDayRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Editing Day ${widget.initialRoute.dayIndex + 1}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        // MUUTOS: Tallennusnappi on nyt "Done"-nappi, joka palauttaa datan
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Confirm Changes',
            onPressed: () => context.pop(_currentRoute),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentRoute.points.isNotEmpty
                  ? _currentRoute.points.first
                  : const LatLng(65.0, 25.5),
              initialZoom: 10.0,
              onLongPress: (_, point) => _handleLongPress(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _currentRoute.points,
                    strokeWidth: 6.0,
                    color: theme.colorScheme.primary,
                    borderStrokeWidth: 1.0,
                    borderColor: Colors.black.withOpacity(0.2),
                  ),
                ],
              ),
              MarkerLayer(
                markers: _currentRoute.userClickedPoints.map((point) {
                  bool isFirst = _currentRoute.userClickedPoints.first == point;
                  bool isLast = _currentRoute.userClickedPoints.length > 1 &&
                      _currentRoute.userClickedPoints.last == point;
                  return Marker(
                    width: 24.0,
                    height: 24.0,
                    point: point,
                    child: Container(
                      decoration: BoxDecoration(
                          color: isLast
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.0),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4)
                          ]),
                      child: isFirst
                          ? Icon(Icons.flag,
                              size: 12, color: theme.colorScheme.onPrimary)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(bottom: 30, right: 10, child: _buildActionButtons(theme)),
          Positioned(
              bottom: 20,
              left: 20,
              right: 100,
              child: _buildStatsBar(theme, _currentRoute.summary)),
          if (_isLoading)
            Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  // Apumetodit pysyvät samoina
  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        FloatingActionButton(
            heroTag: 'undo_fab',
            mini: true,
            tooltip: 'Undo last point',
            onPressed: _undoLastPoint,
            child: const Icon(Icons.undo)),
        const SizedBox(height: 10),
        FloatingActionButton(
            heroTag: 'clear_fab',
            tooltip: 'Clear current day\'s route',
            onPressed: _clearCurrentDayRoute,
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
            child: const Icon(Icons.delete_sweep_outlined)),
      ],
    );
  }

  Widget _buildStatsBar(ThemeData theme, RouteSummary summary) {
    String formatDistance(double meters) {
      if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }

    String formatDuration(double seconds) {
      if (seconds == 0) return '0 m';
      final duration = Duration(seconds: seconds.toInt());
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      if (hours > 0) return '${hours}h ${minutes}m';
      return '${minutes}m';
    }

    return IgnorePointer(
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: theme.cardColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 2)
                ]),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(Icons.route_outlined,
                      formatDistance(summary.distance), theme),
                  _buildStatItem(Icons.timer_outlined,
                      formatDuration(summary.duration), theme),
                  _buildStatItem(Icons.arrow_upward_rounded,
                      '${summary.ascent.toStringAsFixed(0)} m', theme),
                  _buildStatItem(Icons.arrow_downward_rounded,
                      '${summary.descent.toStringAsFixed(0)} m', theme)
                ])));
  }

  Widget _buildStatItem(IconData icon, String value, ThemeData theme) {
    return Flexible(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: theme.colorScheme.secondary, size: 18),
      const SizedBox(width: 6),
      Text(value,
          style: GoogleFonts.lato(
              color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold))
    ]));
  }
}
