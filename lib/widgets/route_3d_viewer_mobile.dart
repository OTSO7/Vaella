import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class Route3DViewer extends StatefulWidget {
  final List<LatLng> routePoints;
  final Color routeColor;
  final double animationSpeed;
  final double cameraHeight;
  final double cameraAngle;
  final bool isPlaying;
  final bool showTerrain;
  final bool showLabels;
  final VoidCallback? onPlaybackComplete;

  const Route3DViewer({
    super.key,
    required this.routePoints,
    required this.routeColor,
    this.animationSpeed = 1.0,
    this.cameraHeight = 500.0,
    this.cameraAngle = 45.0,
    this.isPlaying = false,
    this.showTerrain = true,
    this.showLabels = true,
    this.onPlaybackComplete,
  });

  @override
  State<Route3DViewer> createState() => _Route3DViewerState();
}

class _Route3DViewerState extends State<Route3DViewer>
    with SingleTickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _animationController;
  int _currentPointIndex = 0;
  double _currentZoom = 15.0;
  double _currentRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Calculate smoother animation duration based on route length
    final animationDuration = widget.routePoints.length * 100; // milliseconds per point
    
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (animationDuration / widget.animationSpeed).round(),
      ),
    );

    _animationController.addListener(_onAnimationUpdate);
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onPlaybackComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(Route3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _startAnimation();
      } else {
        _pauseAnimation();
      }
    }

    if (widget.animationSpeed != oldWidget.animationSpeed) {
      final animationDuration = widget.routePoints.length * 100;
      _animationController.duration = Duration(
        milliseconds: (animationDuration / widget.animationSpeed).round(),
      );
    }

    if (widget.cameraHeight != oldWidget.cameraHeight) {
      _currentZoom = _calculateZoomFromHeight(widget.cameraHeight);
    }
  }

  double _calculateZoomFromHeight(double height) {
    // Convert camera height to map zoom level
    return 18 - (math.log(height / 100) / math.ln2);
  }

  void _onAnimationUpdate() {
    if (!mounted || widget.routePoints.isEmpty) return;

    final progress = _animationController.value;
    final totalPoints = widget.routePoints.length - 1;
    final exactIndex = progress * totalPoints;
    final currentIndex = exactIndex.floor();
    final nextIndex = (currentIndex + 1).clamp(0, totalPoints);
    final t = exactIndex - currentIndex;

    // Only update state if index changed to avoid excessive rebuilds
    if (currentIndex != _currentPointIndex) {
      // Use post frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentPointIndex = currentIndex;
          });
        }
      });
    }

    // Interpolate between points for smooth movement
    final currentPoint = widget.routePoints[currentIndex];
    final nextPoint = widget.routePoints[nextIndex];
    
    final lat = currentPoint.latitude + (nextPoint.latitude - currentPoint.latitude) * t;
    final lng = currentPoint.longitude + (nextPoint.longitude - currentPoint.longitude) * t;

    // Calculate bearing for rotation
    if (currentIndex < totalPoints) {
      _currentRotation = _calculateBearing(currentPoint, nextPoint);
    }

    // Move map to interpolated position smoothly
    if (_mapController.mapEventStream != null) {
      _mapController.move(LatLng(lat, lng), _currentZoom);
      _mapController.rotate(_currentRotation);
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final dLon = (end.longitude - start.longitude) * math.pi / 180;
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    return math.atan2(y, x) * 180 / math.pi;
  }

  void _startAnimation() {
    if (_animationController.isCompleted) {
      _animationController.reset();
    }
    _animationController.forward();
  }

  void _pauseAnimation() {
    _animationController.stop();
  }

  @override
  void dispose() {
    _animationController.removeListener(_onAnimationUpdate);
    _animationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.routePoints.isEmpty) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.terrain,
                size: 64,
                color: Colors.white30,
              ),
              SizedBox(height: 16),
              Text(
                'No route data available',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Plan a route first to see the 3D fly-over',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // 3D-style tilted map with enhanced perspective
        ClipRect(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002) // increased perspective for better 3D effect
              ..rotateX(-widget.cameraAngle * math.pi / 180) // tilt angle
              ..scale(1.0, 1.3), // stretch vertically for depth illusion
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.routePoints.first,
                initialZoom: _currentZoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none, // Disable user interaction during animation
                ),
              ),
              children: [
                // Terrain/Satellite tiles for better 3D effect
                TileLayer(
                  urlTemplate: widget.showTerrain
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.treknoteflutter',
                  maxZoom: 19,
                  errorTileCallback: (tile, error, stackTrace) {
                    // Handle tile loading errors silently
                  },
                ),
                
                // Hillshade overlay for terrain effect using ESRI (working URL)
                if (widget.showTerrain)
                  Opacity(
                    opacity: 0.5,
                    child: TileLayer(
                      urlTemplate: 'https://services.arcgisonline.com/ArcGIS/rest/services/Elevation/World_Hillshade/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'com.example.treknoteflutter',
                    ),
                  ),
                
                // Add shadow effect for elevation illusion
                if (widget.showTerrain)
                  PolylineLayer(
                    polylines: [
                      // Shadow polyline
                      Polyline(
                        points: widget.routePoints.map((point) => 
                          LatLng(point.latitude - 0.0002, point.longitude + 0.0002)
                        ).toList(),
                        strokeWidth: 10.0,
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ],
                  ),
                
                // Route polyline with elevation effect
                PolylineLayer(
                  polylines: [
                    // Main route
                    Polyline(
                      points: widget.routePoints,
                      strokeWidth: 6.0,
                      color: widget.routeColor,
                      borderStrokeWidth: 2.0,
                      borderColor: Colors.white.withOpacity(0.5),
                    ),
                    // Highlight current segment with glow effect
                    if (_currentPointIndex > 0)
                      Polyline(
                        points: widget.routePoints.sublist(0, _currentPointIndex + 1),
                        strokeWidth: 8.0,
                        color: widget.routeColor.withOpacity(0.9),
                        borderStrokeWidth: 3.0,
                        borderColor: Colors.white.withOpacity(0.8),
                      ),
                  ],
                ),
                
                // Markers
                MarkerLayer(
                  markers: [
                    // Start marker
                    Marker(
                      point: widget.routePoints.first,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    // End marker
                    Marker(
                      point: widget.routePoints.last,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.flag,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    // Current position marker
                    if (_currentPointIndex < widget.routePoints.length)
                      Marker(
                        point: widget.routePoints[_currentPointIndex],
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                
                // Labels
                if (widget.showLabels)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.routePoints.first,
                        width: 60,
                        height: 40,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'START',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                      Marker(
                        point: widget.routePoints.last,
                        width: 60,
                        height: 40,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'FINISH',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        
        // Add gradient overlay for depth effect
        if (widget.showTerrain)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.15),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
        
        // Progress indicator
        Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _animationController.value,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.routeColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Point ${_currentPointIndex + 1} of ${widget.routePoints.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}