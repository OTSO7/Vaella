// lib/pages/group_hike_hub_page.dart
import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/hike_plan_model.dart';
import '../models/daily_route_model.dart';
import '../models/user_profile_model.dart' as user_model;
import '../providers/auth_provider.dart';
import '../providers/route_planner_provider.dart';
import '../services/hike_plan_service.dart';
import '../utils/app_colors.dart';

class GroupHikeHubPage extends StatefulWidget {
  final HikePlan initialPlan;

  const GroupHikeHubPage({super.key, required this.initialPlan});

  @override
  State<GroupHikeHubPage> createState() => _GroupHikeHubPageState();
}

class _GroupHikeHubPageState extends State<GroupHikeHubPage>
    with TickerProviderStateMixin {
  late HikePlan _plan;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<String> _participantIds = [];

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _updateParticipantIds();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updateParticipantIds() {
    final me = context.read<AuthProvider>().userProfile;
    _participantIds = <String>{
      if (_plan.collabOwnerId != null && _plan.collabOwnerId!.isNotEmpty)
        _plan.collabOwnerId!,
      ..._plan.collaboratorIds,
      if (me != null && me.uid.isNotEmpty) me.uid,
    }.toList();
  }

  Future<void> _refreshPlanData() async {
    try {
      final service = HikePlanService();
      final stream = service.getHikePlanStream(_plan.id);
      final updatedPlan = await stream.first;
      if (updatedPlan != null && mounted) {
        setState(() {
          _plan = updatedPlan;
          _updateParticipantIds();
        });
      }
    } catch (e) {
      // Silent fail - keep existing plan data
    }
  }

  Future<void> _openWeather() async {
    if (_plan.latitude != null && _plan.longitude != null) {
      GoRouter.of(context).pushNamed('weatherPage',
          pathParameters: {'planId': _plan.id}, extra: _plan);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Weather forecast requires location coordinates.'),
          backgroundColor: AppColors.errorColor(context),
        ),
      );
    }
  }

  Future<void> _openPlanner() async {
    context.read<RoutePlannerProvider>().loadPlan(_plan);
    await context.push('/route-planner');
    if (!mounted) return;
    setState(() => _plan = context.read<RoutePlannerProvider>().plan);
  }

  Future<void> _openUserPackingList(String userId) async {
    // Navigate to specific user's packing list view
    final result = await GoRouter.of(context).pushNamed('packingListPage',
        pathParameters: {'planId': _plan.id}, extra: _plan);
    if (mounted && result is HikePlan) {
      setState(() {
        _plan = result;
      });
    } else {
      _refreshPlanData();
    }
  }

  Future<void> _openAddPlanModal() async {
    // Add plan functionality - can be implemented if needed
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add plan feature coming soon')),
    );
  }

  Future<void> _openInviteSheet() async {
    // Show invite sheet for adding more participants
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite feature coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRoute = _plan.dailyRoutes.any((r) => r.points.isNotEmpty);
    final hasLocation = _plan.latitude != null && _plan.longitude != null;
    final dayCount = _plan.endDate != null
        ? _plan.endDate!.difference(_plan.startDate).inDays + 1
        : 1;
    final dateRange = dayCount > 1
        ? '${DateFormat('MMM d').format(_plan.startDate)} - ${DateFormat('MMM d, yyyy').format(_plan.endDate!)}'
        : DateFormat('MMM d, yyyy').format(_plan.startDate);
    final distanceText = _plan.lengthKm != null && _plan.lengthKm! > 0
        ? '${_plan.lengthKm!.toStringAsFixed(1)} km'
        : '—';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: cs.surface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // Modern header with background
            SliverAppBar(
              pinned: true,
              stretch: true,
              elevation: 0,
              expandedHeight: 460,
              backgroundColor: cs.surface,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                    tooltip: 'Add plan',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => _openAddPlanModal()),
                IconButton(
                    tooltip: 'Invite',
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    onPressed: () => _openInviteSheet()),
                const SizedBox(width: 6),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground
                ],
                background: _HeaderBackground(
                  hasRoute: hasRoute,
                  hasLocation: hasLocation,
                  planCenter: hasLocation
                      ? LatLng(_plan.latitude!, _plan.longitude!)
                      : null,
                  imageUrl: _plan.imageUrl,
                  dailyRoutes: _plan.dailyRoutes,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(120),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _GlassHeaderInfo(
                    title: _plan.hikeName,
                    location: _plan.location,
                    dateRange: dateRange,
                    distanceText: distanceText,
                    days: dayCount,
                  ),
                ),
              ),
            ),

            // Modern grid-based layout with group focus
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverToBoxAdapter(
                child: _ModernGroupLayout(
                  plan: _plan,
                  hasRoute: hasRoute,
                  hasLocation: hasLocation,
                  planCenter: hasLocation
                      ? LatLng(_plan.latitude!, _plan.longitude!)
                      : null,
                  participantIds: _participantIds,
                  onOpenWeather: _openWeather,
                  onOpenPlanner: _openPlanner,
                  onOpenUserPackingList: _openUserPackingList,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= HELPER WIDGETS =================
class _GroupPreparationGrid extends StatelessWidget {
  final List<String> participantIds;
  final HikePlan plan;
  final List<QueryDocumentSnapshot> users;

  const _GroupPreparationGrid({
    required this.participantIds,
    required this.plan,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: users.map((userDoc) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final userName = userData['displayName'] ?? 'Hiker';
          final photoUrl = userData['photoURL'] as String?;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userDoc.id)
                .collection('plans')
                .doc(plan.id)
                .snapshots(),
            builder: (context, planSnapshot) {
              final planData =
                  planSnapshot.data?.data() as Map<String, dynamic>?;
              final preparationItems =
                  planData?['preparationItems'] as Map<String, dynamic>? ?? {};
              final completedItems =
                  preparationItems.values.where((v) => v == true).length;
              final progress = completedItems / 4; // 4 total preparation items

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          photoUrl != null ? NetworkImage(photoUrl) : null,
                      backgroundColor: cs.primaryContainer,
                      child: photoUrl == null
                          ? Icon(Icons.person_rounded,
                              color: cs.onPrimaryContainer, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName.split(' ').first,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: cs.surfaceContainerHighest,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(cs.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(progress * 100).round()}%',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: cs.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= MODERN COMPONENTS =================

class _ModernGroupLayout extends StatelessWidget {
  final HikePlan plan;
  final bool hasRoute;
  final bool hasLocation;
  final LatLng? planCenter;
  final List<String> participantIds;
  final VoidCallback onOpenWeather;
  final VoidCallback onOpenPlanner;
  final Function(String) onOpenUserPackingList;

  const _ModernGroupLayout({
    required this.plan,
    required this.hasRoute,
    required this.hasLocation,
    required this.planCenter,
    required this.participantIds,
    required this.onOpenWeather,
    required this.onOpenPlanner,
    required this.onOpenUserPackingList,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group collaboration hub - prominent position for group plans
        _ModernGroupHubCard(
          plan: plan,
          participantIds: participantIds,
        ),
        const SizedBox(height: 20),

        // Primary featured card - Weather (full width)
        _ModernWeatherCard(
          plan: plan,
          onOpen: onOpenWeather,
        ),

        const SizedBox(height: 20),

        // Two-column grid for main actions
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _ModernPackingCard(
                  plan: plan,
                  onOpen: () => onOpenUserPackingList(participantIds.first),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _ModernFoodCard(
                  plan: plan,
                  onOpen: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Food planning coming soon'))),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Route planning card - enhanced for group collaboration
        _ModernRouteCard(
          plan: plan,
          hasRoute: hasRoute,
          hasLocation: hasLocation,
          planCenter: planCenter,
          onOpen: onOpenPlanner,
        ),

        const SizedBox(height: 20),

        // Individual participant progress cards
        _buildParticipantProgressSection(context),
      ],
    );
  }

  Widget _buildParticipantProgressSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team Progress',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ...participantIds.map((participantId) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModernParticipantCard(
                participantId: participantId,
                plan: plan,
                onTap: () => onOpenUserPackingList(participantId),
              ),
            )),
      ],
    );
  }
}

class _HeaderBackground extends StatelessWidget {
  final bool hasRoute;
  final bool hasLocation;
  final LatLng? planCenter;
  final String? imageUrl;
  final List<DailyRoute> dailyRoutes;

  const _HeaderBackground({
    required this.hasRoute,
    required this.hasLocation,
    required this.planCenter,
    required this.imageUrl,
    required this.dailyRoutes,
  });

  @override
  Widget build(BuildContext context) {
    Widget bg;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      bg = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultBackground(),
      );
    } else if (hasRoute && dailyRoutes.isNotEmpty) {
      final allPoints = dailyRoutes.expand((r) => r.points).toList();
      if (allPoints.isNotEmpty) {
        bg = FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(allPoints),
              padding: const EdgeInsets.all(48),
            ),
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.treknoteflutter',
            ),
            PolylineLayer(
              polylines: dailyRoutes
                  .map((route) => Polyline(
                        points: route.points,
                        strokeWidth: 4,
                        color: route.routeColor,
                      ))
                  .toList(),
            ),
          ],
        );
      } else {
        bg = _buildDefaultBackground();
      }
    } else if (hasLocation && planCenter != null) {
      bg = FlutterMap(
        options: MapOptions(
          initialCenter: planCenter!,
          initialZoom: 11,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.treknoteflutter',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: planCenter!,
                width: 40,
                height: 40,
                child: Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      bg = _buildDefaultBackground();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        bg,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.6, 1],
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.45),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6B73FF), Color(0xFF9DDCFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 120,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }
}

