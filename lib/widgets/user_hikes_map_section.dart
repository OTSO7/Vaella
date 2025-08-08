import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../models/post_model.dart';
import '../models/hike_plan_model.dart';
import '../models/user_profile_model.dart' as user_model;
import '../providers/route_planner_provider.dart';
import 'post_card.dart';
import 'hike_plan_card.dart';

// --- 1. Yhtenäinen datamalli kartan kohteille ---

enum MapItemType { post, plannedHike, completedHike }

abstract class MapDisplayItem {
  String get id;
  String get title;
  LatLng get location;
  MapItemType get type;
  Object get data; // Alkuperäinen Post tai HikePlan olio
}

class PostMapItem implements MapDisplayItem {
  @override
  final Post data;
  PostMapItem(this.data);

  @override
  String get id => data.id;
  @override
  String get title => data.title;
  @override
  LatLng get location => LatLng(data.latitude!, data.longitude!);
  @override
  MapItemType get type => MapItemType.post;
}

class PlannedHikeMapItem implements MapDisplayItem {
  @override
  final HikePlan data;
  PlannedHikeMapItem(this.data);

  @override
  String get id => data.id;
  @override
  String get title => data.hikeName;
  @override
  LatLng get location => LatLng(data.latitude!, data.longitude!);
  @override
  MapItemType get type => MapItemType.plannedHike;
}

class CompletedHikeMapItem implements MapDisplayItem {
  @override
  final HikePlan data;
  CompletedHikeMapItem(this.data);

  @override
  String get id => data.id;
  @override
  String get title => data.hikeName;
  @override
  LatLng get location => LatLng(data.latitude!, data.longitude!);
  @override
  MapItemType get type => MapItemType.completedHike;
}

// --- 2. Pääwidgetti ---

class UserPostsMapSection extends StatefulWidget {
  final String userId;
  final user_model.UserProfile userProfile;
  const UserPostsMapSection(
      {super.key, required this.userId, required this.userProfile});

  @override
  State<UserPostsMapSection> createState() => _UserPostsMapSectionState();
}

