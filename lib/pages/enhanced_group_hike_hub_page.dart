// lib/pages/enhanced_group_hike_hub_page.dart
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../models/hike_plan_model.dart';
import '../models/user_profile_model.dart' as user_model;
import '../providers/auth_provider.dart';
import '../providers/route_planner_provider.dart';
import '../services/hike_plan_service.dart';
import '../utils/app_colors.dart';

class EnhancedGroupHikeHubPage extends StatefulWidget {
  final HikePlan initialPlan;

  const EnhancedGroupHikeHubPage({super.key, required this.initialPlan});

  @override
  State<EnhancedGroupHikeHubPage> createState() =>
      _EnhancedGroupHikeHubPageState();
}

class _EnhancedGroupHikeHubPageState extends State<EnhancedGroupHikeHubPage>
    with TickerProviderStateMixin {
  late HikePlan _plan;
  late PageController _pageController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  List<String> _participantIds = [];
  int _currentPageIndex = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    _pageController = PageController(viewportFraction: 1.0);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _updateParticipantIds();
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
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
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
    context.read<RoutePlannerProvider>().loadPlan(_plan);
    await context.push('/route-planner');
    if (!mounted) return;
    setState(() => _plan = context.read<RoutePlannerProvider>().plan);
  }

  Future<void> _openUserPackingList(String userId) async {
    HapticFeedback.lightImpact();
    final result = await GoRouter.of(context).pushNamed('packingListPage',
        pathParameters: {'planId': _plan.id},
        queryParameters: {'userId': userId},
        extra: _plan);
    if (mounted && result is HikePlan) {
      setState(() => _plan = result);
      _refreshPlanData();
    }
  }

  Future<void> _openInviteSheet() async {
    // Check if already at max capacity (4 members)
    if (_participantIds.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum 4 members allowed in a group hike'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final me = auth.userProfile;
    if (me == null) return;

    final cs = Theme.of(context).colorScheme;
    List<user_model.UserProfile> results = [];
    final controller = TextEditingController();
    bool isLoading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          Future<void> _search(String q) async {
            setModalState(() => isLoading = true);
            results = await auth.searchUsersByUsername(q.trim());
            setModalState(() => isLoading = false);
          }

          Future<void> _sendInvite(user_model.UserProfile target) async {
            // Double check capacity
            if (_participantIds.length >= 4) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Group is full (4 members max)'),
                  backgroundColor: Colors.orange.shade700,
                ),
              );
              Navigator.of(ctx).pop();
              return;
            }

            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(target.uid)
                  .collection('notifications')
                  .add({
                'type': 'hike_invite',
                'planId': _plan.id,
                'planName': _plan.hikeName,
                'fromUserId': me.uid,
                'fromDisplayName': me.displayName,
                'createdAt': FieldValue.serverTimestamp(),
                'status': 'pending',
              });
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Invite sent to ${target.displayName}'),
                    backgroundColor: Colors.green.shade700),
              );
              Navigator.of(ctx).pop();
              _refreshPlanData();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to send invite: $e')));
            }
          }

          final remainingSlots = 4 - _participantIds.length;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 12,
              right: 12,
              top: 12,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(top: 10, bottom: 12),
                      decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.person_add_alt_1_rounded,
                              color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Invite friends to this hike',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700, fontSize: 16)),
                                Text(
                                  '$remainingSlots ${remainingSlots == 1 ? 'slot' : 'slots'} remaining',
                                  style: GoogleFonts.lato(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.of(ctx).pop()),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search friends by username'),
                        onSubmitted: _search,
                      ),
                    ),
                    if (isLoading)
                      const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator())
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (_, __) => Divider(
                              color: cs.outlineVariant.withOpacity(0.3)),
                          itemBuilder: (ctx, i) {
                            final u = results[i];
                            // Check if user is already in the group
                            final isAlreadyMember = _participantIds.contains(u.uid);
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: (u.photoURL != null &&
                                        u.photoURL!.isNotEmpty)
                                    ? NetworkImage(u.photoURL!)
                                    : null,
                                child:
                                    (u.photoURL == null || u.photoURL!.isEmpty)
                                        ? const Icon(Icons.person)
                                        : null,
                              ),
                              title: Text(u.displayName,
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text('@${u.username}',
                                  style: GoogleFonts.lato(
                                      color: cs.onSurfaceVariant)),
                              trailing: isAlreadyMember
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Member',
                                        style: GoogleFonts.lato(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onPrimaryContainer,
                                        ),
                                      ),
                                    )
                                  : TextButton(
                                      onPressed: () => _sendInvite(u),
                                      child: const Text('Invite')),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentPageIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppColors.primaryColor(context),
                strokeWidth: 2,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading adventure...',
                style: GoogleFonts.lato(
                  color: AppColors.subtleTextColor(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          // Main carousel with fade animation
          FadeTransition(
            opacity: _fadeAnimation,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const ClampingScrollPhysics(),
              itemCount: 1 + _participantIds.length,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Main overview with opacity animation
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double opacity = 1.0;
                      if (_pageController.hasClients) {
                        final page = _pageController.page ?? 0.0;
                        opacity = (1.0 - page.clamp(0.0, 1.0)).clamp(0.0, 1.0);
                      }
                      return Opacity(
                        opacity: opacity,
                        child: _buildMainOverviewPage(context),
                      );
                    },
                  );
                } else {
                  // Participant pages with fade in
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double opacity = 1.0;
                      if (_pageController.hasClients) {
                        final page = _pageController.page ?? 0.0;
                        final diff = (page - index).abs();
                        opacity = (1.0 - diff).clamp(0.0, 1.0);
                      }
                      return Opacity(
                        opacity: opacity,
                        child: _buildParticipantPage(
                            context, _participantIds[index - 1]),
                      );
                    },
                  );
                }
              },
            ),
          ),

          // Elegant page indicator
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: _buildPageIndicator(cs),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Container(
        margin: const EdgeInsets.all(8),
        child: Material(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          child: Material(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.lightImpact();
                // TODO: Implement share functionality
              },
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.ios_share_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(ColorScheme cs) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            child: SmoothPageIndicator(
              controller: _pageController,
              count: 1 + _participantIds.length,
              effect: WormEffect(
                dotWidth: 8,
                dotHeight: 8,
                spacing: 8,
                activeDotColor: AppColors.primaryColor(context),
                dotColor: Colors.white.withOpacity(0.2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainOverviewPage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRoute = _plan.dailyRoutes.any((r) => r.points.isNotEmpty);
    final hasLocation = _plan.latitude != null && _plan.longitude != null;
    final dayCount = _plan.endDate != null
        ? _plan.endDate!.difference(_plan.startDate).inDays + 1
        : 1;
    final dateRange = dayCount > 1
        ? '${DateFormat('MMM d').format(_plan.startDate)} - ${DateFormat('MMM d').format(_plan.endDate!)}'
        : DateFormat('MMMM d, yyyy').format(_plan.startDate);

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        // Beautiful header with map
        SliverToBoxAdapter(
          child: _buildMapHeader(context, hasRoute, hasLocation),
        ),

        // Main content
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF0A0A0A),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Elegant title section
                  _buildTitleSection(),
                  const SizedBox(height: 32),

                  // Info cards with glassmorphism
                  _buildInfoCards(dateRange, dayCount),
                  const SizedBox(height: 32),

                  // Team section
                  _buildTeamSection(context),
                  const SizedBox(height: 24),

                  // Action cards
                  _buildActionSection(context, hasLocation, hasRoute),
                  const SizedBox(
                      height: 80), // Extra padding for page indicator
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapHeader(
      BuildContext context, bool hasRoute, bool hasLocation) {
    final allPoints = _plan.dailyRoutes.expand((r) => r.points).toList();

    return Container(
      height: 350,
      child: Stack(
        children: [
          // Map or gradient background
          if (hasRoute && allPoints.isNotEmpty) ...[
            ClipRRect(
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(allPoints),
                    padding: const EdgeInsets.all(40),
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.treknoteflutter',
                  ),
                  PolylineLayer(
                    polylines: _plan.dailyRoutes.map((route) {
                      return Polyline(
                        points: route.points,
                        strokeWidth: 4,
                        color: AppColors.primaryColor(context),
                        borderStrokeWidth: 2,
                        borderColor: Colors.white.withOpacity(0.5),
                      );
                    }).toList(),
                  ),
                  // Start and end markers
                  if (allPoints.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        // Start marker
                        Marker(
                          point: allPoints.first,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.flag_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        // End marker
                        if (allPoints.length > 1)
                          Marker(
                            point: allPoints.last,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ] else if (hasLocation &&
              _plan.latitude != null &&
              _plan.longitude != null) ...[
            // Show location without route
            ClipRRect(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_plan.latitude!, _plan.longitude!),
                  initialZoom: 12,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.treknoteflutter',
                    tileBuilder: (context, tileWidget, tile) {
                      return ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.3),
                          BlendMode.darken,
                        ),
                        child: tileWidget,
                      );
                    },
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_plan.latitude!, _plan.longitude!),
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor(context),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // Default gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryColor(context).withOpacity(0.8),
                    AppColors.primaryColor(context).withOpacity(0.4),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.terrain_rounded,
                      size: 80,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No route planned yet',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF1A1A1A),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _plan.hikeName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 32,
            color: Colors.white,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 16,
              color: AppColors.primaryColor(context).withOpacity(0.8),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _plan.location,
                style: GoogleFonts.lato(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCards(String dateRange, int dayCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.calendar_today_rounded, dateRange),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.timer_outlined, '$dayCount days'),
          if (_plan.lengthKm != null && _plan.lengthKm! > 0) ...[
            const SizedBox(height: 16),
            _buildInfoRow(Icons.route_rounded,
                '${_plan.lengthKm!.toStringAsFixed(1)} km'),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryColor(context).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.primaryColor(context),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: GoogleFonts.lato(
            fontSize: 15,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSection(BuildContext context) {
    final canInviteMore = _participantIds.length < 4;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.groups_rounded,
              color: AppColors.primaryColor(context),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Team',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            if (canInviteMore) ...[
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _openInviteSheet();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryColor(context).withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 14,
                          color: AppColors.primaryColor(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Add',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _participantIds.length >= 4 
                    ? Colors.orange.withOpacity(0.2)
                    : AppColors.primaryColor(context).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_participantIds.length}/4 members',
                style: GoogleFonts.lato(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _participantIds.length >= 4 
                      ? Colors.orange
                      : AppColors.primaryColor(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildParticipantAvatars(),
      ],
    );
  }

  Widget _buildParticipantAvatars() {
    // Handle empty participant list
    if (_participantIds.isEmpty) {
      return Container(
        height: 56,
        alignment: Alignment.centerLeft,
        child: Text(
          'No team members yet',
          style: GoogleFonts.lato(
            fontSize: 14,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId,
              whereIn: _participantIds.take(10).toList())
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingAvatars();
        }

        final users = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'uid': doc.id,
            'name': data['displayName'] ?? 'Hiker',
            'photo': data['photoURL'],
          };
        }).toList();

        if (users.isEmpty) {
          return Container(
            height: 56,
            alignment: Alignment.centerLeft,
            child: Text(
              'Loading team members...',
              style: GoogleFonts.lato(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          );
        }

        return SizedBox(
          height: 56,
          child: Stack(
            children: users.asMap().entries.map((entry) {
              final index = entry.key;
              final user = entry.value;

              return Positioned(
                left: index * 40.0, // Overlap avatars
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _pageController.animateToPage(
                      index + 1,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2C2C2C),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage: user['photo'] != null
                          ? NetworkImage(user['photo'])
                          : null,
                      backgroundColor: AppColors.cardColor(context),
                      child: user['photo'] == null
                          ? Icon(
                              Icons.person_rounded,
                              color: AppColors.primaryColor(context),
                              size: 24,
                            )
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildLoadingAvatars() {
    return Row(
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.only(left: index > 0 ? -12 : 0),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            border: Border.all(
              color: const Color(0xFF0A0A0A),
              width: 3,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActionSection(
      BuildContext context, bool hasLocation, bool hasRoute) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        _buildModernActionCard(
          context,
          icon: Icons.cloud_outlined,
          title: 'Weather',
          subtitle: hasLocation ? 'Check forecast' : 'Add location first',
          color: Colors.blue,
          onTap: hasLocation ? _openWeather : null,
        ),
        const SizedBox(height: 12),
        _buildModernActionCard(
          context,
          icon: Icons.map_outlined,
          title: 'Route',
          subtitle: hasRoute ? 'View & edit' : 'Plan your route',
          color: Colors.purple,
          onTap: _openPlanner,
        ),
        const SizedBox(height: 12),
        _buildModernActionCard(
          context,
          icon: Icons.backpack_outlined,
          title: 'My Gear',
          subtitle: 'Manage packing list',
          color: AppColors.accentColor(context),
          onTap: () {
            final currentUserId = context.read<AuthProvider>().userProfile?.uid;
            if (currentUserId != null) {
              _openUserPackingList(currentUserId);
            }
          },
        ),
      ],
    );
  }

  Widget _buildModernActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isEnabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? color : color.withOpacity(0.5),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isEnabled
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: isEnabled
                            ? Colors.white.withOpacity(0.6)
                            : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color:
                    isEnabled ? color.withOpacity(0.6) : color.withOpacity(0.2),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantPage(BuildContext context, String participantId) {
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
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
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
              .doc(_plan.id)
              .snapshots(),
          builder: (context, planSnapshot) {
            final planData = planSnapshot.data?.data() as Map<String, dynamic>?;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A1A1A),
                    const Color(0xFF0A0A0A),
                  ],
                ),
              ),
              child: SafeArea(
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const SizedBox(height: 40),

                            // Profile header
                            _buildProfileHeader(userProfile, isCurrentUser),
                            const SizedBox(height: 32),

                            // Progress card
                            _buildProgressCard(planData),
                            const SizedBox(height: 20),

                            // Action buttons
                            _buildUserActions(
                                participantId, isCurrentUser, planData),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileHeader(
      user_model.UserProfile? userProfile, bool isCurrentUser) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isCurrentUser ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isCurrentUser
                        ? [
                            AppColors.primaryColor(context),
                            AppColors.primaryColor(context).withOpacity(0.6),
                          ]
                        : [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.1),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isCurrentUser
                          ? AppColors.primaryColor(context).withOpacity(0.3)
                          : Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  radius: 47,
                  backgroundImage: userProfile?.photoURL != null
                      ? NetworkImage(userProfile!.photoURL!)
                      : null,
                  backgroundColor: const Color(0xFF2C2C2C),
                  child: userProfile?.photoURL == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: Colors.white.withOpacity(0.5),
                        )
                      : null,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          userProfile?.displayName ?? 'Adventurer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        if (userProfile?.username != null) ...[
          const SizedBox(height: 4),
          Text(
            '@${userProfile!.username}',
            style: GoogleFonts.lato(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (isCurrentUser)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryColor(context).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primaryColor(context).withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              'You',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryColor(context),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressCard(Map<String, dynamic>? planData) {
    final preparationItems =
        planData?['preparationItems'] as Map<String, dynamic>? ?? {};
    final completedItems =
        preparationItems.values.where((v) => v == true).length;
    final prepProgress = completedItems / 4;

    final packingList = (planData?['packingList'] as List<dynamic>? ?? []);
    final packedItems =
        packingList.where((item) => item['isPacked'] == true).length;
    final packingProgress =
        packingList.isNotEmpty ? packedItems / packingList.length : 0.0;

    final overallProgress = (prepProgress + packingProgress) / 2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              Text(
                '${(overallProgress * 100).round()}%',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: _getProgressColor(overallProgress),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(overallProgress),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProgressItem('Preparation', prepProgress),
              _buildProgressItem('Packing', packingProgress),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String label, double progress) {
    return Column(
      children: [
        Text(
          '${(progress * 100).round()}%',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 12,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return AppColors.primaryColor(context);
    if (progress >= 0.5) return AppColors.accentColor(context);
    return Colors.red.shade400;
  }

  Widget _buildUserActions(String participantId, bool isCurrentUser,
      Map<String, dynamic>? planData) {
    final packingList = (planData?['packingList'] as List<dynamic>? ?? []);
    final packedItems =
        packingList.where((item) => item['isPacked'] == true).length;
    final totalItems = packingList.length;

    return Column(
      children: [
        _buildModernActionCard(
          context,
          icon: Icons.backpack_outlined,
          title: isCurrentUser ? 'My Packing List' : 'Packing List',
          subtitle: totalItems > 0
              ? '$packedItems of $totalItems items'
              : 'No items yet',
          color: AppColors.accentColor(context),
          onTap: () => _openUserPackingList(participantId),
        ),
      ],
    );
  }
}

// Custom painter for subtle pattern
class _SubtlePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;
    for (double i = 0; i < size.width; i += spacing) {
      for (double j = 0; j < size.height; j += spacing) {
        canvas.drawCircle(Offset(i, j), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