class _GlassHeaderInfo extends StatelessWidget {
  final String title;
  final String location;
  final String dateRange;
  final String distanceText;
  final int days;

  const _GlassHeaderInfo({
    required this.title,
    required this.location,
    required this.dateRange,
    required this.distanceText,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (location.isNotEmpty) ...[
                    Icon(Icons.place_outlined, size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 3,
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(Icons.calendar_month_outlined,
                      size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: Text(
                      dateRange,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$days days',
                    style: GoogleFonts.lato(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernGroupHubCard extends StatelessWidget {
  final HikePlan plan;
  final List<String> participantIds;

  const _ModernGroupHubCard({
    required this.plan,
    required this.participantIds,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withOpacity(0.8),
            cs.primaryContainer.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with group info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.groups_2_rounded,
                  color: cs.onPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Group Adventure',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${participantIds.length} adventurers planning together',
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        color: cs.onPrimaryContainer.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Participant avatars
          _buildParticipantRow(context, cs),
        ],
      ),
    );
  }

  Widget _buildParticipantRow(BuildContext context, ColorScheme cs) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId,
              whereIn: participantIds.take(10).toList())
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingAvatars(cs);
        }

        final users = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'uid': doc.id,
            'name': data['displayName'] ?? 'Hiker',
            'photo': data['photoURL'],
          };
        }).toList();

        return Row(
          children: [
            // Avatar stack with overlapping
            SizedBox(
              height: 44,
              width: (users.length * 32.0) + 12,
              child: Stack(
                children: users.asMap().entries.map((entry) {
                  final index = entry.key;
                  final user = entry.value;
                  return Positioned(
                    left: index * 32.0,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage: user['photo'] != null
                            ? NetworkImage(user['photo'])
                            : null,
                        backgroundColor: cs.primaryContainer,
                        child: user['photo'] == null
                            ? Icon(
                                Icons.person_rounded,
                                color: cs.onPrimaryContainer,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const Spacer(),

            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Active',
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingAvatars(ColorScheme cs) {
    return Row(
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.only(left: index > 0 ? -8 : 0),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.surfaceContainerHighest,
            border: Border.all(color: cs.surface, width: 3),
          ),
        );
      }),
    );
  }
}

class _ModernWeatherCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback onOpen;

  const _ModernWeatherCard({
    required this.plan,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surfaceContainer,
            cs.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.2),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.cloud_rounded,
                    color: Colors.blue,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Weather Forecast',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.latitude != null
                            ? 'Check conditions for your hike'
                            : 'Add location for weather info',
                        style: GoogleFonts.lato(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: cs.onSurfaceVariant,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernPackingCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback onOpen;

  const _ModernPackingCard({
    required this.plan,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final packedCount = plan.packingList.where((i) => i.isPacked).length;
    final totalCount = plan.packingList.length;
    final progress = totalCount > 0 ? packedCount / totalCount : 0.0;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surfaceContainer,
            cs.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.2),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.backpack_rounded,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Packing List',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalCount > 0
                                ? '$packedCount of $totalCount packed'
                                : 'Start packing!',
                            style: GoogleFonts.lato(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: cs.onSurfaceVariant,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (totalCount > 0) ...[
                  Text(
                    '${(progress * 100).round()}% Complete',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor:
                          cs.surfaceContainerHighest.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      minHeight: 8,
                    ),
                  ),
                ] else
                  Text(
                    'Start building your personal packing list',
                    style: GoogleFonts.lato(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernFoodCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback onOpen;

  const _ModernFoodCard({
    required this.plan,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foodData = _calculateFoodTotals();
    final progress = foodData['progress'];

    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surfaceContainer,
            cs.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.2),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: Colors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Food Planning',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            foodData['days'] > 0
                                ? '${foodData['days']} days planned'
                                : 'Plan your meals',
                            style: GoogleFonts.lato(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: cs.onSurfaceVariant,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (foodData['days'] > 0) ...[
                  Text(
                    '${(progress * 100).round()}% Planned',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor:
                          cs.surfaceContainerHighest.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      minHeight: 8,
                    ),
                  ),
                ] else
                  Text(
                    'Plan your personal meals and snacks',
                    style: GoogleFonts.lato(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateFoodTotals() {
    if (plan.foodPlanJson == null || plan.foodPlanJson!.isEmpty) {
      return {'calories': 0, 'items': 0, 'days': 0, 'progress': 0.0};
    }

    try {
      final List<dynamic> decoded = json.decode(plan.foodPlanJson!);
      int plannedDays = 0;
      final totalDays = plan.endDate != null
          ? plan.endDate!.difference(plan.startDate).inDays + 1
          : 1;

      for (final dayData in decoded) {
        final sections = dayData['sections'] as List<dynamic>? ?? [];
        bool dayHasItems = false;

        for (final sectionData in sections) {
          final items = sectionData['items'] as List<dynamic>? ?? [];
          if (items.isNotEmpty) {
            dayHasItems = true;
            break;
          }
        }

        if (dayHasItems) plannedDays++;
      }

      return {
        'days': plannedDays,
        'progress': totalDays > 0 ? plannedDays / totalDays : 0.0,
      };
    } catch (e) {
      return {'days': 0, 'progress': 0.0};
    }
  }
}

class _ModernRouteCard extends StatelessWidget {
  final HikePlan plan;
  final bool hasRoute;
  final bool hasLocation;
  final LatLng? planCenter;
  final VoidCallback onOpen;

  const _ModernRouteCard({
    required this.plan,
    required this.hasRoute,
    required this.hasLocation,
    required this.planCenter,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalDistance = plan.dailyRoutes.fold<double>(
        0.0, (sum, route) => sum + (route.summary.distance / 1000));

    return Container(
      height: hasRoute ? 180 : 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surfaceContainer,
            cs.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.2),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.route_rounded,
                        color: Colors.purple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Route Planning',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasRoute
                                ? '${totalDistance.toStringAsFixed(1)} km planned'
                                : 'Plan your route',
                            style: GoogleFonts.lato(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: cs.onSurfaceVariant,
                      size: 16,
                    ),
                  ],
                ),
                if (hasRoute) ...[
                  const SizedBox(height: 16),
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.map_rounded,
                        size: 32,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernParticipantCard extends StatelessWidget {
  final String participantId;
  final HikePlan plan;
  final VoidCallback onTap;

  const _ModernParticipantCard({
    required this.participantId,
    required this.plan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId = context.read<AuthProvider>().userProfile?.uid;
    final isCurrentUser = participantId == currentUserId;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(participantId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return _buildLoadingCard(cs);
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final userProfile = userData != null
            ? user_model.UserProfile.fromFirestore(userSnapshot.data!)
            : null;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(participantId)
              .collection('plans')
              .doc(plan.id)
              .snapshots(),
          builder: (context, planSnapshot) {
            if (!planSnapshot.hasData) {
              return _buildLoadingCard(cs);
            }

            final planData = planSnapshot.data?.data() as Map<String, dynamic>?;
            final preparationItems =
                planData?['preparationItems'] as Map<String, dynamic>? ?? {};
            final completedItems =
                preparationItems.values.where((v) => v == true).length;
            final progress = completedItems / 4;

            final packingList =
                (planData?['packingList'] as List<dynamic>? ?? []);
            final packedItems =
                packingList.where((item) => item['isPacked'] == true).length;
            final packingProgress =
                packingList.isNotEmpty ? packedItems / packingList.length : 0.0;

            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.surfaceContainer,
                        cs.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrentUser
                          ? cs.primary.withOpacity(0.3)
                          : cs.outline.withOpacity(0.1),
                      width: isCurrentUser ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // User avatar and info
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: userProfile?.photoURL != null
                            ? NetworkImage(userProfile!.photoURL!)
                            : null,
                        backgroundColor: cs.primaryContainer,
                        child: userProfile?.photoURL == null
                            ? Icon(
                                Icons.person_rounded,
                                color: cs.onPrimaryContainer,
                                size: 20,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    userProfile?.displayName ?? 'Hiker',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: cs.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'You',
                                      style: GoogleFonts.lato(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(((progress + packingProgress) / 2) * 100).round()}% ready',
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingCard(ColorScheme cs) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withOpacity(0.1),
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.primary,
          ),
        ),
      ),
    );
  }
}