class _UserPostsMapSectionState extends State<UserPostsMapSection>
    with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  MapDisplayItem? _selectedItem;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // --- 3. Datan haku ja yhdistäminen ---

  Stream<List<MapDisplayItem>> _getCombinedMapDataStream() {
    final postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: widget.userId)
        .where('visibility', isEqualTo: 'public')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Post.fromFirestore(doc))
            .where((post) => post.latitude != null && post.longitude != null)
            .map((post) => PostMapItem(post))
            .toList());

    final plansStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('plans')
        .snapshots()
        .map((snapshot) {
      final plans = snapshot.docs
          .map((doc) => HikePlan.fromFirestore(doc))
          .where((plan) => plan.latitude != null && plan.longitude != null);

      final List<MapDisplayItem> planItems = [];
      for (var plan in plans) {
        if (plan.status == HikeStatus.planned ||
            plan.status == HikeStatus.upcoming ||
            plan.status == HikeStatus.ongoing) {
          planItems.add(PlannedHikeMapItem(plan));
        } else if (plan.status == HikeStatus.completed) {
          planItems.add(CompletedHikeMapItem(plan));
        }
      }
      return planItems;
    });

    return Rx.combineLatest2(postsStream, plansStream,
        (List<MapDisplayItem> posts, List<MapDisplayItem> plans) {
      final allItems = <MapDisplayItem>[];
      final planIdsInPosts =
          posts.map((item) => (item.data as Post).planId).toSet();

      allItems.addAll(posts);

      allItems.addAll(plans.where((item) {
        if (item.type == MapItemType.completedHike) {
          return !planIdsInPosts.contains(item.id);
        }
        return true;
      }));

      return allItems;
    });
  }

  void _onMarkerTap(MapDisplayItem item) {
    setState(() {
      _selectedItem = item;
    });
    _mapController.move(item.location, _mapController.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<MapDisplayItem>>(
      stream: _getCombinedMapDataStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error loading map data: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(Theme.of(context));
        }

        final allItems = snapshot.data!;
        return _buildMapView(context, allItems);
      },
    );
  }

  // --- 4. UI-komponentit ---

  Widget _buildMapView(BuildContext context, List<MapDisplayItem> items) {
    final markers = items.map((item) {
      return Marker(
        width: 40,
        height: 40,
        point: item.location,
        child: MapMarker(
          item: item,
          isSelected: _selectedItem?.id == item.id,
          onTap: () => _onMarkerTap(item),
        ),
      );
    }).toList();

    final allPoints = items.map((item) => item.location).toList();
    final bounds = allPoints.isNotEmpty
        ? LatLngBounds.fromPoints(allPoints)
        : LatLngBounds(const LatLng(65.0, 25.0), const LatLng(64.0, 26.0));

    // KORJAUS: Lasketaan tilastot suoraan kartalla näkyvistä kohteista.
    final double totalDistance = items.fold(0.0, (sum, item) {
      if (item is PostMapItem) return sum + item.data.distanceKm;
      if (item is CompletedHikeMapItem) {
        return sum + (item.data.lengthKm ?? 0.0);
      }
      return sum;
    });

    final int totalNights = items.fold(0, (sum, item) {
      if (item is PostMapItem) return sum + item.data.nights;
      if (item is CompletedHikeMapItem) {
        final plan = item.data;
        if (plan.endDate != null) {
          // Varmistetaan, ettei erotus ole negatiivinen
          final nights = plan.endDate!.difference(plan.startDate).inDays;
          return sum + (nights > 0 ? nights : 0);
        }
      }
      return sum;
    });

    // Lasketaan toteutuneet vaellukset (Postaukset + Suoritetut suunnitelmat ilman postausta)
    final int totalHikes = items
        .where((item) =>
            item.type == MapItemType.post ||
            item.type == MapItemType.completedHike)
        .length;

    final calculatedStats = user_model.HikeStats(
      totalDistance: totalDistance,
      totalHikes: totalHikes,
      totalNights: totalNights,
      highestAltitude: widget.userProfile.hikeStats.highestAltitude,
    );

    return Stack(
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
                      color: Theme.of(context).colorScheme.primary,
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
        _MapOverlay(
          userProfile: widget.userProfile.copyWith(hikeStats: calculatedStats),
          onFullScreenTap: () {
            context.push('/profile/map',
                extra: {'userId': widget.userId, 'items': items});
          },
        ),
        _buildSelectedItemCard(context),
      ],
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
            if (isVisible)
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 60, color: theme.hintColor),
            const SizedBox(height: 16),
            Text(
              'Nothing to Show on Map',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Your posts and hike plans with a location will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 5. Yksittäinen kartan markkeri (JAETTU) ---
class MapMarker extends StatelessWidget {
  final MapDisplayItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const MapMarker({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color;
    final IconData icon;

    switch (item.type) {
      case MapItemType.post:
        color = Colors.green.shade600; // Suoritettu ja postattu
        icon = Icons.check_circle_rounded;
        break;
      case MapItemType.plannedHike:
        color = Colors.amber.shade700; // Suunnitteilla
        icon = Icons.watch_later_rounded;
        break;
      case MapItemType.completedHike:
        color = Colors.red.shade600; // Suoritettu, ei postattu
        icon = Icons.task_alt_rounded;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: isSelected ? 1.3 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: theme.scaffoldBackgroundColor
                  .withOpacity(isSelected ? 1.0 : 0.8),
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// --- 6. KARTAN PÄÄLLÄ OLEVA UI ---
class _MapOverlay extends StatelessWidget {
  final user_model.UserProfile userProfile;
  final VoidCallback onFullScreenTap;

  const _MapOverlay({required this.userProfile, required this.onFullScreenTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = userProfile.hikeStats;

    return Positioned.fill(
      child: IgnorePointer(
        // Ignore all pointers except for the fullscreen button
        ignoring: true,
        child: Stack(
          children: [
            // Top Left Stats
            Positioned(
              top: 16,
              left: 16,
              child: _StatBox(
                theme: theme,
                children: [
                  _StatRow(
                      icon: Icons.hiking,
                      value:
                          '${stats.totalDistance.toStringAsFixed(1)} km hiked'),
                  _StatRow(
                      icon: Icons.nights_stay_outlined,
                      value:
                          '${NumberFormat.compact().format(stats.totalNights)} nights'),
                  _StatRow(
                      icon: Icons.filter_hdr,
                      value:
                          '${NumberFormat.compact().format(stats.totalHikes)} hikes'),
                ],
              ),
            ),
            // Top Right Fullscreen Button
            Positioned(
              top: 16,
              right: 16,
              child: Material(
                color: theme.scaffoldBackgroundColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onFullScreenTap,
                  child: const IgnorePointer(
                    // Make sure this specific widget is tappable
                    ignoring: false,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.fullscreen, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final ThemeData theme;
  final List<Widget> children;
  const _StatBox({required this.theme, required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String value;
  const _StatRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.lato(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              shadows: [
                const Shadow(color: Colors.black54, blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
