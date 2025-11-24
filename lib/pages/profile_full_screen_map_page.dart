import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

import '../models/post_model.dart';
import '../models/hike_plan_model.dart';
import '../providers/route_planner_provider.dart';
import '../widgets/user_hikes_map_section.dart'; 
import '../widgets/post_card.dart';
import '../widgets/hike_plan_card.dart';

class ProfileFullScreenMapPage extends StatefulWidget {
  final String userId;
  final List<MapDisplayItem> initialItems;

  const ProfileFullScreenMapPage({
    super.key,
    required this.userId,
    required this.initialItems,
  });

  @override
  State<ProfileFullScreenMapPage> createState() =>
      _ProfileFullScreenMapPageState();
}

class CenterZoom {
  final LatLng center;
  final double zoom;

  CenterZoom({required this.center, required this.zoom});
}

class _ProfileFullScreenMapPageState extends State<ProfileFullScreenMapPage>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  
  // State
  MapDisplayItem? _selectedItem;
  List<LatLng> _activeRoutePoints = [];
  
  // Animations
  late AnimationController _routeDrawController;
  late Animation<double> _routeProgressAnimation;

  @override
  void initState() {
    super.initState();
    // Controller for the polyline drawing animation
    _routeDrawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _routeProgressAnimation = CurvedAnimation(
      parent: _routeDrawController,
      curve: Curves.easeInOutQuart,
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _routeDrawController.dispose();
    super.dispose();
  }

  List<LatLng> _getPointsFromItem(MapDisplayItem item) {
    if (item.type == MapItemType.post) {
      final post = item.data as Post;
      if (post.dailyRoutes != null && post.dailyRoutes!.isNotEmpty) {
        return post.dailyRoutes!.expand((r) => r.points).toList();
      }
    } else if (item.type == MapItemType.plannedHike || 
               item.type == MapItemType.completedHike) {
      final plan = item.data as HikePlan;
      if (plan.dailyRoutes.isNotEmpty) {
        return plan.dailyRoutes.expand((r) => r.points).toList();
      }
    }
    // Fallback: just the single location point if no route exists
    return [item.location]; 
  }

  void _onMarkerTap(MapDisplayItem item) {
    setState(() {
      _selectedItem = item;
      _activeRoutePoints = _getPointsFromItem(item);
    });

    // 1. Reset animations
    _routeDrawController.reset();

    // 2. Calculate target view
    LatLng targetCenter;
    double targetZoom;

    if (_activeRoutePoints.length > 1) {
      final bounds = LatLngBounds.fromPoints(_activeRoutePoints);
      final centerZoom = _centerZoomFitBounds(bounds);
      targetCenter = centerZoom.center;
      targetZoom = centerZoom.zoom;
    } else {
      targetCenter = item.location;
      targetZoom = 14.0; // Close up for single points
    }

    // 3. Animate Camera
    _animatedMapMove(targetCenter, targetZoom);

    // 4. Start Route Drawing (delayed slightly so camera starts first)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _selectedItem == item) {
        _routeDrawController.forward();
      }
    });
  }

  // Helper to calculate zoom level for bounds
  CenterZoom _centerZoomFitBounds(LatLngBounds bounds) {
    // This is a simplified approximation. 
    // Real implementation requires map dimensions which might not be available 
    // perfectly without LayoutBuilder, but this is "close enough" for the effect.
    return CenterZoom(
      center: bounds.center,
      zoom: _mapController.camera.zoom < 10 ? 12 : _mapController.camera.zoom, 
    );
  }
  
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the degrees of lat/lng.
    final latTween = Tween<double>(
        begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(
        begin: _mapController.camera.zoom, end: destZoom);

    final controller = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
    
    final Animation<double> animation = CurvedAnimation(
        parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _deselect() {
    setState(() {
      _selectedItem = null;
      _activeRoutePoints = [];
    });
    _routeDrawController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Create markers
    final markers = widget.initialItems.map((item) {
      final isSelected = _selectedItem?.id == item.id;
      return Marker(
        width: isSelected ? 50 : 40, // Grow when selected
        height: isSelected ? 50 : 40,
        point: item.location,
        child: GestureDetector(
          onTap: () => _onMarkerTap(item),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: isSelected ? 1.2 : 1.0,
            child: MapMarker(
              item: item,
              isSelected: isSelected,
              onTap: () {}, // Handled by parent GestureDetector for animation
            ),
          ),
        ),
      );
    }).toList();

    final allPoints = widget.initialItems.map((item) => item.location).toList();
    final bounds = LatLngBounds.fromPoints(allPoints);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.8),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(50.0),
              ),
              maxZoom: 18,
              onTap: (_, __) => _deselect(),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.treknoteflutter',
              ),
              
              // 1. The "Ghost" Route (Faint background line for context)
              if (_selectedItem != null && _activeRoutePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _activeRoutePoints,
                      strokeWidth: 4.0,
                      color: Colors.black.withOpacity(0.1),
                    ),
                  ],
                ),

              // 2. The Animated Route (Drawing on top)
              if (_selectedItem != null && _activeRoutePoints.length > 1)
                AnimatedBuilder(
                  animation: _routeProgressAnimation,
                  builder: (context, child) {
                    // Calculate how many points to show based on animation value
                    final count = (_activeRoutePoints.length * _routeProgressAnimation.value).ceil();
                    final visiblePoints = _activeRoutePoints.take(count).toList();
                    
                    if (visiblePoints.isEmpty) return const SizedBox.shrink();

                    return PolylineLayer(
                      polylines: [
                        Polyline(
                          points: visiblePoints,
                          strokeWidth: 5.0,
                          color: theme.colorScheme.secondary, // Orange/Accent color
                          borderColor: Colors.white,
                          borderStrokeWidth: 2.0,
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                      ],
                    );
                  },
                ),

              // 3. Markers
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 80,
                  size: const Size(40, 40),
                  markers: markers,
                  polygonOptions: const PolygonOptions(
                      borderColor: Colors.blueAccent,
                      color: Colors.black12,
                      borderStrokeWidth: 3),
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary,
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          _buildSelectedItemCard(context),
        ],
      ),
    );
  }

  Widget _buildSelectedItemCard(BuildContext context) {
    final bool isSelected = _selectedItem != null;
    
    // Delay showing the card until route has started drawing
    // We can use the same controller status or just link it to selection state 
    // with a slightly longer duration/delay in the AnimatedPositioned.
    
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut, // Nice bounce effect
      bottom: isSelected ? MediaQuery.of(context).padding.bottom + 24 : -400,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: isSelected ? 1.0 : 0.0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _buildCardContent(context),
            if (isSelected)
              Positioned(
                top: -12,
                right: -12,
                child: GestureDetector(
                  onTap: _deselect,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                         BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                         )
                      ]
                    ),
                    child: const Icon(Icons.close, size: 20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    if (_selectedItem == null) return const SizedBox.shrink();

    switch (_selectedItem!.type) {
      case MapItemType.post:
        return PostCard(
          post: _selectedItem!.data as Post,
          onTap: () => context.push('/post/${_selectedItem!.id}'),
        );
      case MapItemType.plannedHike:
      case MapItemType.completedHike:
        return HikePlanCard(
          plan: _selectedItem!.data as HikePlan,
          onTap: () {
            final plan = _selectedItem!.data as HikePlan;
            if (_selectedItem!.type == MapItemType.plannedHike) {
              context.push('/hike-plan-hub', extra: plan);
            } else {
              context.read<RoutePlannerProvider>().loadPlan(plan);
              context.push('/route-planner');
            }
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
