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
  bool _showInstructions = true;
  
  // Elevation graph interaction
  LatLng? _elevationMarkerPosition;
  double? _elevationMarkerDistance;
  
  // Panel drag state
  double _panelHeight = 100.0;
  double _dragStartHeight = 100.0;
  bool _isDragging = false;
  
  // Animation for FAB buttons
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  
  // Constants
  static const String _orsApiKey = 
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImRjNTNkYjcxNWYwYTQ0YjA4NzdhM2JjODc5ZmQ5ZDE5IiwiaCI6Im11cm11cjY0In0=';
  static const double _minPanelHeight = 100.0;
  static const double _maxPanelHeight = 350.0;

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
      begin: _minPanelHeight,
      end: _maxPanelHeight,
    ).animate(CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeInOutCubic,
    ));
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOutCubic,
    );
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
      
      print('Initial route data check:');
      print('  - Points: ${currentRoute.points.length}');
      print('  - Elevation data: ${currentRoute.elevationProfile.length}');
      print('  - Distance data: ${currentRoute.distances.length}');
      
      // ALWAYS recalculate elevation data when we have points
      // This ensures the graph shows correct data immediately when opening
      if (currentRoute.points.isNotEmpty) {
        print('Route has points, recalculating elevation data...');
        // Clear old data first
        _elevationProfile = [];
        _distances = [];
        
        // Schedule recalculation after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _recalculateElevationData();
        });
      } else {
        // No points, just clear the data
        _elevationProfile = [];
        _distances = [];
      }
    }
    
    _autoContinueRouteIfNeeded();
  }
  
  // Method to recalculate elevation data for existing routes
  Future<void> _recalculateElevationData() async {
    final currentRoute = _modifiedRoutes[widget.editingDayIndex];
    
    print('Recalculating elevation data for ${currentRoute.points.length} points');
    
    if (currentRoute.points.isEmpty) {
      print('No points to calculate elevation for');
      setState(() {
        _elevationProfile = [];
        _distances = [];
      });
      return;
    }
    
    final newElevations = <double>[];
    final newDistances = <double>[];
    double cumulativeDistance = 0;
    
    // Calculate distances for all points
    for (int i = 0; i < currentRoute.points.length; i++) {
      if (i > 0) {
        cumulativeDistance += _calculateDistance(
          currentRoute.points[i-1], 
          currentRoute.points[i]
        );
      }
      newDistances.add(cumulativeDistance);
    }
    
    // Check if we have real elevation data from the route
    bool hasValidElevation = currentRoute.elevationProfile.isNotEmpty && 
                             currentRoute.elevationProfile.length == currentRoute.points.length;
    
    if (hasValidElevation) {
      // Use existing REAL elevation data
      print('Using existing real elevation data from route');
      newElevations.addAll(currentRoute.elevationProfile);
    } else {
      // NO FAKE DATA - leave empty if we don't have real data
      print('No real elevation data available');
      // Keep elevations empty - will be handled in UI
    }
    
    print('Elevation points: ${newElevations.length}, Distance points: ${newDistances.length}');
    
    if (mounted) {
      setState(() {
        _elevationProfile = List.from(newElevations);
        _distances = List.from(newDistances);
        
        // Update the route with the new data
        _modifiedRoutes[widget.editingDayIndex] = DailyRoute(
          dayIndex: currentRoute.dayIndex,
          points: currentRoute.points,
          notes: currentRoute.notes,
          colorValue: currentRoute.colorValue,
          summary: currentRoute.summary,
          userClickedPoints: currentRoute.userClickedPoints,
          elevationProfile: List.from(newElevations),
          distances: List.from(newDistances),
        );
        
        print('State updated with elevation data');
      });
    }
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
    _fabAnimationController.dispose();
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
          bottom: _panelHeight + 50,
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

  Future<(List<LatLng>, RouteSummary, List<double>)> _createDirectRoute(LatLng start, LatLng end) async {
    final distance = _calculateDistance(start, end);
    
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
    
    // Fetch REAL elevation data for the points
    final elevations = await _fetchElevationForPoints(points);
    
    // Calculate real ascent/descent from elevation data
    double ascent = 0;
    double descent = 0;
    for (int i = 1; i < elevations.length; i++) {
      final diff = elevations[i] - elevations[i-1];
      if (diff > 0) ascent += diff;
      else descent += diff.abs();
    }
    
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
  
  // New method to fetch elevation data for specific points
  Future<List<double>> _fetchElevationForPoints(List<LatLng> points) async {
    // Use Open-Elevation API or similar service
    try {
      final locations = points.map((p) => {
        "latitude": p.latitude,
        "longitude": p.longitude,
      }).toList();
      
      final response = await http.post(
        Uri.parse('https://api.open-elevation.com/api/v1/lookup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"locations": locations}),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        return results.map((r) => (r['elevation'] as num).toDouble()).toList();
      }
    } catch (e) {
      print('Failed to fetch elevation data: $e');
    }
    
    // Return empty list if failed - NO FAKE DATA
    return [];
  }

  Future<(List<LatLng>, RouteSummary, List<double>)?> _fetchRouteFromORS(
    LatLng start,
    LatLng end, {
    bool useDirectLine = false,
  }) async {
    if (useDirectLine) {
      final result = await _createDirectRoute(start, end);
      return result;
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

    // Fallback to direct line with real elevation
    final result = await _createDirectRoute(start, end);
    return result;
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
          
          // Remove duplicate start point if needed
          final pointsToAdd = List<LatLng>.from(points);
          final elevsToAdd = List<double>.from(elevations);
          
          if (newPoints.isNotEmpty && pointsToAdd.isNotEmpty) {
            pointsToAdd.removeAt(0);
            if (elevsToAdd.isNotEmpty) {
              elevsToAdd.removeAt(0);
            }
          }
          
          // Add points and calculate distances for each point
          for (int j = 0; j < pointsToAdd.length; j++) {
            newPoints.add(pointsToAdd[j]);
            
            // Calculate cumulative distance
            if (newPoints.length > 1) {
              final prevPoint = newPoints[newPoints.length - 2];
              final currPoint = newPoints[newPoints.length - 1];
              cumulativeDistance += _calculateDistance(prevPoint, currPoint);
            }
            allDistances.add(cumulativeDistance);
            
            // Handle elevation data - ONLY use real data
            if (j < elevsToAdd.length) {
              // We have real elevation data (even if it's 0 - sea level is valid!)
              allElevations.add(elevsToAdd[j]);
            }
            // NO FAKE DATA - if no elevation, we'll have mismatched lengths which is OK
          }
          
          newSummary += summary;
        }
      }

      // Log data status
      print('Debug: Points: ${newPoints.length}, Elevations: ${allElevations.length}, Distances: ${allDistances.length}');
      
      // NO FAKE ELEVATION DATA - keep empty if we don't have real data
      
      // Calculate distances if needed (distances are calculated, not fake)
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
      
      // Reset panel height to minimum when adding first points
      if (!_hasRoute && updatedClickedPoints.length >= 2) {
        _panelHeight = _minPanelHeight;
      }
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
      
      // Reset panel to minimum height when clearing route
      _panelHeight = _minPanelHeight;
      _panelAnimationController.reset();
      
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

  void _onPanelDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStartHeight = _panelHeight;
    });
  }
  
  void _onPanelDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Invert delta because dragging up should increase height
      _panelHeight = (_dragStartHeight - details.localPosition.dy + details.globalPosition.dy - details.localPosition.dy)
          .clamp(_minPanelHeight, _maxPanelHeight)
          .toDouble();
    });
  }
  
  void _onPanelDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      // Snap to expanded or collapsed based on current position
      if (_panelHeight > (_maxPanelHeight + _minPanelHeight) / 2) {
        // Snap to expanded
        _panelHeight = _maxPanelHeight;
        _panelAnimationController.forward();
      } else {
        // Snap to collapsed
        _panelHeight = _minPanelHeight;
        _panelAnimationController.reverse();
        _clearElevationMarker();
      }
    });
  }
  
  void _onPanelVerticalDragUpdate(DragUpdateDetails details) {
    // Only allow dragging if route exists
    if (!_hasRoute) return;
    
    setState(() {
      _isDragging = true;
      // Update panel height based on drag
      _panelHeight = (_panelHeight - details.delta.dy)
          .clamp(_minPanelHeight, _maxPanelHeight)
          .toDouble();
      
      // Update animation controller value
      final progress = (_panelHeight - _minPanelHeight) / (_maxPanelHeight - _minPanelHeight);
      _panelAnimationController.value = progress;
      _fabAnimationController.value = progress;
    });
  }
  
  void _onPanelVerticalDragEnd(DragEndDetails details) {
    // Only allow dragging if route exists
    if (!_hasRoute) return;
    
    // Determine whether to expand or collapse based on velocity and position
    final velocity = details.primaryVelocity ?? 0;
    final shouldExpand = velocity < -300 || // Fast upward swipe (more responsive)
        (velocity.abs() < 300 && _panelHeight > (_maxPanelHeight + _minPanelHeight) / 2);
    
    setState(() {
      _isDragging = false;
      if (shouldExpand) {
        _panelHeight = _maxPanelHeight;
        _panelAnimationController.forward();
        _fabAnimationController.forward();
      } else {
        _panelHeight = _minPanelHeight;
        _panelAnimationController.reverse();
        _fabAnimationController.reverse();
        _clearElevationMarker();
      }
    });
  }
  
  bool get _isPanelExpanded => _panelHeight > (_maxPanelHeight + _minPanelHeight) / 2;
  
  // Find the position on the route based on distance
  LatLng? _getPositionAtDistance(double targetDistance) {
    if (_activeRoute.points.isEmpty || _distances.isEmpty) return null;
    
    // Find the segment containing this distance
    for (int i = 1; i < _distances.length; i++) {
      if (_distances[i] >= targetDistance) {
        // Interpolate between points[i-1] and points[i]
        final prevDist = i > 0 ? _distances[i-1] : 0.0;
        final nextDist = _distances[i];
        final ratio = (targetDistance - prevDist) / (nextDist - prevDist);
        
        if (i < _activeRoute.points.length) {
          final prevPoint = _activeRoute.points[i-1];
          final nextPoint = _activeRoute.points[i];
          
          final lat = prevPoint.latitude + (nextPoint.latitude - prevPoint.latitude) * ratio;
          final lng = prevPoint.longitude + (nextPoint.longitude - prevPoint.longitude) * ratio;
          
          return LatLng(lat, lng);
        }
      }
    }
    
    // If distance is beyond the route, return the last point
    return _activeRoute.points.isNotEmpty ? _activeRoute.points.last : null;
  }
  
  void _handleElevationGraphTouch(double distance) {
    final position = _getPositionAtDistance(distance);
    if (position != null) {
      // Immediate feedback with haptic
      HapticFeedback.selectionClick();
      setState(() {
        _elevationMarkerPosition = position;
        _elevationMarkerDistance = distance;
      });
    }
  }
  
  void _clearElevationMarker() {
    setState(() {
      _elevationMarkerPosition = null;
      _elevationMarkerDistance = null;
    });
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
              
              // Elevation marker (shows position when interacting with graph)
              if (_elevationMarkerPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 36.0,
                      height: 36.0,
                      point: _elevationMarkerPosition!,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 150),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.secondary.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.directions_walk,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              
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
          
          // Bottom panel - draggable only when route exists
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onVerticalDragUpdate: _hasRoute ? _onPanelVerticalDragUpdate : null,
              onVerticalDragEnd: _hasRoute ? _onPanelVerticalDragEnd : null,
              child: AnimatedContainer(
                duration: _isDragging ? Duration.zero : const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                height: _hasRoute ? _panelHeight : _minPanelHeight,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: _buildBottomPanel(theme),
              ),
            ),
          ),
          
          // Floating action buttons with smooth animation
          AnimatedPositioned(
            duration: _isDragging ? Duration.zero : const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            bottom: _panelHeight + 16,
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
          
          AnimatedPositioned(
            duration: _isDragging ? Duration.zero : const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            bottom: _panelHeight + 16,
            right: 16,
            child: Column(
              children: [
                // Undo button with scale animation
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 200),
                  tween: Tween(begin: 0.95, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: FloatingActionButton(
                        heroTag: 'undo',
                        mini: true,
                        onPressed: _canUndo ? () {
                          HapticFeedback.lightImpact();
                          _undoLastPoint();
                        } : null,
                        backgroundColor: _canUndo
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceVariant,
                        elevation: _canUndo ? 4 : 1,
                        child: Icon(
                          Icons.undo_rounded,
                          color: _canUndo
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Clear button with trash icon
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 200),
                  tween: Tween(begin: 0.95, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: FloatingActionButton(
                        heroTag: 'clear',
                        onPressed: _canClear ? () {
                          HapticFeedback.mediumImpact();
                          _clearCurrentDayRoute();
                        } : null,
                        backgroundColor: _canClear
                            ? theme.colorScheme.errorContainer
                            : theme.colorScheme.surfaceVariant,
                        elevation: _canClear ? 4 : 1,
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: _canClear
                              ? theme.colorScheme.onErrorContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
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
        // Handle bar - only show when route exists (draggable)
        if (_hasRoute)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isPanelExpanded ? 50 : 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withOpacity(_isPanelExpanded ? 0.7 : 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        
        // Stats row - always visible
        _buildStatsRow(theme),
        
        // Elevation graph - only when expanded and has route
        // Wrapped in GestureDetector to prevent panel drag when interacting with graph
        if (_isPanelExpanded && _hasRoute)
          Expanded(
            child: GestureDetector(
              // Block ONLY vertical drag events from propagating to panel
              // This allows horizontal scrolling on the graph to work
              onVerticalDragUpdate: (_) {}, // Consume vertical drag
              onVerticalDragEnd: (_) {}, // Consume vertical drag end
              onVerticalDragStart: (_) {}, // Consume vertical drag start
              // DO NOT block horizontal events - let them pass through to the graph
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: (_maxPanelHeight - 100).toDouble(), // Leave space for stats
                ),
                child: _buildElevationGraph(theme),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildStatsRow(ThemeData theme) {
    return Container(
      height: 80,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: _buildStatItem(
              icon: Icons.route,
              value: _formatDistance(_activeRoute.summary.distance),
              label: 'Distance',
              theme: theme,
              isLarge: true,
            ),
          ),
          Flexible(
            child: _buildStatItem(
              icon: Icons.schedule,
              value: _formatDuration(_activeRoute.summary.duration),
              label: 'Duration',
              theme: theme,
            ),
          ),
          Flexible(
            child: _buildStatItem(
              icon: Icons.trending_up,
              value: '${_activeRoute.summary.ascent.toStringAsFixed(0)}m',
              label: 'Ascent',
              theme: theme,
              color: Colors.green,
            ),
          ),
          Flexible(
            child: _buildStatItem(
              icon: Icons.trending_down,
              value: '${_activeRoute.summary.descent.toStringAsFixed(0)}m',
              label: 'Descent',
              theme: theme,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildElevationGraph(ThemeData theme) {
    // Generate elevation data
    final spots = _generateElevationData();
    
    if (spots.isEmpty || spots.length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.landscape_outlined,
              size: 36,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No elevation data yet',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Plan your route to see elevation profile',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }
    
    // Calculate min and max with padding
    double minY = spots.map((s) => s.y).reduce(math.min);
    double maxY = spots.map((s) => s.y).reduce(math.max);
    
    if ((maxY - minY) < 50) {
      final center = (maxY + minY) / 2;
      minY = center - 50;
      maxY = center + 50;
    }
    
    final range = maxY - minY;
    minY -= range * 0.1;
    maxY += range * 0.1;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Elevation Profile',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (_elevationMarkerDistance != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_formatDistance(_elevationMarkerDistance!)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Graph
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) > 0 ? (maxY - minY) / 4 : 25, // Default 25m intervals
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.dividerColor.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: (maxY - minY) > 0 ? (maxY - minY) / 4 : 25, // Default 25m intervals
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}m',
                          style: TextStyle(
                            fontSize: 9,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: _activeRoute.summary.distance > 0 
                          ? _activeRoute.summary.distance / 4 
                          : 250, // Default 250m intervals if no distance
                      getTitlesWidget: (value, meta) {
                        if (value == 0) {
                          return Text(
                            'Start',
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        } else if (_activeRoute.summary.distance > 0 && 
                                   value >= _activeRoute.summary.distance - 10) {
                          return Text(
                            'End',
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        } else {
                          return Text(
                            '${(value / 1000).toStringAsFixed(1)}km',
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(
                      color: theme.dividerColor.withOpacity(0.2),
                      width: 1,
                    ),
                    bottom: BorderSide(
                      color: theme.dividerColor.withOpacity(0.2),
                      width: 1,
                    ),
                    top: BorderSide.none,
                    right: BorderSide.none,
                  ),
                ),
                minX: 0,
                maxX: _activeRoute.summary.distance > 0 ? _activeRoute.summary.distance : 1000,
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    preventCurveOverShooting: true,
                    color: _activeRoute.routeColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          _activeRoute.routeColor.withOpacity(0.2),
                          _activeRoute.routeColor.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    // Immediate response for all touch events
                    if (event is FlTapDownEvent || event is FlPanStartEvent || 
                        event is FlTapUpEvent || event is FlPanUpdateEvent) {
                      if (touchResponse != null && 
                          touchResponse.lineBarSpots != null &&
                          touchResponse.lineBarSpots!.isNotEmpty) {
                        final spot = touchResponse.lineBarSpots!.first;
                        _handleElevationGraphTouch(spot.x);
                      }
                    } else if (event is FlPanEndEvent || event is FlTapCancelEvent || 
                               event is FlPanCancelEvent) {
                      _clearElevationMarker();
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => theme.colorScheme.surface,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    tooltipBorder: BorderSide(
                      color: theme.dividerColor.withOpacity(0.2),
                      width: 1,
                    ),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toInt()}m\n${(spot.x / 1000).toStringAsFixed(1)}km',
                          GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: theme.colorScheme.secondary,
                          strokeWidth: 2,
                          dashArray: [5, 5],
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 5,
                              color: theme.colorScheme.secondary,
                              strokeWidth: 2,
                              strokeColor: theme.colorScheme.surface,
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  List<FlSpot> _generateElevationData() {
    final points = <FlSpot>[];
    
    print('Generating elevation graph data:');
    print('  - Elevation points: ${_elevationProfile.length}');
    print('  - Distance points: ${_distances.length}');
    print('  - Route points: ${_activeRoute.points.length}');
    
    // Check if we have valid data
    if (_activeRoute.points.isEmpty || _elevationProfile.isEmpty || _distances.isEmpty) {
      print('  - Missing data, returning empty');
      return points;
    }
    
    // Ensure we have matching data lengths
    if (_elevationProfile.length != _distances.length) {
      print('  - Data length mismatch, returning empty');
      return points;
    }
    
    // Use the actual distance from our calculated data
    final totalDistance = _distances.isNotEmpty ? _distances.last : 0.0;
    
    if (totalDistance <= 0) {
      print('  - No distance calculated, returning empty');
      return points;
    }
    
    print('  - Using elevation data with total distance: $totalDistance');
    
    // Create points from our elevation and distance data
    // Start with first point at 0 distance
    points.add(FlSpot(0, _elevationProfile.first));
    
    // Sample points for performance (max 200 points for smooth curve)
    final dataLength = _elevationProfile.length;
    final step = dataLength > 200 ? dataLength ~/ 200 : 1;
    
    for (int i = step; i < dataLength; i += step) {
      if (i < _distances.length && i < _elevationProfile.length) {
        final dist = _distances[i];
        final elev = _elevationProfile[i];
        
        // Validate data
        if (!dist.isNaN && !elev.isNaN && dist.isFinite && elev.isFinite) {
          points.add(FlSpot(dist, elev));
        }
      }
    }
    
    // Always add the last point to ensure we reach the end
    if (_elevationProfile.isNotEmpty && _distances.isNotEmpty) {
      final lastPoint = FlSpot(_distances.last, _elevationProfile.last);
      // Only add if it's different from the last added point
      if (points.isEmpty || points.last.x != lastPoint.x) {
        points.add(lastPoint);
      }
    }
    
    print('  - Generated ${points.length} points for graph');
    
    // Ensure we have at least 2 points for a valid graph
    if (points.length < 2 && _elevationProfile.isNotEmpty) {
      // Add at least one more point if we only have one
      if (_elevationProfile.length > 1) {
        final midIndex = _elevationProfile.length ~/ 2;
        points.add(FlSpot(_distances[midIndex], _elevationProfile[midIndex]));
      }
      // Add the last point
      points.add(FlSpot(totalDistance, _elevationProfile.last));
    }
    
    return points;
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required ThemeData theme,
    bool isLarge = false,
    Color? color,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color ?? theme.colorScheme.primary,
            size: isLarge ? 22 : 18,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: isLarge ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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