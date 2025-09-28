import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class UltraSmooth3DRoute extends StatefulWidget {
  final List<LatLng> routePoints;
  final Color routeColor;
  final double animationSpeed;
  final double cameraHeight;
  final double cameraAngle;
  final bool isPlaying;
  final bool showTerrain;
  final VoidCallback? onPlaybackComplete;

  const UltraSmooth3DRoute({
    super.key,
    required this.routePoints,
    required this.routeColor,
    this.animationSpeed = 1.0,
    this.cameraHeight = 500.0,
    this.cameraAngle = 45.0,
    this.isPlaying = false,
    this.showTerrain = true,
    this.onPlaybackComplete,
  });

  @override
  State<UltraSmooth3DRoute> createState() => _UltraSmooth3DRouteState();
}

class _UltraSmooth3DRouteState extends State<UltraSmooth3DRoute>
    with SingleTickerProviderStateMixin {
  
  // Animation
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _progress = 0.0;
  
  // Map control
  MapController? _mapController;
  
  // Route data
  final List<double> _distances = [];
  double _totalDistance = 0;
  LatLng _currentPosition = const LatLng(0, 0);
  double _currentBearing = 0;
  double _targetBearing = 0;
  
  // Smooth values
  double _smoothLat = 0;
  double _smoothLng = 0;
  double _smoothBearing = 0;
  double _smoothZoom = 17; // Start with higher zoom for lower view
  
  @override
  void initState() {
    super.initState();
    _initializeRoute();
    _ticker = createTicker(_onTick);
    
    // Delay map controller initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _mapController = MapController();
        });
      }
    });
  }

  void _initializeRoute() {
    if (widget.routePoints.isEmpty) return;
    
    _currentPosition = widget.routePoints.first;
    _smoothLat = _currentPosition.latitude;
    _smoothLng = _currentPosition.longitude;
    
    // Calculate distances between consecutive points
    _distances.clear();
    _totalDistance = 0;
    
    if (widget.routePoints.length > 1) {
      const distance = Distance();
      for (int i = 1; i < widget.routePoints.length; i++) {
        final d = distance.as(
          LengthUnit.Meter,
          widget.routePoints[i - 1],
          widget.routePoints[i],
        );
        _distances.add(d);
        _totalDistance += d;
      }
    }
  }

  void _onTick(Duration elapsed) {
    if (!widget.isPlaying || widget.routePoints.length < 2) return;
    
    // Calculate delta time in seconds
    final deltaTime = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    
    // Much slower progress - complete route in 180 seconds (3 minutes) at speed 1.0
    _progress += (deltaTime * widget.animationSpeed) / 180.0;
    
    if (_progress >= 1.0) {
      _progress = 1.0;
      _ticker.stop();
      widget.onPlaybackComplete?.call();
    }
    
    // Calculate position along route
    _updatePosition();
    
    // Update map smoothly
    _updateMap();
    
    // Trigger rebuild for UI updates
    if (mounted) {
      setState(() {});
    }
  }

  void _updatePosition() {
    if (widget.routePoints.length < 2 || _distances.isEmpty) return;
    
    // Find position based on total distance traveled
    final targetDistance = _progress * _totalDistance;
    double accumulatedDistance = 0;
    
    // Find which segment we're in
    for (int i = 0; i < _distances.length; i++) {
      final segmentDistance = _distances[i];
      
      if (accumulatedDistance + segmentDistance >= targetDistance) {
        // We're in segment i (between point i and point i+1)
        final distanceIntoSegment = targetDistance - accumulatedDistance;
        final segmentProgress = segmentDistance > 0 
            ? distanceIntoSegment / segmentDistance 
            : 0.0;
        
        // Get the two points of this segment
        final start = widget.routePoints[i];
        final end = widget.routePoints[i + 1];
        
        // Linear interpolation between the two points
        final lat = start.latitude + (end.latitude - start.latitude) * segmentProgress;
        final lng = start.longitude + (end.longitude - start.longitude) * segmentProgress;
        
        _currentPosition = LatLng(lat, lng);
        
        // Calculate bearing for this segment
        _targetBearing = _calculateBearing(start, end);
        
        return; // Exit once we've found our position
      }
      
      accumulatedDistance += segmentDistance;
    }
    
    // If we've somehow gone past the end, set to last point
    if (accumulatedDistance < targetDistance && widget.routePoints.isNotEmpty) {
      _currentPosition = widget.routePoints.last;
    }
  }

  void _updateMap() {
    if (_mapController == null) return;
    
    // Much slower smoothing for smoother movement
    const positionSmoothing = 0.08; // Lower = smoother but slower response
    const bearingSmoothing = 0.05;  // Very smooth rotation
    const zoomSmoothing = 0.05;
    
    // Smooth position
    _smoothLat += (_currentPosition.latitude - _smoothLat) * positionSmoothing;
    _smoothLng += (_currentPosition.longitude - _smoothLng) * positionSmoothing;
    
    // Smooth bearing (handle wrap-around)
    double bearingDiff = _targetBearing - _smoothBearing;
    if (bearingDiff > 180) bearingDiff -= 360;
    if (bearingDiff < -180) bearingDiff += 360;
    _smoothBearing += bearingDiff * bearingSmoothing;
    
    // Normalize bearing to [0, 360]
    while (_smoothBearing < 0) _smoothBearing += 360;
    while (_smoothBearing >= 360) _smoothBearing -= 360;
    
    // Calculate zoom for low camera view (higher zoom = closer to ground)
    // Lower camera height = higher zoom level for closer view
    final targetZoom = 18.5 - math.log(widget.cameraHeight / 500) / math.ln2;
    _smoothZoom += (targetZoom - _smoothZoom) * zoomSmoothing;
    
    // Apply to map
    try {
      _mapController!.move(LatLng(_smoothLat, _smoothLng), _smoothZoom);
      _mapController!.rotate(_smoothBearing);
    } catch (e) {
      // Ignore errors during animation
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final dLon = (end.longitude - start.longitude) * math.pi / 180;
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  @override
  void didUpdateWidget(UltraSmooth3DRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.routePoints != oldWidget.routePoints) {
      _initializeRoute();
    }
    
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _lastElapsed = Duration.zero;
      if (_progress >= 1.0) {
        _progress = 0;
        _initializeRoute();
      }
      _ticker.start();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.routePoints.isEmpty) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Text(
            'No route available',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }

    // Build map only after controller is ready
    if (_mapController == null) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white54,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen map with 3D perspective tilt
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateX(-widget.cameraAngle * math.pi / 180), // Tilt for 3D view
          child: _buildMap(),
        ),
        
        // 3D effect overlay
        if (widget.showTerrain) _build3DOverlay(),
        
        // Progress indicator
        _buildProgressIndicator(),
      ],
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.routePoints.first,
        initialZoom: 17, // Start zoomed in for low view
        minZoom: 14,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        // Use ESRI satellite imagery instead of OSM to avoid policy issues
        TileLayer(
          urlTemplate: widget.showTerrain
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
          maxZoom: 19,
          userAgentPackageName: 'com.treknote.app', // Proper app identification
          tileProvider: NetworkTileProvider(), // Use network tile provider
        ),
        
        // Hillshade for 3D terrain effect
        if (widget.showTerrain)
          Opacity(
            opacity: 0.6, // Stronger hillshade for better terrain visibility
            child: TileLayer(
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Elevation/World_Hillshade/MapServer/tile/{z}/{y}/{x}',
              maxZoom: 19,
              userAgentPackageName: 'com.treknote.app',
              tileProvider: NetworkTileProvider(),
            ),
          ),
        
        // Route polylines
        PolylineLayer(
          polylines: [
            // Shadow for depth (offset more for low angle view)
            if (widget.showTerrain)
              Polyline(
                points: widget.routePoints.map((p) => 
                  LatLng(p.latitude - 0.00015, p.longitude + 0.00015)
                ).toList(),
                strokeWidth: 8,
                color: Colors.black.withOpacity(0.4),
              ),
            // Main route (semi-transparent)
            Polyline(
              points: widget.routePoints,
              strokeWidth: 5,
              color: widget.routeColor.withOpacity(0.3),
              borderStrokeWidth: 1,
              borderColor: Colors.white.withOpacity(0.3),
            ),
            // Completed portion (solid)
            if (_progress > 0)
              Polyline(
                points: _getCompletedPoints(),
                strokeWidth: 6,
                color: widget.routeColor,
                borderStrokeWidth: 2,
                borderColor: Colors.white.withOpacity(0.9),
              ),
          ],
        ),
        
        // Markers
        MarkerLayer(
          markers: [
            // Start marker
            Marker(
              point: widget.routePoints.first,
              width: 36,
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
              ),
            ),
            // End marker
            Marker(
              point: widget.routePoints.last,
              width: 36,
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.flag, color: Colors.white, size: 18),
              ),
            ),
            // Current position marker (following the route exactly)
            Marker(
              point: LatLng(_smoothLat, _smoothLng),
              width: 28,
              height: 28,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.6),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: _smoothBearing * math.pi / 180,
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _build3DOverlay() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.lightBlue.withOpacity(0.15), // Sky
              Colors.transparent,
              Colors.transparent,
              Colors.brown.withOpacity(0.2), // Ground fog
            ],
            stops: const [0.0, 0.2, 0.8, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 4,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(widget.routeColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distance: ${(_progress * _totalDistance / 1000).toStringAsFixed(2)} km',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Total: ${(_totalDistance / 1000).toStringAsFixed(2)} km',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<LatLng> _getCompletedPoints() {
    if (_progress <= 0) return [];
    if (_progress >= 1) return widget.routePoints;
    
    final targetDistance = _progress * _totalDistance;
    double accumulatedDistance = 0;
    List<LatLng> points = [];
    
    for (int i = 0; i < widget.routePoints.length - 1; i++) {
      points.add(widget.routePoints[i]);
      
      if (i < _distances.length) {
        if (accumulatedDistance + _distances[i] >= targetDistance) {
          // Add the interpolated current position
          points.add(_currentPosition);
          break;
        }
        accumulatedDistance += _distances[i];
      }
    }
    
    return points;
  }
}