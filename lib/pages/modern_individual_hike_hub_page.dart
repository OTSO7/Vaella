// lib/pages/modern_individual_hike_hub_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class ModernIndividualHikeHubPage extends StatefulWidget {
  final HikePlan initialPlan;

  const ModernIndividualHikeHubPage({super.key, required this.initialPlan});

  @override
  State<ModernIndividualHikeHubPage> createState() =>
      _ModernIndividualHikeHubPageState();
}

class _ModernIndividualHikeHubPageState
    extends State<ModernIndividualHikeHubPage> with TickerProviderStateMixin {
  late HikePlan _plan;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _refreshPlanData() async {
    try {
      final service = HikePlanService();
      final stream = service.getHikePlanStream(_plan.id);
      final updatedPlan = await stream.first;
      if (updatedPlan != null && mounted) {
        setState(() {
          _plan = updatedPlan;
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

  Future<void> _openPackingList() async {
    HapticFeedback.lightImpact();
    final currentUserId = context.read<AuthProvider>().userProfile?.uid;
    if (currentUserId == null) return;

    final result = await GoRouter.of(context).pushNamed('packingListPage',
        pathParameters: {'planId': _plan.id},
        queryParameters: {'userId': currentUserId},
        extra: _plan);
    if (mounted && result is HikePlan) {
      setState(() => _plan = result);
      _refreshPlanData();
    }
  }

  Future<void> _openFoodPlanner() async {
    HapticFeedback.lightImpact();
    final result = await context.pushNamed('foodPlannerPage',
        pathParameters: {'planId': _plan.id}, extra: _plan);
    if (mounted && result is HikePlan) {
      setState(() => _plan = result);
    } else {
      _refreshPlanData();
    }
  }

  Future<void> _openInviteSheet() async {
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
          Future<void> search(String q) async {
            setModalState(() => isLoading = true);
            results = await auth.searchUsersByUsername(q.trim());
            setModalState(() => isLoading = false);
          }

          Future<void> sendInvite(user_model.UserProfile target) async {
            try {
              // Make plan collaborative when first invite is sent
              if (!_plan.isCollaborative) {
                final updatedPlan = _plan.copyWith(
                  isCollaborative: true,
                  collabOwnerId: me.uid,
                );
                await HikePlanService().updateHikePlan(updatedPlan);
                setState(() => _plan = updatedPlan);

                // Navigate to group view after making plan collaborative
                if (mounted) {
                  Navigator.of(ctx).pop(); // Close invite sheet first
                  // Use pushReplacement instead of go to maintain navigation stack
                  context.pushReplacement('/group-hike-hub',
                      extra: updatedPlan);
                  return; // Exit early since we're navigating away
                }
              }

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
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to send invite: $e')));
            }
          }

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
                          Text('Invite friends to this hike',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const Spacer(),
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
                        onSubmitted: search,
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
                              trailing: TextButton(
                                  onPressed: () => sendInvite(u),
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

    final hasRoute = _plan.dailyRoutes.any((r) => r.points.isNotEmpty);
    final hasLocation = _plan.latitude != null && _plan.longitude != null;
    final dayCount = _plan.endDate != null
        ? _plan.endDate!.difference(_plan.startDate).inDays + 1
        : 1;
    final dateRange = dayCount > 1
        ? '${DateFormat('MMM d').format(_plan.startDate)} - ${DateFormat('MMM d').format(_plan.endDate!)}'
        : DateFormat('MMMM d, yyyy').format(_plan.startDate);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
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
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Elegant title section
                      _buildTitleSection(),
                      const SizedBox(height: 24),

                      // Info cards with glassmorphism
                      _buildInfoCards(dateRange, dayCount),
                      const SizedBox(height: 24),

                      // Action cards
                      _buildActionSection(context, hasLocation, hasRoute),
                      const SizedBox(height: 24),

                      // Invite to group adventure section
                      _buildInvitePrompt(context),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
                _openInviteSheet();
              },
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
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

  Widget _buildMapHeader(
      BuildContext context, bool hasRoute, bool hasLocation) {
    final allPoints = _plan.dailyRoutes.expand((r) => r.points).toList();

    return SizedBox(
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

          // Gradient overlay at bottom only
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
                    Theme.of(context).scaffoldBackgroundColor,
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
            fontSize: 28,
            color: Theme.of(context).colorScheme.onSurface,
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
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
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
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildModernActionCard(
          context,
          icon: Icons.cloud_outlined,
          title: 'Weather',
          subtitle: hasLocation ? 'Check forecast' : 'Add location first',
          color: Colors.lightBlue.shade600,
          onTap: hasLocation ? _openWeather : null,
        ),
        const SizedBox(height: 12),
        _buildModernActionCard(
          context,
          icon: Icons.map_outlined,
          title: 'Route',
          subtitle: hasRoute ? 'View & edit' : 'Plan your route',
          color: Colors.deepPurple.shade400,
          onTap: _openPlanner,
        ),
        const SizedBox(height: 12),
        _buildModernActionCard(
          context,
          icon: Icons.backpack_outlined,
          title: 'My Gear',
          subtitle: 'Manage packing list',
          color: Colors.teal.shade600,
          onTap: _openPackingList,
        ),
        const SizedBox(height: 12),
        _buildModernActionCard(
          context,
          icon: Icons.restaurant_menu,
          title: 'Food Planner',
          subtitle: 'Plan meals and snacks',
          color: Colors.orange.shade600,
          onTap: _openFoodPlanner,
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
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: isEnabled
                            ? Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6)
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.3),
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

  Widget _buildInvitePrompt(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor(context).withOpacity(0.15),
            AppColors.primaryColor(context).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryColor(context).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryColor(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.group_add_rounded,
              color: AppColors.primaryColor(context),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make it a Group Adventure',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Invite friends to plan together',
                  style: GoogleFonts.lato(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.primaryColor(context),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.lightImpact();
                _openInviteSheet();
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'Invite',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
