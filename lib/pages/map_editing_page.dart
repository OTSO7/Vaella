import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// KORJATTU: Tuodaan mallit suoraan, ei koko route_planner_pagea.
import '../models/daily_route_model.dart';

class MapEditingPage extends StatefulWidget {
  final List<DailyRoute> allDailyRoutes;
  final int editingDayIndex;
  final LatLng? planLocation;

  const MapEditingPage({
    super.key,
    required this.allDailyRoutes,
    required this.editingDayIndex,
    this.planLocation,
  });

  @override
  State<MapEditingPage> createState() => _MapEditingPageState();
}

class _MapEditingPageState extends State<MapEditingPage> {
  final MapController _mapController = MapController();
  late List<DailyRoute> _modifiedRoutes;
  bool _isLoading = false;

  final String _orsApiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImRjNTNkYjcxNWYwYTQ0YjA4NzdhM2JjODc5ZmQ5ZDE5IiwiaCI6Im11cm11cjY0In0=';

  // KORJATTU: Varmistetaan, että aktiivinen reitti on aina ajan tasalla.
  DailyRoute get _activeRoute => _modifiedRoutes[widget.editingDayIndex];

  @override
  void initState() {
    super.initState();
    // Luodaan syvä kopio, jotta emme muokkaa alkuperäistä listaa vahingossa.
    _modifiedRoutes =
        widget.allDailyRoutes.map((route) => route.copyWith()).toList();
    _autoContinueRouteIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToRoute();
    });
  }

  void _autoContinueRouteIfNeeded() {
    if (widget.editingDayIndex > 0 && _activeRoute.userClickedPoints.isEmpty) {
      final previousRoute = _modifiedRoutes[widget.editingDayIndex - 1];
      if (previousRoute.userClickedPoints.isNotEmpty) {
        final lastPoint = previousRoute.userClickedPoints.last;
        // KORJATTU: Muokataan listaa oikein
        setState(() {
          _activeRoute.userClickedPoints = [lastPoint];
          _activeRoute.points.clear();
          _activeRoute.points.add(lastPoint);
        });
      }
    }
  }

  void _fitMapToRoute() {
    if (!mounted) return;
    final pointsToFit = _activeRoute.points.isNotEmpty
        ? _activeRoute.points
        : _activeRoute.userClickedPoints;

    if (pointsToFit.length > 1) {
      _mapController.fitCamera(
        CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pointsToFit),
            padding: const EdgeInsets.all(50.0)),
      );
    } else if (pointsToFit.isNotEmpty) {
      _mapController.move(pointsToFit.first, 13.0);
    } else if (widget.planLocation != null) {
      _mapController.move(widget.planLocation!, 10.0);
    }
  }

  void _handleLongPress(LatLng point) {
    HapticFeedback.mediumImpact();
    _addPointToRoute(point);
  }

  Future<(List<LatLng>, RouteSummary)?> _fetchRouteFromORS(
      LatLng start, LatLng end) async {
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
      "elevation": true
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['features'][0]['geometry']['coordinates'] as List;
        final summaryData = data['features'][0]['properties']['summary'];
        final points =
            coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
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
      debugPrint("ORS Exception: $e");
    }
    return null;
  }

  Future<void> _recalculateCurrentDayRoute() async {
    setState(() => _isLoading = true);

    // Käytetään paikallisia muuttujia, jotta vältetään setState-ongelmat
    final newPoints = <LatLng>[];
    var newSummary = RouteSummary();

    if (_activeRoute.userClickedPoints.length < 2) {
      newPoints.addAll(_activeRoute.userClickedPoints);
    } else {
      for (int i = 0; i < _activeRoute.userClickedPoints.length - 1; i++) {
        final start = _activeRoute.userClickedPoints[i];
        final end = _activeRoute.userClickedPoints[i + 1];
        final result = await _fetchRouteFromORS(start, end);

        if (result != null) {
          final (points, summary) = result;
          if (newPoints.isNotEmpty) points.removeAt(0);
          newPoints.addAll(points);
          newSummary += summary;
        } else {
          if (newPoints.isEmpty) newPoints.add(start);
          newPoints.add(end);
        }
      }
    }

    if (mounted) {
      setState(() {
        _modifiedRoutes[widget.editingDayIndex] = _activeRoute.copyWith(
          points: newPoints,
          summary: newSummary,
        );
        _isLoading = false;
      });
      _fitMapToRoute();
    }
  }

  void _addPointToRoute(LatLng point) {
    setState(() {
      _activeRoute.userClickedPoints.add(point);
    });
    _recalculateCurrentDayRoute();
  }

  void _clearCurrentDayRoute() {
    setState(() {
      if (widget.editingDayIndex > 0 &&
          _modifiedRoutes[widget.editingDayIndex - 1].points.isNotEmpty) {
        // Säilytetään vain ensimmäinen piste, jos jatketaan edellisestä
        _activeRoute.userClickedPoints
            .removeRange(1, _activeRoute.userClickedPoints.length);
      } else {
        _activeRoute.userClickedPoints.clear();
      }
    });
    _recalculateCurrentDayRoute();
  }

  void _undoLastPoint() {
    if (_activeRoute.userClickedPoints.isNotEmpty) {
      // Estetään edellisen päivän päätepisteen poistaminen
      if (widget.editingDayIndex > 0 &&
          _activeRoute.userClickedPoints.length == 1 &&
          _modifiedRoutes[widget.editingDayIndex - 1].points.isNotEmpty) {
        return;
      }
      setState(() {
        _activeRoute.userClickedPoints.removeLast();
      });
      _recalculateCurrentDayRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Editing Day ${widget.editingDayIndex + 1}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Confirm Changes',
            onPressed: () => Navigator.of(context).pop(_modifiedRoutes),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.planLocation ?? const LatLng(65.0, 25.5),
              initialZoom: 5.0,
              onLongPress: (_, point) => _handleLongPress(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                retinaMode: RetinaMode.isHighDensity(context),
              ),
              PolylineLayer(
                polylines: _modifiedRoutes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final route = entry.value;
                  final bool isActive = index == widget.editingDayIndex;
                  return Polyline(
                    points: route.points,
                    strokeWidth: isActive ? 6.0 : 4.0,
                    color: isActive
                        ? route.routeColor
                        : route.routeColor.withOpacity(0.5),
                    borderStrokeWidth: 1.0,
                    borderColor: Colors.black.withOpacity(0.2),
                  );
                }).toList(),
              ),
              MarkerLayer(
                markers:
                    _activeRoute.userClickedPoints.asMap().entries.map((entry) {
                  final index = entry.key;
                  final point = entry.value;
                  return Marker(
                    width: 24.0,
                    height: 24.0,
                    point: point,
                    child: GestureDetector(
                      onTap: () {
                        // Mahdollisuus poistaa pisteitä klikkaamalla
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              index == _activeRoute.userClickedPoints.length - 1
                                  ? theme.colorScheme.secondary
                                  : _activeRoute.routeColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.0),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4)
                          ],
                        ),
                        child: Center(
                          child: Text((index + 1).toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
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
              child: _buildStatsBar(theme, _activeRoute.summary)),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

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
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Flexible(
                child: _buildStatItem(Icons.route_outlined,
                    formatDistance(summary.distance), theme)),
            Flexible(
                child: _buildStatItem(Icons.timer_outlined,
                    formatDuration(summary.duration), theme)),
            Flexible(
                child: _buildStatItem(Icons.arrow_upward_rounded,
                    '${summary.ascent.toStringAsFixed(0)} m', theme)),
            Flexible(
                child: _buildStatItem(Icons.arrow_downward_rounded,
                    '${summary.descent.toStringAsFixed(0)} m', theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.secondary, size: 18),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.lato(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}
