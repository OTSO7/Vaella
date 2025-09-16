// lib/pages/group_hike_hub_page.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/hike_plan_model.dart';
import '../models/user_profile_model.dart' as user_model;
import '../providers/auth_provider.dart';
import '../providers/route_planner_provider.dart';
import '../services/hike_plan_service.dart';
import '../utils/app_colors.dart';
import '../utils/map_helpers.dart';

class GroupHikeHubPage extends StatefulWidget {
  final HikePlan initialPlan;

  const GroupHikeHubPage({super.key, required this.initialPlan});

  @override
  State<GroupHikeHubPage> createState() => _GroupHikeHubPageState();
}

class _GroupHikeHubPageState extends State<GroupHikeHubPage>
    with TickerProviderStateMixin {
  late HikePlan _plan;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _currentPage = 0;
  List<String> _participantIds = [];

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    _pageController = PageController();
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
    _pageController.dispose();
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

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: cs.surface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Custom app bar with page indicators
            _buildCustomAppBar(cs),

            // Swipeable pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  // Overview page (leftmost)
                  _GroupOverviewPage(
                    plan: _plan,
                    participantIds: _participantIds,
                    onOpenWeather: _openWeather,
                    onOpenPlanner: _openPlanner,
                  ),

                  // Individual participant pages
                  ..._participantIds.map(
                    (participantId) => _ParticipantPage(
                      participantId: participantId,
                      plan: _plan,
                      onOpenPackingList: () =>
                          _openUserPackingList(participantId),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(ColorScheme cs) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.surface,
            cs.surface.withOpacity(0.95),
            cs.surface.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              // Top row with back button and title
              Row(
                children: [
                  Material(
                    color: cs.surfaceContainerHighest.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: cs.onSurface,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _plan.hikeName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Group Planning',
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Page indicators
              _buildPageIndicators(cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicators(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Overview indicator
        _buildIndicatorDot(
          cs,
          isActive: _currentPage == 0,
          isOverview: true,
        ),

        const SizedBox(width: 8),

        // Participant indicators
        ...List.generate(_participantIds.length, (index) {
          final participantIndex = index + 1;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _buildIndicatorDot(
              cs,
              isActive: _currentPage == participantIndex,
              participantId: _participantIds[index],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildIndicatorDot(
    ColorScheme cs, {
    required bool isActive,
    bool isOverview = false,
    String? participantId,
  }) {
    if (isOverview) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isActive ? 32 : 24,
        height: isActive ? 32 : 24,
        decoration: BoxDecoration(
          color: isActive ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? cs.primary : cs.outline.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Icon(
          Icons.explore_rounded,
          color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
          size: isActive ? 18 : 14,
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(participantId!)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final photoUrl = userData?['photoURL'] as String?;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isActive ? 36 : 28,
          height: isActive ? 36 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? cs.primary : cs.outline.withOpacity(0.3),
              width: isActive ? 3 : 2,
            ),
          ),
          child: CircleAvatar(
            radius: isActive ? 15 : 11,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            backgroundColor: cs.primaryContainer,
            child: photoUrl == null
                ? Icon(
                    Icons.person_rounded,
                    color: cs.onPrimaryContainer,
                    size: isActive ? 18 : 14,
                  )
                : null,
          ),
        );
      },
    );
  }
}

// ================= GROUP OVERVIEW PAGE =================
class _GroupOverviewPage extends StatelessWidget {
  final HikePlan plan;
  final List<String> participantIds;
  final VoidCallback onOpenWeather;
  final VoidCallback onOpenPlanner;

  const _GroupOverviewPage({
    required this.plan,
    required this.participantIds,
    required this.onOpenWeather,
    required this.onOpenPlanner,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRoute = plan.dailyRoutes.any((r) => r.points.isNotEmpty);
    final hasLocation = plan.latitude != null && plan.longitude != null;
    final planCenter =
        hasLocation ? LatLng(plan.latitude!, plan.longitude!) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hike overview card with beautiful visual
          _buildHikeOverviewCard(
              context, cs, hasRoute, hasLocation, planCenter),

          const SizedBox(height: 24),

          // Group preparation overview
          _buildGroupPreparationOverview(context, cs),

          const SizedBox(height: 24),

          // Quick action cards
          _buildQuickActions(context, cs),
        ],
      ),
    );
  }

  Widget _buildHikeOverviewCard(
    BuildContext context,
    ColorScheme cs,
    bool hasRoute,
    bool hasLocation,
    LatLng? planCenter,
  ) {
    final dateRange = _dateRangeString(plan.startDate, plan.endDate);
    final days = _dayCount(plan.startDate, plan.endDate);
    final distanceText = plan.lengthKm != null && plan.lengthKm! > 0
        ? '${plan.lengthKm!.toStringAsFixed(1)} km'
        : '—';

    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background image/map
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: _buildBackgroundContent(hasRoute, hasLocation, planCenter),
            ),
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.hikeName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.location,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(dateRange, Icons.calendar_today_rounded),
                    const SizedBox(width: 8),
                    _buildInfoChip('$days days', Icons.schedule_rounded),
                    const SizedBox(width: 8),
                    _buildInfoChip(distanceText, Icons.straighten_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundContent(
      bool hasRoute, bool hasLocation, LatLng? planCenter) {
    if (hasRoute) {
      final allPoints = plan.dailyRoutes.expand((r) => r.points).toList();
      final bounds =
          allPoints.isNotEmpty ? LatLngBounds.fromPoints(allPoints) : null;
      final arrows = generateArrowMarkersForDays(plan.dailyRoutes);

      return FlutterMap(
        options: MapOptions(
          initialCameraFit: bounds != null
              ? CameraFit.bounds(
                  bounds: bounds, padding: const EdgeInsets.all(48))
              : const CameraFit.coordinates(
                  coordinates: [LatLng(65, 25)], minZoom: 5),
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
          ),
          PolylineLayer(
            polylines: plan.dailyRoutes
                .map((route) => Polyline(
                      points: route.points,
                      strokeWidth: 4,
                      color: route.routeColor,
                    ))
                .toList(),
          ),
          if (arrows.isNotEmpty) MarkerLayer(markers: arrows),
        ],
      );
    } else if (hasLocation && planCenter != null) {
      return FlutterMap(
        options: MapOptions(
          initialCenter: planCenter,
          initialZoom: 11,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: planCenter,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6B73FF),
              const Color(0xFF9DDCFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.landscape_rounded,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
      );
    }
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupPreparationOverview(BuildContext context, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Group Preparation',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId,
                  whereIn: participantIds.take(10).toList())
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _buildLoadingIndicator(cs);
            }

            return _GroupPreparationGrid(
              participantIds: participantIds,
              plan: plan,
              users: snapshot.data!.docs,
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.cloud_rounded,
                title: 'Weather',
                subtitle: 'Check forecast',
                color: Colors.blue,
                onTap: onOpenWeather,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.route_rounded,
                title: 'Route',
                subtitle: 'Plan path',
                color: Colors.green,
                onTap: onOpenPlanner,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator(ColorScheme cs) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  String _dateRangeString(DateTime start, DateTime? end) {
    if (end == null || DateUtils.isSameDay(start, end)) {
      return DateFormat('d.M.yyyy').format(start);
    }
    final sameYear = start.year == end.year;
    final sameMonth = sameYear && start.month == end.month;
    if (sameMonth) {
      return '${DateFormat('d').format(start)}–${DateFormat('d.M.yyyy').format(end)}';
    } else if (sameYear) {
      return '${DateFormat('d.M').format(start)}–${DateFormat('d.M.yyyy').format(end)}';
    }
    return '${DateFormat('d.M.yyyy').format(start)}–${DateFormat('d.M.yyyy').format(end)}';
  }

  int _dayCount(DateTime start, DateTime? end) {
    final e = end ?? start;
    final s = DateTime(start.year, start.month, start.day);
    final ee = DateTime(e.year, e.month, e.day);
    return ee.difference(s).inDays + 1;
  }
}

// ================= PARTICIPANT PAGE =================
class _ParticipantPage extends StatelessWidget {
  final String participantId;
  final HikePlan plan;
  final VoidCallback onOpenPackingList;

  const _ParticipantPage({
    required this.participantId,
    required this.plan,
    required this.onOpenPackingList,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(participantId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return _buildLoadingState(cs);
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
              return _buildLoadingState(cs);
            }

            final planData = planSnapshot.data?.data() as Map<String, dynamic>?;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User profile header
                  _buildUserHeader(context, cs, userProfile),

                  const SizedBox(height: 24),

                  // Preparation progress
                  _buildPreparationProgress(context, cs, planData),

                  const SizedBox(height: 24),

                  // Packing details
                  _buildPackingDetails(context, cs, planData),

                  const SizedBox(height: 24),

                  // Food planning details
                  _buildFoodDetails(context, cs, planData),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserHeader(BuildContext context, ColorScheme cs,
      user_model.UserProfile? userProfile) {
    final isCurrentUser =
        context.read<AuthProvider>().userProfile?.uid == participantId;

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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with level badge
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrentUser
                        ? cs.primary
                        : cs.outline.withOpacity(0.3),
                    width: isCurrentUser ? 4 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundImage: userProfile?.photoURL != null
                      ? NetworkImage(userProfile!.photoURL!)
                      : null,
                  backgroundColor: cs.surface,
                  child: userProfile?.photoURL == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: cs.onSurface.withOpacity(0.6),
                        )
                      : null,
                ),
              ),

              // Level badge
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                  child: Text(
                    'L${userProfile?.level ?? 1}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 20),

          // User info
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
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'You',
                          style: GoogleFonts.lato(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (userProfile?.username != null)
                  Text(
                    '@${userProfile!.username}',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 8),

                // Experience info
                Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${userProfile?.experience ?? 0} XP',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreparationProgress(
      BuildContext context, ColorScheme cs, Map<String, dynamic>? planData) {
    final preparationItems =
        planData?['preparationItems'] as Map<String, dynamic>? ?? {};
    final completedItems =
        preparationItems.values.where((v) => v == true).length;
    final totalItems = 4; // weather, day planner, food planner, packing list
    final progress = totalItems > 0 ? completedItems / totalItems : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                color: cs.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Preparation Progress',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: cs.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),

          const SizedBox(height: 16),

          // Individual items
          ...['weather', 'day_planner', 'food_planner', 'packing_list']
              .map((key) {
            final isCompleted = preparationItems[key] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color:
                          isCompleted ? cs.primary : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: isCompleted
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: cs.onPrimary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getPreparationItemName(key),
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: isCompleted ? cs.onSurface : cs.onSurfaceVariant,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPackingDetails(
      BuildContext context, ColorScheme cs, Map<String, dynamic>? planData) {
    final packingList = (planData?['packingList'] as List<dynamic>? ?? []);

    final packedItems =
        packingList.where((item) => item['isPacked'] == true).length;
    final totalItems = packingList.length;
    final progress = totalItems > 0 ? packedItems / totalItems : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
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
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        totalItems > 0
                            ? '$packedItems of $totalItems packed'
                            : 'No items yet',
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onOpenPackingList,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          if (totalItems > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest.withOpacity(0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            ),
          // Items preview (top 5)
          if (packingList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: packingList.take(5).map((item) {
                  final itemData = item as Map<String, dynamic>;
                  final isPacked = itemData['isPacked'] == true;
                  final itemName =
                      itemData['name'] as String? ?? 'Unknown item';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isPacked
                                ? Colors.orange
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: isPacked
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 12,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            itemName,
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              color:
                                  isPacked ? cs.onSurfaceVariant : cs.onSurface,
                              decoration:
                                  isPacked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            if (packingList.length > 5)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text(
                  '+${packingList.length - 5} more items',
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                'No packing items added yet',
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFoodDetails(
      BuildContext context, ColorScheme cs, Map<String, dynamic>? planData) {
    final foodPlanJson = planData?['foodPlanJson'] as String?;
    final foodData = _calculateFoodProgress(foodPlanJson, planData);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      foodData['plannedDays'] > 0
                          ? '${foodData['plannedDays']} days planned'
                          : 'No food plan yet',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (foodData['plannedDays'] > 0) ...[
            const SizedBox(height: 16),

            // Food stats
            Row(
              children: [
                _buildFoodStat(
                  cs,
                  '${foodData['totalCalories'].toInt()}',
                  'Calories',
                  Icons.local_fire_department_rounded,
                  Colors.red,
                ),
                const SizedBox(width: 16),
                _buildFoodStat(
                  cs,
                  '${foodData['totalItems'].toInt()}',
                  'Items',
                  Icons.inventory_2_rounded,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFoodStat(
      ColorScheme cs, String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: cs.onSurface,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: CircularProgressIndicator(
          color: cs.primary,
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateFoodProgress(
      String? foodPlanJson, Map<String, dynamic>? planData) {
    if (foodPlanJson == null || foodPlanJson.isEmpty) {
      return {'plannedDays': 0, 'totalCalories': 0.0, 'totalItems': 0};
    }

    try {
      final List<dynamic> decoded = json.decode(foodPlanJson);
      double totalCalories = 0;
      int totalItems = 0;
      int plannedDays = 0;

      for (final dayData in decoded) {
        final sections = dayData['sections'] as List<dynamic>? ?? [];
        bool dayHasItems = false;

        for (final sectionData in sections) {
          final items = sectionData['items'] as List<dynamic>? ?? [];
          if (items.isNotEmpty) {
            dayHasItems = true;
            totalItems += items.length;
            for (final item in items) {
              totalCalories += (item['calories'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }

        if (dayHasItems) plannedDays++;
      }

      return {
        'plannedDays': plannedDays,
        'totalCalories': totalCalories,
        'totalItems': totalItems,
      };
    } catch (e) {
      return {'plannedDays': 0, 'totalCalories': 0.0, 'totalItems': 0};
    }
  }

  String _getPreparationItemName(String key) {
    switch (key) {
      case 'weather':
        return 'Weather checked';
      case 'day_planner':
        return 'Day plan done';
      case 'food_planner':
        return 'Food plan ready';
      case 'packing_list':
        return 'Packing list created';
      default:
        return key;
    }
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
