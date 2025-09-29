import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:async';

class SmoothRouteAnimator extends StatefulWidget {
  final List<LatLng> routePoints;
  final Color routeColor;
  final double animationSpeed;
  final double cameraHeight;
  final double cameraAngle;
  final bool isPlaying;
  final bool showTerrain;
  final VoidCallback? onPlaybackComplete;

  const SmoothRouteAnimator({
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
  State<SmoothRouteAnimator> createState() => _SmoothRouteAnimatorState();
}

class _SmoothRouteAnimatorState extends State<SmoothRouteAnimator>
    with SingleTickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _animationController;

  LatLng _currentPosition = const LatLng(0, 0);
  final double _currentBearing = 0;
  double _smoothedBearing = 0;
  int _currentSegmentIndex = 0;
  Timer? _animationTimer;
  double _animationProgress = 0.0;

  // Pre-calculated route data
  final List<double> _segmentDistances = [];
  double _totalDistance = 0;
  final List<double> _cumulativeDistances = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.routePoints.isNotEmpty) {
      _currentPosition = widget.routePoints.first;
      _precalculateRouteData();
    }

    // Much longer duration for smoother animation (60 seconds base)
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: (60 / widget.animationSpeed).round()),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _stopAnimation();
        widget.onPlaybackComplete?.call();
      }
    });
  }

  void _precalculateRouteData() {
    if (widget.routePoints.length < 2) return;

    _segmentDistances.clear();
    _cumulativeDistances.clear();
    _totalDistance = 0;
    _cumulativeDistances.add(0);

    const Distance calculator = Distance();

    for (int i = 1; i < widget.routePoints.length; i++) {
      final distance = calculator.as(
        LengthUnit.Meter,
        widget.routePoints[i - 1],
        widget.routePoints[i],
      );
      _segmentDistances.add(distance);
      _totalDistance += distance;
      _cumulativeDistances.add(_totalDistance);
    }
  }

  void _startAnimation() {
    if (_animationController.isCompleted) {
      _animationController.reset();
      _animationProgress = 0.0;
      _currentSegmentIndex = 0;
    }

    _animationController.forward();

    // Use timer for smooth updates (60 FPS)
    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _updateAnimation();
    });
  }

  void _stopAnimation() {
    _animationController.stop();
    _animationTimer?.cancel();
  }

  void _updateAnimation() {
    if (!mounted || widget.routePoints.length < 2) return;

    // Get current animation progress
    _animationProgress = _animationController.value;

    // Calculate position along entire route
    final targetDistance = _animationProgress * _totalDistance;

    // Find current segment
    int segmentIndex = 0;
    for (int i = 1; i < _cumulativeDistances.length; i++) {
      if (targetDistance <= _cumulativeDistances[i]) {
        segmentIndex = i - 1;
        break;
      }
    }

    if (segmentIndex >= widget.routePoints.length - 1) {
      segmentIndex = widget.routePoints.length - 2;
    }

    // Calculate position within segment
    final segmentStartDistance = _cumulativeDistances[segmentIndex];
    final segmentEndDistance = _cumulativeDistances[segmentIndex + 1];
    final segmentLength = segmentEndDistance - segmentStartDistance;
    final distanceInSegment = targetDistance - segmentStartDistance;
    final segmentProgress =
        segmentLength > 0 ? distanceInSegment / segmentLength : 0;

    // Interpolate position
    final start = widget.routePoints[segmentIndex];
    final end = widget.routePoints[segmentIndex + 1];

    final lat =
        start.latitude + (end.latitude - start.latitude) * segmentProgress;
    final lng =
        start.longitude + (end.longitude - start.longitude) * segmentProgress;

    _currentPosition = LatLng(lat, lng);

    // Calculate bearing with smoothing
    final targetBearing = _calculateBearing(start, end);

    // Smooth bearing changes to avoid jerky rotation
    double bearingDiff = targetBearing - _smoothedBearing;

    // Normalize bearing difference to [-180, 180]
    while (bearingDiff > 180) {
      bearingDiff -= 360;
    }
    while (bearingDiff < -180) {
      bearingDiff += 360;
    }

    // Apply smoothing (10% of difference per frame)
    _smoothedBearing += bearingDiff * 0.1;

    // Normalize smoothed bearing to [0, 360]
    while (_smoothedBearing < 0) {
      _smoothedBearing += 360;
    }
    while (_smoothedBearing >= 360) {
      _smoothedBearing -= 360;
    }

    // Update map position
    final zoom = 16.5 - (math.log(widget.cameraHeight / 200) / math.ln2);

    try {
      _mapController.move(_currentPosition, zoom);
      _mapController.rotate(_smoothedBearing);
    } catch (e) {
      // Ignore controller errors during animation
    }

    // Update UI only when segment changes
    if (segmentIndex != _currentSegmentIndex) {
      _currentSegmentIndex = segmentIndex;
      if (mounted) {
        setState(() {});
      }
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
  void didUpdateWidget(SmoothRouteAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.routePoints != oldWidget.routePoints) {
      _precalculateRouteData();
    }

    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }

    if (widget.animationSpeed != oldWidget.animationSpeed) {
      _animationController.duration = Duration(
        seconds: (60 / widget.animationSpeed).round(),
      );
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _animationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.routePoints.isEmpty) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Text(
            'No route available',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final zoom = 16.5 - (math.log(widget.cameraHeight / 200) / math.ln2);

    return Stack(
      children: [
        // Enhanced 3D map with perspective
        ClipRect(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.lightBlue.shade100.withOpacity(0.3),
                  Colors.transparent,
                  Colors.brown.shade900.withOpacity(0.2),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015) // Perspective
                ..rotateX(-widget.cameraAngle * math.pi / 180) // Tilt
                ..scale(1.0, 1.2, 1.0), // Vertical stretch for depth
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.routePoints.first,
                  initialZoom: zoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  // Base terrain/satellite layer
                  TileLayer(
                    urlTemplate: widget.showTerrain
                        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                    maxZoom: 20,
                    tileProvider: NetworkTileProvider(),
                  ),

                  // Hillshade overlay for 3D effect
                  if (widget.showTerrain)
                    Opacity(
                      opacity: 0.6,
                      child: TileLayer(
                        urlTemplate:
                            'https://server.arcgisonline.com/ArcGIS/rest/services/Elevation/World_Hillshade/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.example.app',
                        maxZoom: 20,
                        tileProvider: NetworkTileProvider(),
                      ),
                    ),

                  // Shadow polyline for depth
                  if (widget.showTerrain)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: widget.routePoints
                              .map((p) => LatLng(
                                  p.latitude - 0.0003, p.longitude + 0.0003))
                              .toList(),
                          strokeWidth: 8.0,
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ],
                    ),

                  // Route polylines
                  PolylineLayer(
                    polylines: [
                      // Full route (faded)
                      Polyline(
                        points: widget.routePoints,
                        strokeWidth: 4.0,
                        color: widget.routeColor.withOpacity(0.3),
                        borderStrokeWidth: 1.0,
                        borderColor: Colors.white.withOpacity(0.2),
                      ),
                      // Completed portion
                      if (_currentSegmentIndex > 0)
                        Polyline(
                          points: widget.routePoints
                              .sublist(0, _currentSegmentIndex + 1),
                          strokeWidth: 6.0,
                          color: widget.routeColor,
                          borderStrokeWidth: 2.0,
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
                        width: 36,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 18),
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
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.flag,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      // Current position marker (animated)
                      Marker(
                        point: _currentPosition,
                        width: 24,
                        height: 24,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 500),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 1.0 + (value * 0.2),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.6),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.navigation,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3D terrain effect overlay
        if (widget.showTerrain)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Progress bar
        Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _animationProgress,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.routeColor),
                  minHeight: 3,
                ),
                const SizedBox(height: 4),
                Text(
                  'Distance: ${(_animationProgress * _totalDistance / 1000).toStringAsFixed(1)} km / ${(_totalDistance / 1000).toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
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
