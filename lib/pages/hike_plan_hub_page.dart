import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
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
import '../utils/map_helpers.dart';
import '../widgets/add_hike_plan_form.dart';
import 'group_hike_hub_page.dart';
import 'modern_individual_hike_hub_page.dart';

class HikePlanHubPage extends StatefulWidget {
  final HikePlan initialPlan;
  const HikePlanHubPage({super.key, required this.initialPlan});

  @override
  State<HikePlanHubPage> createState() => _HikePlanHubPageState();
}

class _HikePlanHubPageState extends State<HikePlanHubPage> {
  late HikePlan _plan;
  bool _hasNavigated = false;
  bool _isInitialized = false;
  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;

    // Check for group plan navigation immediately and defer UI initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForGroupNavigation();
      if (mounted && !_hasNavigated) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  void _checkForGroupNavigation() {
    if (_hasNavigated) return;

    final me = context.read<AuthProvider>().userProfile;
    final ids = <String>{
      if (_plan.collabOwnerId != null && _plan.collabOwnerId!.isNotEmpty)
        _plan.collabOwnerId!,
      ..._plan.collaboratorIds,
      if (me != null && me.uid.isNotEmpty) me.uid,
    }.toList();

    final isGroupPlan = ids.length > 1;
    
    if (mounted && !_hasNavigated) {
      _hasNavigated = true;
      
      // Navigate to appropriate page based on plan type
      final targetPage = isGroupPlan 
          ? GroupHikeHubPage(initialPlan: _plan)
          : ModernIndividualHikeHubPage(initialPlan: _plan);
      
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetPage,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOut;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only refresh if we haven't navigated away
    if (!_hasNavigated) {
      _refreshPlanData();
    }
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

  bool get _hasRoute => _plan.dailyRoutes.any((r) => r.points.isNotEmpty);
  bool get _hasLocation => _plan.latitude != null && _plan.longitude != null;

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

  Future<void> _openAddPlanModal() async {
    final result = await showModalBottomSheet<HikePlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scroll) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24.0)),
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24.0)),
                  child: PrimaryScrollController(
                      controller: scroll, child: const AddHikePlanForm()),
                ),
              );
            },
          ),
        );
      },
    );
    if (!mounted || result == null) return;
    try {
      await HikePlanService().addHikePlan(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('New plan "${result.hikeName}" added!'),
            backgroundColor: Colors.green.shade700),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error adding plan: $e')));
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
          Future<void> _search(String q) async {
            setModalState(() => isLoading = true);
            results = await auth.searchUsersByUsername(q.trim());
            setModalState(() => isLoading = false);
          }

          Future<void> _sendInvite(user_model.UserProfile target) async {
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

  Future<void> _openPlanner() async {
    context.read<RoutePlannerProvider>().loadPlan(_plan);
    await context.push('/route-planner');
    if (!mounted) return;
    setState(() => _plan = context.read<RoutePlannerProvider>().plan);
  }

  void _openWeather() {
    if (_plan.latitude != null && _plan.longitude != null) {
      GoRouter.of(context).pushNamed('weatherPage',
          pathParameters: {'planId': _plan.id}, extra: _plan);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Sääennuste vaatii kohteen koordinaatit.'),
            backgroundColor: AppColors.errorColor(context)),
      );
    }
  }

  Future<void> _openPacking() async {
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

  Future<void> _openFood() async {
    final result = await context.pushNamed('foodPlannerPage',
        pathParameters: {'planId': _plan.id}, extra: _plan);
    if (mounted && result is HikePlan) {
      setState(() {
        _plan = result;
      });
    } else {
      _refreshPlanData();
    }
  }

  Future<void> _openGroupProgress() async {
    // Show functional group progress tracking interface
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.analytics_outlined,
                        size: 36,
                        color: cs.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Group Progress',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'See how everyone is preparing',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: cs.onPrimaryContainer.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _GroupProgressContent(
                  plan: _plan,
                  participantIds: <String>{
                    if (_plan.collabOwnerId != null &&
                        _plan.collabOwnerId!.isNotEmpty)
                      _plan.collabOwnerId!,
                    ..._plan.collaboratorIds,
                    if (context.read<AuthProvider>().userProfile != null)
                      context.read<AuthProvider>().userProfile!.uid,
                  }.toList(),
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Show loading screen until initialization is complete or navigation has occurred
    if (!_isInitialized || _hasNavigated) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final me = context.watch<AuthProvider>().userProfile;

    // Participant IDs: owner + collaborators + me
    final ids = <String>{
      if (_plan.collabOwnerId != null && _plan.collabOwnerId!.isNotEmpty)
        _plan.collabOwnerId!,
      ..._plan.collaboratorIds,
      if (me != null && me.uid.isNotEmpty) me.uid,
    }.toList();

    final dateRange = _dateRangeString(_plan.startDate, _plan.endDate);
    final distanceText = _plan.lengthKm != null && _plan.lengthKm! > 0
        ? '${_plan.lengthKm!.toStringAsFixed(1)} km'
        : '—';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
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
                  onPressed: _openAddPlanModal),
              IconButton(
                  tooltip: 'Invite',
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  onPressed: _openInviteSheet),
              const SizedBox(width: 6),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground
              ],
              background: _HeaderBackground(
                hasRoute: _hasRoute,
                hasLocation: _hasLocation,
                planCenter: _hasLocation
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
                  days: _dayCount(_plan.startDate, _plan.endDate),
                ),
              ),
            ),
          ),

          // Modern grid-based layout
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverToBoxAdapter(
              child: _ModernGridLayout(
                plan: _plan,
                hasRoute: _hasRoute,
                hasLocation: _hasLocation,
                planCenter: _hasLocation
                    ? LatLng(_plan.latitude!, _plan.longitude!)
                    : null,
                participantIds: ids,
                onOpenWeather: _openWeather,
                onOpenPacking: _openPacking,
                onOpenFood: _openFood,
                onOpenPlanner: _openPlanner,
                onInvite: _openInviteSheet,
                onOpenGroupProgress: _openGroupProgress,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= HEADER =================
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
    if (hasRoute) {
      final allPoints = dailyRoutes.expand((r) => r.points).toList();
      final bounds =
          allPoints.isNotEmpty ? LatLngBounds.fromPoints(allPoints) : null;
      final arrows = generateArrowMarkersForDays(dailyRoutes);
      bg = FlutterMap(
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
              subdomains: const ['a', 'b', 'c', 'd']),
          PolylineLayer(
            polylines: dailyRoutes
                .where((r) => r.points.isNotEmpty)
                .map(
                  (r) => Polyline(
                    points: r.points,
                    color: r.routeColor.withOpacity(0.96),
                    strokeWidth: 5,
                    borderColor: Colors.black.withOpacity(0.22),
                    borderStrokeWidth: 1.2,
                  ),
                )
                .toList(),
          ),
          if (arrows.isNotEmpty) MarkerLayer(markers: arrows),
        ],
      );
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
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd']),
          MarkerLayer(
            markers: [
              Marker(
                point: planCenter!,
                width: 38,
                height: 38,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                      color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.place, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      );
    } else if ((imageUrl ?? '').isNotEmpty) {
      bg = CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover);
    } else {
      final cs = Theme.of(context).colorScheme;
      bg = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.surfaceContainer, cs.surfaceContainerHighest],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
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
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
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
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ================= MODERN CARD COMPONENTS =================

// Enhanced Group Hub Card - Apple-inspired group collaboration
class _ModernGroupHubCard extends StatelessWidget {
  final HikePlan plan;
  final List<String> participantIds;
  final VoidCallback onInvite;
  final VoidCallback onOpenGroupProgress;

  const _ModernGroupHubCard({
    required this.plan,
    required this.participantIds,
    required this.onInvite,
    required this.onOpenGroupProgress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
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
        border: Border.all(
          color: cs.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: cs.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with group info and actions
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

            const SizedBox(height: 24),

            // Participant avatars with Apple-style design
            _buildParticipantRow(context, cs),

            const SizedBox(height: 24),

            // Action buttons with Apple-style design
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    cs: cs,
                    icon: Icons.analytics_outlined,
                    label: 'Group Progress',
                    onTap: onOpenGroupProgress,
                    isPrimary: true,
                  ),
                ),
                const SizedBox(width: 12),
                _buildInviteButton(context, cs),
              ],
            ),
          ],
        ),
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
            // Avatar stack with Apple-style overlapping
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
                        border: Border.all(
                          color: cs.surface,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
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
                                size: 24,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            if (users.length < participantIds.length) ...[
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surfaceContainerHighest,
                  border: Border.all(
                    color: cs.outline.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+${participantIds.length - users.length}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Group status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: cs.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    color: Colors.green.shade400,
                    size: 8,
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

  Widget _buildActionButton({
    required BuildContext context,
    required ColorScheme cs,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: isPrimary
                ? cs.surface.withOpacity(0.9)
                : cs.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outline.withOpacity(0.2),
            ),
            boxShadow: [
              if (isPrimary) ...[
                BoxShadow(
                  color: cs.primary.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isPrimary ? cs.primary : cs.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isPrimary ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteButton(BuildContext context, ColorScheme cs) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onInvite,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.person_add_alt_1_rounded,
            color: cs.onPrimary,
            size: 20,
          ),
        ),
      ),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
            spreadRadius: 0,
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.cloud_outlined,
                    color: cs.onPrimaryContainer,
                    size: 24,
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

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 160),
      child: Container(
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
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
              spreadRadius: 0,
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
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.backpack_outlined,
                          color: cs.onPrimaryContainer,
                          size: 22,
                        ),
                      ),
                      const Expanded(child: SizedBox.shrink()),
                      Flexible(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    cs.surfaceContainerHighest.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Personal',
                                style: GoogleFonts.lato(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (totalCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: progress > 0.8
                                      ? cs.primary.withOpacity(0.1)
                                      : cs.surfaceContainerHighest
                                          .withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${(progress * 100).round()}%',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: progress > 0.8
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'My Packing List',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (totalCount > 0) ...[
                    Text(
                      '$packedCount of $totalCount items packed',
                      style: GoogleFonts.lato(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor:
                            cs.surfaceContainerHighest.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress > 0.8
                              ? cs.primary
                              : cs.primary.withOpacity(0.6),
                        ),
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

  Map<String, double> _calculateFoodTotals() {
    if (plan.foodPlanJson == null || plan.foodPlanJson!.isEmpty) {
      return {'calories': 0, 'items': 0, 'days': 0};
    }

    try {
      final List<dynamic> decoded = json.decode(plan.foodPlanJson!);
      double totalCalories = 0;
      int totalItems = 0;
      int daysWithFood = 0;

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

        if (dayHasItems) daysWithFood++;
      }

      return {
        'calories': totalCalories,
        'items': totalItems.toDouble(),
        'days': daysWithFood.toDouble(),
      };
    } catch (e) {
      return {'calories': 0, 'items': 0, 'days': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = plan.endDate != null
        ? plan.endDate!.difference(plan.startDate).inDays + 1
        : 1;
    final foodData = _calculateFoodTotals();
    final plannedDays = foodData['days']!.toInt();
    final progress = days > 0 ? (plannedDays / days) : 0.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 160),
      child: Container(
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
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
              spreadRadius: 0,
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
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: cs.secondary.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.restaurant_menu,
                          color: cs.onSecondaryContainer,
                          size: 22,
                        ),
                      ),
                      const Expanded(child: SizedBox.shrink()),
                      Flexible(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    cs.surfaceContainerHighest.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Personal',
                                style: GoogleFonts.lato(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (plannedDays > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: progress > 0.8
                                      ? cs.primary.withOpacity(0.1)
                                      : cs.surfaceContainerHighest
                                          .withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${(progress * 100).round()}%',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: progress > 0.8
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'My Food Plan',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (plannedDays > 0) ...[
                    Text(
                      '$plannedDays of $days days planned',
                      style: GoogleFonts.lato(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor:
                            cs.surfaceContainerHighest.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress > 0.8
                              ? cs.primary
                              : cs.primary.withOpacity(0.6),
                        ),
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
      ),
    );
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
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Stack(
            children: [
              // Subtle map preview if has route
              if (hasRoute || hasLocation)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Opacity(
                      opacity: 0.15,
                      child: _HeaderBackground(
                        hasRoute: hasRoute,
                        hasLocation: hasLocation,
                        planCenter: planCenter,
                        imageUrl: plan.imageUrl,
                        dailyRoutes: plan.dailyRoutes,
                      ),
                    ),
                  ),
                ),

              // Content
              Positioned.fill(
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
                              color: hasRoute
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: hasRoute
                                      ? cs.primary.withOpacity(0.15)
                                      : cs.onSurfaceVariant.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              hasRoute ? Icons.route : Icons.add_road_rounded,
                              color: hasRoute
                                  ? cs.onPrimaryContainer
                                  : cs.onSurfaceVariant,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              hasRoute ? 'Route Planned' : 'Plan Route',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
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
                        const Spacer(),
                        Text(
                          '${totalDistance.toStringAsFixed(1)} km total distance',
                          style: GoogleFonts.lato(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${plan.dailyRoutes.length} day segments',
                          style: GoogleFonts.lato(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          'Create your hiking route',
                          style: GoogleFonts.lato(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= MODERN GRID LAYOUT =================
class _ModernGridLayout extends StatelessWidget {
  final HikePlan plan;
  final bool hasRoute;
  final bool hasLocation;
  final LatLng? planCenter;
  final List<String> participantIds;
  final VoidCallback onOpenWeather;
  final VoidCallback onOpenPacking;
  final VoidCallback onOpenFood;
  final VoidCallback onOpenPlanner;
  final VoidCallback onInvite;
  final VoidCallback onOpenGroupProgress;

  const _ModernGridLayout({
    required this.plan,
    required this.hasRoute,
    required this.hasLocation,
    required this.planCenter,
    required this.participantIds,
    required this.onOpenWeather,
    required this.onOpenPacking,
    required this.onOpenFood,
    required this.onOpenPlanner,
    required this.onInvite,
    required this.onOpenGroupProgress,
  });

  @override
  Widget build(BuildContext context) {
    final isGroupPlan = participantIds.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group collaboration hub - prominent position for group plans
        if (isGroupPlan) ...[
          _ModernGroupHubCard(
            plan: plan,
            participantIds: participantIds,
            onInvite: onInvite,
            onOpenGroupProgress: onOpenGroupProgress,
          ),
          const SizedBox(height: 20),
        ],

        // Primary featured card - Weather (full width)
        _ModernWeatherCard(
          plan: plan,
          onOpen: onOpenWeather,
        ),

        const SizedBox(height: 20),

        // Two-column grid for main actions with group features
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _ModernPackingCard(
                  plan: plan,
                  onOpen: onOpenPacking,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _ModernFoodCard(
                  plan: plan,
                  onOpen: onOpenFood,
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

        // Invite section for single-person plans
        if (!isGroupPlan) ...[
          const SizedBox(height: 20),
          _buildInvitePrompt(context),
        ],
      ],
    );
  }

  Widget _buildInvitePrompt(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withOpacity(0.3),
            cs.primaryContainer.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.group_add_rounded,
              color: cs.primary,
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
            color: cs.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onInvite,
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

// ================= GROUP PROGRESS CONTENT =================
class _GroupProgressContent extends StatelessWidget {
  final HikePlan plan;
  final List<String> participantIds;

  const _GroupProgressContent({
    required this.plan,
    required this.participantIds,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId,
                whereIn: participantIds.take(10).toList())
            .snapshots(),
        builder: (context, usersSnapshot) {
          if (!usersSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = usersSnapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'uid': doc.id,
              'name': data['displayName'] ?? 'Hiker',
              'photo': data['photoURL'],
            };
          }).toList();

          return Column(
            children: users
                .map((user) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _UserProgressCard(
                        user: user,
                        planId: plan.id,
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _UserProgressCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String planId;

  const _UserProgressCard({
    required this.user,
    required this.planId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user['uid'])
          .collection('plans')
          .doc(planId)
          .snapshots(),
      builder: (context, planSnapshot) {
        if (!planSnapshot.hasData) {
          return _buildLoadingCard(context, cs);
        }

        final planData = planSnapshot.data?.data() as Map<String, dynamic>?;
        if (planData == null) {
          return _buildNoDataCard(context, cs);
        }

        // Calculate packing progress
        final packingList = (planData['packingList'] as List<dynamic>? ?? []);
        final packedItems =
            packingList.where((item) => item['isPacked'] == true).length;
        final totalItems = packingList.length;
        final packingProgress = totalItems > 0 ? packedItems / totalItems : 0.0;

        // Calculate food planning progress
        final foodPlanJson = planData['foodPlanJson'] as String?;
        final foodProgress = _calculateFoodProgress(foodPlanJson, planData);

        return Container(
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
              color: cs.outlineVariant.withOpacity(0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // User header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.outline.withOpacity(0.2),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundImage: user['photo'] != null
                            ? NetworkImage(user['photo'])
                            : null,
                        backgroundColor: cs.primaryContainer,
                        child: user['photo'] == null
                            ? Icon(
                                Icons.person_rounded,
                                color: cs.onPrimaryContainer,
                                size: 28,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Personal progress',
                            style: GoogleFonts.lato(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Progress sections
                Row(
                  children: [
                    Expanded(
                      child: _ProgressSection(
                        icon: Icons.backpack_outlined,
                        title: 'Packing',
                        progress: packingProgress,
                        subtitle: totalItems > 0
                            ? '$packedItems of $totalItems packed'
                            : 'No items yet',
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProgressSection(
                        icon: Icons.restaurant_menu,
                        title: 'Food Plan',
                        progress: foodProgress,
                        subtitle: _getFoodProgressText(foodPlanJson, planData),
                        color: cs.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _calculateFoodProgress(
      String? foodPlanJson, Map<String, dynamic> planData) {
    if (foodPlanJson == null || foodPlanJson.isEmpty) return 0.0;

    try {
      final startDate = (planData['startDate'] as Timestamp).toDate();
      final endDate = (planData['endDate'] as Timestamp?)?.toDate();
      final totalDays =
          endDate != null ? endDate.difference(startDate).inDays + 1 : 1;

      final List<dynamic> decoded = json.decode(foodPlanJson);
      int daysWithFood = 0;

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

        if (dayHasItems) daysWithFood++;
      }

      return totalDays > 0 ? (daysWithFood / totalDays) : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  String _getFoodProgressText(
      String? foodPlanJson, Map<String, dynamic> planData) {
    if (foodPlanJson == null || foodPlanJson.isEmpty) return 'No plan yet';

    try {
      final startDate = (planData['startDate'] as Timestamp).toDate();
      final endDate = (planData['endDate'] as Timestamp?)?.toDate();
      final totalDays =
          endDate != null ? endDate.difference(startDate).inDays + 1 : 1;

      final List<dynamic> decoded = json.decode(foodPlanJson);
      int daysWithFood = 0;

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

        if (dayHasItems) daysWithFood++;
      }

      return '$daysWithFood of $totalDays days';
    } catch (e) {
      return 'No plan yet';
    }
  }

  Widget _buildLoadingCard(BuildContext context, ColorScheme cs) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildNoDataCard(BuildContext context, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage:
                user['photo'] != null ? NetworkImage(user['photo']) : null,
            backgroundColor: cs.primaryContainer,
            child: user['photo'] == null
                ? Icon(
                    Icons.person_rounded,
                    color: cs.onPrimaryContainer,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'No data available',
                  style: GoogleFonts.lato(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final double progress;
  final String subtitle;
  final Color color;

  const _ProgressSection({
    required this.icon,
    required this.title,
    required this.progress,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: cs.surfaceContainerHighest.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  subtitle,
                  style: GoogleFonts.lato(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
