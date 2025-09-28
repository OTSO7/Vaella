import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/daily_route_model.dart';
import '../utils/map_helpers.dart';

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

class _MapEditingPageState extends State<MapEditingPage> with TickerProviderStateMixin {
  // Controllers
  final MapController _mapController = MapController();
  late AnimationController _panelAnimationController;
  late Animation<double> _panelAnimation;
  
  // Route data
  late List<DailyRoute> _modifiedRoutes;
  List<double> _elevationProfile = [];
  List<double> _distances = [];
  List<bool> _segmentIsDirectLine = [];
  
  // UI State
  bool _isLoading = false;
  bool _useDirectLineForNext = false;
  bool _isPanelExpanded = true;
  bool _showInstructions = true;
  
  // Constants
  static const String _orsApiKey = 
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImRjNTNkYjcxNWYwYTQ0YjA4NzdhM2JjODc5ZmQ5ZDE5IiwiaCI6Im11cm11cjY0In0=';
  static const double _collapsedPanelHeight = 100.0;
  static const double _expandedPanelHeight = 100.0;  // Same as collapsed since no graph

  DailyRoute get _activeRoute => _modifiedRoutes[widget.editingDayIndex];
  bool get _hasRoute => _activeRoute.points.isNotEmpty;
  bool get _canUndo => _activeRoute.userClickedPoints.isNotEmpty;
  bool get _canClear => _activeRoute.userClickedPoints.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeRoutes();
    _checkForInstructions();
  }

  void _initializeAnimations() {
    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _panelAnimation = Tween<double>(
      begin: _collapsedPanelHeight,
      end: _expandedPanelHeight,
    ).animate(CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeInOut,
    ));
    if (_isPanelExpanded) {
      _panelAnimationController.forward();
    }
  }

  void _initializeRoutes() {
    // Create deep copies of routes to ensure each has independent data
    _modifiedRoutes = widget.allDailyRoutes.map((route) => DailyRoute(
      dayIndex: route.dayIndex,
      points: List.from(route.points),
      notes: route.notes,
      colorValue: route.colorValue,
      summary: RouteSummary(
        distance: route.summary.distance,
        duration: route.summary.duration,
        ascent: route.summary.ascent,
        descent: route.summary.descent,
      ),
      userClickedPoints: List.from(route.userClickedPoints),
      elevationProfile: List.from(route.elevationProfile),
      distances: List.from(route.distances),
    )).toList();
    
    // Load existing elevation data for the current route if available
    if (widget.editingDayIndex < _modifiedRoutes.length) {
      final currentRoute = _modifiedRoutes[widget.editingDayIndex];
      _elevationProfile = List.from(currentRoute.elevationProfile);
      _distances = List.from(currentRoute.distances);
    }
    
    _autoContinueRouteIfNeeded();
  }

  void _checkForInstructions() {
    // Hide instructions if user has already added points
    if (_activeRoute.userClickedPoints.isNotEmpty) {
      setState(() => _showInstructions = false);
    }
  }

  @override
  void dispose() {
    _panelAnimationController.dispose();
    super.dispose();
  }

  void _autoContinueRouteIfNeeded() {
    if (widget.editingDayIndex > 0) {
      final currentRoute = _modifiedRoutes[widget.editingDayIndex];
      if (currentRoute.userClickedPoints.isEmpty) {
        final previousRoute = _modifiedRoutes[widget.editingDayIndex - 1];
        if (previousRoute.userClickedPoints.isNotEmpty) {
          final lastPoint = previousRoute.userClickedPoints.last;
          setState(() {
            // Create a new route with updated userClickedPoints
            _modifiedRoutes[widget.editingDayIndex] = DailyRoute(
              dayIndex: currentRoute.dayIndex,
              points: [lastPoint],
              notes: currentRoute.notes,
              colorValue: currentRoute.colorValue,
              summary: currentRoute.summary,
              userClickedPoints: [lastPoint],
              elevationProfile: [],
              distances: [],
            );
          });
        }
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
          padding: EdgeInsets.only(
            left: 50,
            right: 50,
            top: 50,
            bottom: _isPanelExpanded ? _expandedPanelHeight + 50 : _collapsedPanelHeight + 50,
          ),
        ),
      );
    } else if (pointsToFit.isNotEmpty) {
      _mapController.move(pointsToFit.first, 13.0);
    } else if (widget.planLocation != null) {
      _mapController.move(widget.planLocation!, 10.0);
    }
  }

  void _handleMapTap(LatLng point) {
    HapticFeedback.lightImpact();
    if (_showInstructions) {
      setState(() => _showInstructions = false);
    }
    _addPointToRoute(point);
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // meters
    final lat1Rad = start.latitudeInRad;
    final lat2Rad = end.latitudeInRad;
    final deltaLatRad = (end.latitude - start.latitude) * (math.pi / 180);
    final deltaLngRad = (end.longitude - start.longitude) * (math.pi / 180);

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _calculateHikingDuration({
    required double distanceMeters,
    required double ascentMeters,
  }) {
    final distanceKm = distanceMeters / 1000;
    final minutesForDistance = distanceKm * 15;
    final minutesForAscent = ascentMeters / 10;
    final totalMinutes = minutesForDistance + minutesForAscent;
    return totalMinutes * 60;
  }

  (List<LatLng>, RouteSummary) _createDirectRoute(LatLng start, LatLng end) {
    final distance = _calculateDistance(start, end);
    final duration = _calculateHikingDuration(
      distanceMeters: distance,
      ascentMeters: 0,
    );
    
    final summary = RouteSummary(
      distance: distance,
      duration: duration,
      ascent: 0,
      descent: 0,
    );
    
    // Create intermediate points for smoother line
    final points = <LatLng>[start];
    const steps = 10;
    for (int i = 1; i < steps; i++) {
      final ratio = i / steps;
      final lat = start.latitude + (end.latitude - start.latitude) * ratio;
      final lng = start.longitude + (end.longitude - start.longitude) * ratio;
      points.add(LatLng(lat, lng));
    }
    points.add(end);
    
    return (points, summary);
  }

  Future<(List<LatLng>, RouteSummary, List<double>)?> _fetchRouteFromORS(
    LatLng start,
    LatLng end, {
    bool useDirectLine = false,
  }) async {
    if (useDirectLine) {
      final (points, summary) = _createDirectRoute(start, end);
      return (points, summary, <double>[]);
    }

    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/foot-hiking/geojson',
    );
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': _orsApiKey,
    };
    final body = json.encode({
      "coordinates": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude],
      ],
      "elevation": true,
    });

    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['features'][0]['geometry']['coordinates'] as List;
        final points = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();

        final elevations = <double>[];
        for (var coord in coords) {
          if (coord.length > 2) {
            elevations.add((coord[2] as num).toDouble());
          }
        }

        final distance = (data['features'][0]['properties']['summary']['distance'] as num?)
                ?.toDouble() ?? 0.0;
        final ascent = (data['features'][0]['properties']['ascent'] as num?)
                ?.toDouble() ?? 0.0;
        final descent = (data['features'][0]['properties']['descent'] as num?)
                ?.toDouble() ?? 0.0;

        final duration = _calculateHikingDuration(
          distanceMeters: distance,
          ascentMeters: ascent,
        );

        final summary = RouteSummary(
          distance: distance,
          duration: duration,
          ascent: ascent,
          descent: descent,
        );
        
        return (points, summary, elevations);
      }
    } catch (e) {
      debugPrint("Routing error: $e");
    }

    // Fallback to direct line
    final (points, summary) = _createDirectRoute(start, end);
    return (points, summary, <double>[]);
  }

  Future<void> _recalculateCurrentDayRoute() async {
    final currentRoute = _modifiedRoutes[widget.editingDayIndex];
    
    if (!mounted || currentRoute.userClickedPoints.length < 2) {
      setState(() {
        if (currentRoute.userClickedPoints.length < 2) {
          // Create a new route with updated points but cleared elevation data
          _modifiedRoutes[widget.editingDayIndex] = DailyRoute(
            dayIndex: currentRoute.dayIndex,
            points: List.from(currentRoute.userClickedPoints),
            notes: currentRoute.notes,
            colorValue: currentRoute.colorValue,
            summary: RouteSummary(),
            userClickedPoints: List.from(currentRoute.userClickedPoints),
            elevationProfile: [],
            distances: [],
          );
          _elevationProfile = [];
          _distances = [];
        }
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newPoints = <LatLng>[];
      final allElevations = <double>[];
      final allDistances = <double>[];
      var newSummary = RouteSummary();
      double cumulativeDistance = 0;

      for (int i = 0; i < currentRoute.userClickedPoints.length - 1; i++) {
        final start = currentRoute.userClickedPoints[i];
        final end = currentRoute.userClickedPoints[i + 1];
        final useDirectLine = i < _segmentIsDirectLine.length && _segmentIsDirectLine[i];
        
        final result = await _fetchRouteFromORS(start, end, useDirectLine: useDirectLine);
        
        if (result != null) {
          final (points, summary, elevations) = result;
          
          // Store the starting index for this segment
          final segmentStartIdx = newPoints.length;
          
          // Remove duplicate start point if needed
          if (newPoints.isNotEmpty && points.isNotEmpty) {
            points.removeAt(0);
            if (elevations.isNotEmpty) {
              elevations.removeAt(0);
            }
          }
          
          // Add points and calculate distances
          for (int j = 0; j < points.length; j++) {
            if (j > 0 || newPoints.isEmpty) {
              if (newPoints.isNotEmpty) {
                cumulativeDistance += _calculateDistance(
                  j == 0 ? newPoints.last : points[j-1], 
                  points[j]
                );
              }
              allDistances.add(cumulativeDistance);
            }
          }
          
          // Handle elevation data
          if (elevations.isNotEmpty) {
            // We have real elevation data
            allElevations.addAll(elevations);
          } else {
            // No elevation data (direct line or fallback), generate fake elevations
            // Use a base elevation and add small variations
            final baseElevation = allElevations.isNotEmpty ? allElevations.last : 200.0;
            for (int j = 0; j < points.length; j++) {
              allElevations.add(baseElevation + (math.Random().nextDouble() - 0.5) * 10);
            }
          }
          
          newPoints.addAll(points);
          newSummary += summary;
        }
      }

      // Ensure we have matching lengths
      print('Debug: Points: ${newPoints.length}, Elevations: ${allElevations.length}, Distances: ${allDistances.length}');
      
      // If we have points but no elevations, generate dummy elevations
      if (newPoints.isNotEmpty && allElevations.isEmpty) {
        for (int i = 0; i < newPoints.length; i++) {
          allElevations.add(200.0 + (math.Random().nextDouble() - 0.5) * 20);
        }
      }
      
      // If we have points but no distances, calculate them
      if (newPoints.isNotEmpty && allDistances.isEmpty) {
        double cumDist = 0;
        for (int i = 0; i < newPoints.length; i++) {
          if (i > 0) {
            cumDist += _calculateDistance(newPoints[i-1], newPoints[i]);
          }
          allDistances.add(cumDist);
        }
      }

      if (mounted) {
        setState(() {
          // Create a completely new route with the calculated data
          _modifiedRoutes[widget.editingDayIndex] = DailyRoute(
            dayIndex: currentRoute.dayIndex,
            points: newPoints,
            notes: currentRoute.notes,
            colorValue: currentRoute.colorValue,
            summary: newSummary,
            userClickedPoints: List.from(currentRoute.userClickedPoints),
            elevationProfile: List.from(allElevations),
            distances: List.from(allDistances),
          );
          _elevationProfile = List.from(allElevations);
          _distances = List.from(allDistances);
        });
        _fitMapToRoute();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addPointToRoute(LatLng point) {
    final currentRoute = _modifiedRoutes[widget.editingDayIndex];
    
    if (currentRoute.userClickedPoints.isNotEmpty) {
      _segmentIsDirectLine.add(_useDirectLineForNext);
    }
    
    setState(() {
      // Create a new route with updated userClickedPoints
      final updatedClickedPoints = List<LatLng>.from(currentRoute.userClickedPoints)..add(point);
      _modifiedRoutes[widget.editingDayIndex] = DailyRoute(
        dayIndex: currentRoute.dayIndex,
        points: currentRoute.points,
        notes: currentRoute.notes,
        colorValue: currentRoute.colorValue,
        summary: currentRoute.summary,
        userClickedPoints: updatedClickedPoints,
        elevationProfile: currentRoute.elevationProfile,
        distances: currentRoute.distances,
      );
    });
    
    _recalculateCurrentDayRoute();
  }

  void _clearCurrentDayRoute() {
    final currentRoute = _modifiedRoutes[widget.editingDayIndex];
    
    setState(() {
      List<LatLng> newUserClickedPoints = [];
      
      if (widget.editingDayIndex > 0 &&
          _modifiedRoutes[widget.editingDayIndex - 1].points.isNotEmpty) {
        // Keep the first point if it's from the previous day
        if (currentRoute.userClickedPoints.isNotEmpty) {
          newUserClickedPoints = [currentRoute.userClickedPoints.first];
        }
      }
      
      _segmentIsDirectLine.clear();
      _elevationProfile = [];
      _distances = [];
      
      // Create a completely new route with cleared data
      _modifiedRoutes[widget.editingDayIndex] = DailyRoute(
        dayIndex: currentRoute.dayIndex,
        points: [],
        notes: currentRoute.notes,
        colorValue: currentRoute.colorValue,
        summary: RouteSummary(),
        userClickedPoints: newUserClickedPoints,
        elevationProfile: [],
        distances: [],
      );
    });
    _recalculateCurrentDayRoute();
  }

  void _undoLastPoint() {
    if (!_canUndo) return;
    
    final currentRoute = _modifiedRoutes[widget.editingDayIndex];
    
    if (widget.editingDayIndex > 0 &&
        currentRoute.userClickedPoints.length == 1 &&
        _modifiedRoutes[widget.editingDayIndex - 1].points.isNotEmpty) {
      return;
    }
    
    setState(() {
      // Create a new route with the last point removed
      final updatedClickedPoints = List<LatLng>.from(currentRoute.userClickedPoints)..removeLast();
      _modifiedRoutes[widget.editingDayIndex] = DailyRoute(
        dayIndex: currentRoute.dayIndex,
        points: currentRoute.points,
        notes: currentRoute.notes,
        colorValue: currentRoute.colorValue,
        summary: currentRoute.summary,
        userClickedPoints: updatedClickedPoints,
        elevationProfile: currentRoute.elevationProfile,
        distances: currentRoute.distances,
      );
      
      if (_segmentIsDirectLine.isNotEmpty) {
        _segmentIsDirectLine.removeLast();
      }
    });
    _recalculateCurrentDayRoute();
  }

  void _togglePanel() {
    // No need to toggle anymore since panel is always the same height
    // Keep method for compatibility but do nothing
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arrowMarkers = generateArrowMarkersForDays(_modifiedRoutes);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Day ${widget.editingDayIndex + 1} Route',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_hasRoute)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(_modifiedRoutes),
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text(
                'Save',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              onMapReady: () {
                Future.delayed(const Duration(milliseconds: 100), _fitMapToRoute);
              },
              initialCenter: widget.planLocation ?? const LatLng(65.0, 25.5),
              initialZoom: widget.planLocation != null ? 10.0 : 5.0,
              onTap: (_, point) => _handleMapTap(point),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.treknote.app',
              ),
              // All routes
              PolylineLayer(
                polylines: _modifiedRoutes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final route = entry.value;
                  final isActive = index == widget.editingDayIndex;
                  
                  return Polyline(
                    points: route.points,
                    strokeWidth: isActive ? 5.0 : 3.0,
                    color: isActive
                        ? route.routeColor
                        : route.routeColor.withOpacity(0.4),
                    borderStrokeWidth: isActive ? 2.0 : 1.0,
                    borderColor: Colors.white.withOpacity(isActive ? 0.8 : 0.4),
                  );
                }).toList(),
              ),
              // Arrow markers
              MarkerLayer(markers: arrowMarkers),
              // User clicked points
              MarkerLayer(
                markers: _activeRoute.userClickedPoints.asMap().entries.map((entry) {
                  final index = entry.key;
                  final point = entry.value;
                  final isLast = index == _activeRoute.userClickedPoints.length - 1;
                  
                  return Marker(
                    width: isLast ? 35.0 : 30.0,
                    height: isLast ? 35.0 : 30.0,
                    point: point,
                    child: GestureDetector(
                      onTap: () {
                        if (isLast) _undoLastPoint();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isLast
                              ? theme.colorScheme.secondary
                              : _activeRoute.routeColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: isLast ? 3.0 : 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isLast ? 12 : 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Attribution
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap',
                    onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                  ),
                ],
              ),
            ],
          ),
          
          // Instructions overlay
          if (_showInstructions && _activeRoute.userClickedPoints.isEmpty)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tap on the map to add route points',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _showInstructions = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          
          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _panelAnimation,
              builder: (context, child) {
                return Container(
                  height: _panelAnimation.value,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: _buildBottomPanel(theme),
                );
              },
            ),
          ),
          
          // Floating action buttons
          Positioned(
            bottom: _isPanelExpanded ? _expandedPanelHeight + 16 : _collapsedPanelHeight + 16,
            left: 16,
            child: Column(
              children: [
                // Direct line toggle
                FloatingActionButton(
                  heroTag: 'direct_line',
                  onPressed: () {
                    setState(() => _useDirectLineForNext = !_useDirectLineForNext);
                    HapticFeedback.lightImpact();
                  },
                  backgroundColor: _useDirectLineForNext
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  child: Icon(
                    _useDirectLineForNext ? Icons.timeline : Icons.route,
                    color: _useDirectLineForNext
                        ? Colors.white
                        : theme.colorScheme.primary,
                  ),
                ),
                if (_useDirectLineForNext)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Direct',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          Positioned(
            bottom: _isPanelExpanded ? _expandedPanelHeight + 16 : _collapsedPanelHeight + 16,
            right: 16,
            child: Column(
              children: [
                // Undo button
                FloatingActionButton(
                  heroTag: 'undo',
                  mini: true,
                  onPressed: _canUndo ? _undoLastPoint : null,
                  backgroundColor: _canUndo
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceVariant,
                  child: Icon(
                    Icons.undo,
                    color: _canUndo
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                // Clear button
                FloatingActionButton(
                  heroTag: 'clear',
                  onPressed: _canClear ? _clearCurrentDayRoute : null,
                  backgroundColor: _canClear
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.surfaceVariant,
                  child: Icon(
                    Icons.clear_all,
                    color: _canClear
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Calculating route...',
                        style: GoogleFonts.poppins(fontSize: 14),
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

  Widget _buildBottomPanel(ThemeData theme) {
    return Column(
      children: [
        // Handle bar
        GestureDetector(
          onTap: _togglePanel,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        
        // Stats row
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  icon: Icons.route,
                  value: _formatDistance(_activeRoute.summary.distance),
                  label: 'Distance',
                  theme: theme,
                  isLarge: true,
                ),
                _buildStatItem(
                  icon: Icons.schedule,
                  value: _formatDuration(_activeRoute.summary.duration),
                  label: 'Duration',
                  theme: theme,
                ),
                _buildStatItem(
                  icon: Icons.trending_up,
                  value: '${_activeRoute.summary.ascent.toStringAsFixed(0)}m',
                  label: 'Ascent',
                  theme: theme,
                  color: Colors.green,
                ),
                _buildStatItem(
                  icon: Icons.trending_down,
                  value: '${_activeRoute.summary.descent.toStringAsFixed(0)}m',
                  label: 'Descent',
                  theme: theme,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required ThemeData theme,
    bool isLarge = false,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color ?? theme.colorScheme.primary,
          size: isLarge ? 24 : 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.lato(
            fontSize: isLarge ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // Removed elevation graph methods as they are no longer needed

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  String _formatDuration(double seconds) {
    if (seconds == 0) return '0min';
    final duration = Duration(seconds: seconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}min';
  }
}