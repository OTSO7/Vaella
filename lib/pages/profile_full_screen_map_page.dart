import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/post_model.dart';
import '../models/hike_plan_model.dart';
import '../providers/route_planner_provider.dart';
import '../widgets/user_hikes_map_section.dart'; // Tuodaan MapDisplayItem, MapItemType, jne.
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

class _ProfileFullScreenMapPageState extends State<ProfileFullScreenMapPage> {
  final MapController _mapController = MapController();
  MapDisplayItem? _selectedItem;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onMarkerTap(MapDisplayItem item) {
    setState(() {
      _selectedItem = item;
    });
    _mapController.move(item.location, _mapController.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markers = widget.initialItems.map((item) {
      return Marker(
        width: 40,
        height: 40,
        point: item.location,
        child: MapMarker(
          // Käytetään jaettua MapMarker-widgettiä
          item: item,
          isSelected: _selectedItem?.id == item.id,
          onTap: () => _onMarkerTap(item),
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
              onTap: (_, __) => setState(() => _selectedItem = null),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.treknoteflutter',
              ),
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
    final bool isVisible = _selectedItem != null;
    Widget cardContent;

    if (!isVisible) {
      cardContent = const SizedBox.shrink();
    } else {
      switch (_selectedItem!.type) {
        case MapItemType.post:
          cardContent = PostCard(
            post: _selectedItem!.data as Post,
            onTap: () => context.push('/post/${_selectedItem!.id}'),
          );
          break;
        case MapItemType.plannedHike:
        case MapItemType.completedHike:
          cardContent = HikePlanCard(
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
          break;
      }
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      bottom: isVisible ? MediaQuery.of(context).padding.bottom + 12 : -300,
      left: 12,
      right: 12,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: isVisible ? 1.0 : 0.0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            cardContent,
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () => setState(() => _selectedItem = null),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).cardColor,
                  child: const Icon(Icons.close, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
