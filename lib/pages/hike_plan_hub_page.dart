import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
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

class HikePlanHubPage extends StatefulWidget {
  final HikePlan initialPlan;
  const HikePlanHubPage({super.key, required this.initialPlan});

  @override
  State<HikePlanHubPage> createState() => _HikePlanHubPageState();
}

class _HikePlanHubPageState extends State<HikePlanHubPage> {
  late HikePlan _plan;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh plan data when returning from other pages
    _refreshPlanData();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
            expandedHeight: 300,
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
              titlePadding: const EdgeInsetsDirectional.only(
                  start: 56, bottom: 14, end: 56),
              title: Text(_plan.hikeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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

          // Subtle collaborators indicator
          if (ids.isNotEmpty && ids.length > 1)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              sliver: SliverToBoxAdapter(
                child: _SubtleCollaboratorsIndicator(
                  participantIds: ids.take(5).toList(),
                  totalCount: ids.length,
                ),
              ),
            ),

          // Weather Forecast - First
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            sliver: SliverToBoxAdapter(
              child: _EnhancedWeatherCard(
                plan: _plan,
                onOpen: _openWeather,
              ),
            ),
          ),

          // Packing List - Second
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverToBoxAdapter(
                child: _GearSummaryCard(plan: _plan, onOpen: _openPacking)),
          ),

          // Food Planner - Third
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverToBoxAdapter(
                child: _FoodSummaryCard(plan: _plan, onOpen: _openFood)),
          ),

          // Route Planner - Fourth
          if (_hasRoute || _hasLocation)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverToBoxAdapter(
                child: _RoutePreviewCard(
                  plan: _plan,
                  hasRoute: _hasRoute,
                  hasLocation: _hasLocation,
                  planCenter: _hasLocation
                      ? LatLng(_plan.latitude!, _plan.longitude!)
                      : null,
                  onOpenPlanner: _openPlanner,
                ),
              ),
            ),

          // Collaborators
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
              child: ids.isEmpty
                  ? _EmptyCollabState(onInvite: _openInviteSheet)
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where(FieldPath.documentId,
                              whereIn: ids.take(10).toList())
                          .snapshots(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];
                        final participants = <_Participant>[];
                        for (final d in docs) {
                          final data = d.data();
                          participants.add(
                            _Participant(
                              uid: d.id,
                              name: (data['displayName'] as String?) ?? 'Hiker',
                              avatarUrl: data['photoURL'] as String?,
                            ),
                          );
                        }
                        if (participants.every((p) => p.uid != me?.uid) &&
                            me != null) {
                          participants.insert(
                              0,
                              _Participant(
                                  uid: me.uid,
                                  name: me.displayName,
                                  avatarUrl: me.photoURL));
                        }
                        if (participants.isEmpty)
                          return _EmptyCollabState(onInvite: _openInviteSheet);

                        return _CollaboratorsSection(
                            participants: participants,
                            onInvite: _openInviteSheet);
                      },
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
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        if (location.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 14, color: Colors.white70),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.lato(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                dateRange,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.lato(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.route_outlined, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(distanceText,
                      style: GoogleFonts.lato(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('${days} days',
                            style: GoogleFonts.lato(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= ROUTE PREVIEW =================
class _RoutePreviewCard extends StatelessWidget {
  final HikePlan plan;
  final bool hasRoute;
  final bool hasLocation;
  final LatLng? planCenter;
  final VoidCallback onOpenPlanner;
  const _RoutePreviewCard(
      {required this.plan,
      required this.hasRoute,
      required this.hasLocation,
      required this.planCenter,
      required this.onOpenPlanner});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Calculate route statistics including both ascent and descent
    final totalDistance = plan.dailyRoutes.fold<double>(
        0.0, (sum, route) => sum + (route.summary.distance / 1000));
    final totalDuration = plan.dailyRoutes
        .fold<double>(0.0, (sum, route) => sum + route.summary.duration);
    final totalAscent = plan.dailyRoutes
        .fold<double>(0.0, (sum, route) => sum + route.summary.ascent);
    final totalDescent = plan.dailyRoutes
        .fold<double>(0.0, (sum, route) => sum + route.summary.descent);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black.withOpacity(0.16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
        ),
        child: InkWell(
          onTap: onOpenPlanner,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Enhanced map preview with gradient overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _HeaderBackground(
                        hasRoute: hasRoute,
                        hasLocation: hasLocation,
                        planCenter: planCenter,
                        imageUrl: plan.imageUrl,
                        dailyRoutes: plan.dailyRoutes,
                      ),
                    ),
                  ),
                  // Gradient overlay for better text readability
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Enhanced floating open indicator
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.launch_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Open Planner',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Content section with enhanced layout
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon and title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.route_outlined,
                            color: cs.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Route Overview',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                hasRoute
                                    ? 'Tap anywhere to explore in detail'
                                    : 'Start planning your route',
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

                    if (hasRoute && totalDistance > 0) ...[
                      const SizedBox(height: 16),
                      // Enhanced route statistics with grid layout
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: cs.outlineVariant.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            // Primary stats row
                            Row(
                              children: [
                                _EnhancedStatItem(
                                  icon: Icons.straighten,
                                  label: 'Distance',
                                  value:
                                      '${totalDistance.toStringAsFixed(1)} km',
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 16),
                                if (totalDuration > 0)
                                  _EnhancedStatItem(
                                    icon: Icons.access_time,
                                    label: 'Duration',
                                    value: _formatDuration(totalDuration),
                                    color: Colors.orange.shade600,
                                  ),
                              ],
                            ),

                            // Elevation stats row (if available)
                            if (totalAscent > 0 || totalDescent > 0) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (totalAscent > 0)
                                    _EnhancedStatItem(
                                      icon: Icons.trending_up,
                                      label: 'Gain',
                                      value: '${totalAscent.toInt()}m',
                                      color: Colors.green.shade600,
                                    ),
                                  if (totalAscent > 0 && totalDescent > 0)
                                    const SizedBox(width: 16),
                                  if (totalDescent > 0)
                                    _EnhancedStatItem(
                                      icon: Icons.trending_down,
                                      label: 'Descent',
                                      value: '${totalDescent.toInt()}m',
                                      color: Colors.red.shade600,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    if (!hasRoute && !hasLocation) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: cs.outlineVariant.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_location_alt_outlined,
                              size: 32,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start planning your route',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add waypoints and create your perfect hiking route',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lato(
                                color: cs.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final d = Duration(seconds: seconds.round());
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }
}

// Enhanced statistics item widget for better visual hierarchy
class _EnhancedStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _EnhancedStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ================= SUBTLE COLLABORATORS INDICATOR =================
class _SubtleCollaboratorsIndicator extends StatelessWidget {
  final List<String> participantIds;
  final int totalCount;

  const _SubtleCollaboratorsIndicator({
    required this.participantIds,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: participantIds)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.group_outlined,
                size: 16,
                color: cs.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Planning with ${totalCount > 1 ? '${totalCount - 1}' : ''} ${totalCount > 2 ? 'friends' : 'friend'}',
                style: GoogleFonts.lato(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 8),
              // Avatar stack
              SizedBox(
                height: 20,
                width: docs.length > 3 ? 60 : docs.length * 18.0,
                child: Stack(
                  children: List.generate(
                    docs.length > 3 ? 3 : docs.length,
                    (index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final avatarUrl = data['photoURL'] as String?;

                      return Positioned(
                        left: index * 12.0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: CircleAvatar(
                            radius: 8,
                            backgroundImage:
                                (avatarUrl != null && avatarUrl.isNotEmpty)
                                    ? NetworkImage(avatarUrl)
                                    : null,
                            backgroundColor: cs.surfaceContainerHighest,
                            child: (avatarUrl == null || avatarUrl.isEmpty)
                                ? Icon(Icons.person,
                                    size: 10, color: cs.onSurfaceVariant)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (totalCount > 3) ...[
                const SizedBox(width: 4),
                Text(
                  '+${totalCount - 3}',
                  style: GoogleFonts.lato(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ================= SECTION CARD =================
class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _SectionCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black.withOpacity(0.16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
        ),
        padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: child,
      ),
    );
  }
}

// ================= GEAR & FOOD =================
class _GearSummaryCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback onOpen;
  const _GearSummaryCard({required this.plan, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final packedCount = plan.packingList.where((i) => i.isPacked).length;
    final totalCount = plan.packingList.length;
    final progress = totalCount == 0 ? 0.0 : packedCount / totalCount;

    if (totalCount == 0) {
      return _SectionCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primaryContainer.withOpacity(0.3),
                  cs.primaryContainer.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.backpack_outlined,
                    size: 32,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Gear List',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start building your packing list!\nAdd essential hiking gear and track your progress.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Add First Item',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
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

    return _SectionCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with gradient background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withOpacity(0.15),
                    cs.primaryContainer.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.backpack_outlined,
                      color: cs.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gear List',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '$totalCount items • ${(progress * 100).round()}% ready',
                          style: GoogleFonts.lato(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: progress == 1.0
                          ? Colors.green.withOpacity(0.2)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          progress == 1.0
                              ? Icons.check_circle
                              : Icons.open_in_new,
                          size: 16,
                          color: progress == 1.0 ? Colors.green : cs.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          progress == 1.0 ? 'Complete' : 'Open',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: progress == 1.0 ? Colors.green : cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress visualization
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progress == 1.0 ? Colors.green : cs.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: progress == 1.0
                              ? Colors.green.withOpacity(0.1)
                              : cs.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$packedCount/$totalCount',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: progress == 1.0 ? Colors.green : cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Item preview
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: plan.packingList.length.clamp(0, 8),
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final item = plan.packingList[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: item.isPacked
                                ? Colors.green.withOpacity(0.1)
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.isPacked
                                  ? Colors.green.withOpacity(0.3)
                                  : cs.outlineVariant.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.isPacked
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 14,
                                color: item.isPacked
                                    ? Colors.green
                                    : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.name,
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: item.isPacked
                                      ? Colors.green
                                      : cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  if (plan.packingList.length > 8) ...[
                    const SizedBox(height: 8),
                    Text(
                      '+${plan.packingList.length - 8} more items',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodSummaryCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback onOpen;
  const _FoodSummaryCard({required this.plan, required this.onOpen});

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
    final hasFood = foodData['items']! > 0;

    return _SectionCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with gradient background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orangeAccent.withOpacity(0.2),
                    Colors.deepOrangeAccent.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasFood
                          ? Icons.restaurant_menu
                          : Icons.restaurant_outlined,
                      color: Colors.deepOrange.shade600,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Food Planner',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          hasFood
                              ? '${foodData['days']!.toInt()}/$days days planned'
                              : '$days ${days == 1 ? 'day' : 'days'} of meals to plan',
                          style: GoogleFonts.lato(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: Colors.deepOrange.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasFood ? 'Edit' : 'Plan',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.deepOrange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: hasFood
                  ? _buildMealSummary(foodData, cs)
                  : _buildEmptyState(cs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSummary(Map<String, double> foodData, ColorScheme cs) {
    final days = plan.endDate != null
        ? plan.endDate!.difference(plan.startDate).inDays + 1
        : 1;
    final plannedDays = foodData['days']!.toInt();
    final progressPercent = days > 0 ? (plannedDays / days) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress visualization (clean and simple)
        Row(
          children: [
            Expanded(
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressPercent >= 1.0
                          ? Colors.green
                          : Colors.orange.shade600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: progressPercent >= 1.0
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$plannedDays/$days days',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: progressPercent >= 1.0
                      ? Colors.green
                      : Colors.orange.shade600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade50.withOpacity(0.8),
                Colors.orange.shade100.withOpacity(0.4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200.withOpacity(0.6)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  size: 32,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Plan Your Trail Meals',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create nutritious meal plans for each day of your hike.\nTrack calories, ingredients, and portions.',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Start Planning',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================= ENHANCED WEATHER CARD =================
class _EnhancedWeatherCard extends StatefulWidget {
  final HikePlan plan;
  final VoidCallback onOpen;

  const _EnhancedWeatherCard({required this.plan, required this.onOpen});

  @override
  State<_EnhancedWeatherCard> createState() => _EnhancedWeatherCardState();
}

class _EnhancedWeatherCardState extends State<_EnhancedWeatherCard> {
  final Dio _dio = Dio();
  Future<Map<String, dynamic>?>? _weatherFuture;

  @override
  void initState() {
    super.initState();
    if (widget.plan.latitude != null && widget.plan.longitude != null) {
      _weatherFuture = _fetchWeatherPreview();
    }
  }

  Future<Map<String, dynamic>?> _fetchWeatherPreview() async {
    try {
      final lat = widget.plan.latitude!;
      final lon = widget.plan.longitude!;
      final now = DateTime.now();
      final start = widget.plan.startDate;
      final diffDays = start.difference(now).inDays;

      if (diffDays > 9) {
        // Return estimate data for far future hikes
        return await _fetchEstimateData(lat, lon, start, widget.plan.endDate);
      } else {
        // Return actual forecast data
        return await _fetchForecastData(lat, lon);
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _fetchEstimateData(
      double lat, double lon, DateTime start, DateTime? end) async {
    try {
      double avgTemp = 0, dayTemp = 0, nightTemp = 0;
      int count = 0, dayCount = 0, nightCount = 0;
      final years = [start.year - 1, start.year - 2, start.year - 3];

      for (final year in years) {
        final startStr = DateFormat('yyyy-MM-dd')
            .format(DateTime(year, start.month, start.day));
        final endStr = DateFormat('yyyy-MM-dd').format(
            DateTime(year, end?.month ?? start.month, end?.day ?? start.day));
        final url =
            'https://archive-api.open-meteo.com/v1/archive?latitude=$lat&longitude=$lon&start_date=$startStr&end_date=$endStr&daily=temperature_2m_mean,temperature_2m_max,temperature_2m_min&timezone=Europe/Helsinki';

        final response = await _dio.get(url);
        final data = response.data;
        if (data?['daily']?['temperature_2m_mean'] != null) {
          final means = List<double>.from(data['daily']['temperature_2m_mean']
              .map((v) => v?.toDouble() ?? 0.0));
          final maxs = List<double>.from(data['daily']['temperature_2m_max']
              .map((v) => v?.toDouble() ?? 0.0));
          final mins = List<double>.from(data['daily']['temperature_2m_min']
              .map((v) => v?.toDouble() ?? 0.0));
          if (means.isNotEmpty) {
            avgTemp += means.reduce((a, b) => a + b);
            count += means.length;
          }
          if (maxs.isNotEmpty) {
            dayTemp += maxs.reduce((a, b) => a + b);
            dayCount += maxs.length;
          }
          if (mins.isNotEmpty) {
            nightTemp += mins.reduce((a, b) => a + b);
            nightCount += mins.length;
          }
        }
      }

      if (count > 0) {
        return {
          'isEstimate': true,
          'avgTemp': avgTemp / count,
          'dayTemp': dayCount > 0 ? dayTemp / dayCount : null,
          'nightTemp': nightCount > 0 ? nightTemp / nightCount : null,
        };
      }
    } catch (e) {
      // Fallback estimate based on location and month
      return _getSeasonalEstimate(start);
    }
    return _getSeasonalEstimate(start);
  }

  Map<String, dynamic> _getSeasonalEstimate(DateTime date) {
    final month = date.month;
    double avgTemp, dayTemp, nightTemp;

    // Finnish seasonal estimates
    switch (month) {
      case 12:
      case 1:
      case 2: // Winter
        avgTemp = -8;
        dayTemp = -3;
        nightTemp = -15;
        break;
      case 3:
      case 4:
      case 5: // Spring
        avgTemp = month == 3 ? -2 : (month == 4 ? 5 : 12);
        dayTemp = avgTemp + 5;
        nightTemp = avgTemp - 8;
        break;
      case 6:
      case 7:
      case 8: // Summer
        avgTemp = month == 6 ? 16 : (month == 7 ? 19 : 17);
        dayTemp = avgTemp + 6;
        nightTemp = avgTemp - 6;
        break;
      case 9:
      case 10:
      case 11: // Autumn
        avgTemp = month == 9 ? 12 : (month == 10 ? 6 : 0);
        dayTemp = avgTemp + 4;
        nightTemp = avgTemp - 6;
        break;
      default:
        avgTemp = 8;
        dayTemp = 15;
        nightTemp = 2;
    }

    return {
      'isEstimate': true,
      'avgTemp': avgTemp,
      'dayTemp': dayTemp,
      'nightTemp': nightTemp,
    };
  }

  Future<Map<String, dynamic>> _fetchForecastData(
      double lat, double lon) async {
    final url =
        'https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$lat&lon=$lon';
    final response = await _dio.get(url,
        options:
            Options(headers: {'User-Agent': 'TrekNote/1.0 (your@email.com)'}));

    final timeseries = response.data['properties']?['timeseries'] as List?;
    if (timeseries == null || timeseries.isEmpty) {
      throw Exception('No forecast data available');
    }

    final now = DateTime.now();
    final currentTemp = timeseries.first['data']['instant']['details']
            ['air_temperature']
        .toDouble();
    final currentSymbol = _getSymbolCode(timeseries.first);

    final List<Map<String, dynamic>> dailyForecast = [];
    final Map<String, List<double>> dailyTemps = {};

    for (var item in timeseries.take(72)) {
      // Next 3 days
      final dt = DateTime.parse(item['time']);
      if (dt.isBefore(now)) continue;

      final dayKey = DateFormat('yyyy-MM-dd').format(dt);
      final temp =
          item['data']['instant']['details']['air_temperature']?.toDouble();

      if (temp != null) {
        dailyTemps.putIfAbsent(dayKey, () => []).add(temp);
      }
    }

    dailyTemps.forEach((dayKey, temps) {
      final day = DateTime.parse(dayKey);
      final high = temps.reduce((a, b) => a > b ? a : b);
      final low = temps.reduce((a, b) => a < b ? a : b);
      dailyForecast.add({
        'date': day,
        'high': high,
        'low': low,
        'dayName': DateFormat('EEEE').format(day),
      });
    });

    dailyForecast.sort((a, b) => a['date'].compareTo(b['date']));

    return {
      'isEstimate': false,
      'currentTemp': currentTemp,
      'currentSymbol': currentSymbol,
      'dailyForecast': dailyForecast.take(5).toList(),
    };
  }

  String _getSymbolCode(Map<String, dynamic> item) {
    return item['data']?['next_1_hours']?['summary']?['symbol_code'] ??
        item['data']?['next_6_hours']?['summary']?['symbol_code'] ??
        item['data']?['next_12_hours']?['summary']?['symbol_code'] ??
        'clearsky_day';
  }

  IconData _getWeatherIcon(String symbolCode) {
    final code = symbolCode.toLowerCase();
    if (code.contains('sun') || code.contains('clearsky_day'))
      return Icons.wb_sunny;
    if (code.contains('clearsky_night')) return Icons.nights_stay;
    if (code.contains('partlycloudy')) return Icons.wb_cloudy;
    if (code.contains('cloudy')) return Icons.cloud;
    if (code.contains('rain')) return Icons.water_drop;
    if (code.contains('snow')) return Icons.ac_unit;
    if (code.contains('thunder')) return Icons.flash_on;
    if (code.contains('fog')) return Icons.foggy;
    return Icons.wb_cloudy;
  }

  Color _getTempColor(double temp) {
    if (temp >= 20) return Colors.orange.shade600;
    if (temp >= 10) return Colors.green.shade600;
    if (temp >= 0) return Colors.blue.shade600;
    return Colors.indigo.shade600;
  }

  String _getEstimateDescription(
      double avgTemp, double? dayTemp, double? nightTemp) {
    final tempDesc = avgTemp >= 15
        ? "pleasant"
        : avgTemp >= 5
            ? "cool"
            : avgTemp >= -5
                ? "cold"
                : "very cold";

    final dayNightDesc = dayTemp != null && nightTemp != null
        ? " Expect around ${dayTemp.round()}°C during the day and ${nightTemp.round()}°C at night."
        : "";

    final advice = avgTemp < 0
        ? " Pack warm layers and winter gear."
        : avgTemp < 10
            ? " Bring warm clothing for chilly conditions."
            : " Comfortable hiking weather expected.";

    return "Typically $tempDesc weather for this time of year.$dayNightDesc$advice";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (widget.plan.latitude == null || widget.plan.longitude == null) {
      return _SectionCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: const Text(
                      'Weather forecast requires location coordinates.'),
                  backgroundColor: AppColors.errorColor(context)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.location_off, color: cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weather Forecast',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Location needed for weather data',
                          style: GoogleFonts.lato(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
    }

    return _SectionCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onOpen,
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _weatherFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Loading weather forecast...',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data;
            if (data == null) {
              return _buildErrorCard(cs);
            }

            if (data['isEstimate'] == true) {
              return _buildEstimateCard(data, cs);
            } else {
              return _buildForecastCard(data, cs);
            }
          },
        ),
      ),
    );
  }

  Widget _buildErrorCard(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Weather Forecast',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                Text('Unable to load weather data',
                    style: GoogleFonts.lato(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildEstimateCard(Map<String, dynamic> data, ColorScheme cs) {
    final avgTemp = data['avgTemp'] as double;
    final dayTemp = data['dayTemp'] as double?;
    final nightTemp = data['nightTemp'] as double?;
    final tempColor = _getTempColor(avgTemp);
    final description = _getEstimateDescription(avgTemp, dayTemp, nightTemp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tempColor.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: tempColor.withOpacity(0.2),
                child: Icon(Icons.history_toggle_off, color: tempColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weather Estimate',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('${avgTemp.round()}°C average',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 24,
                            color: tempColor)),
                  ],
                ),
              ),
              if (dayTemp != null && nightTemp != null) ...[
                Column(
                  children: [
                    Text('${dayTemp.round()}°',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, color: tempColor)),
                    Text('Day',
                        style: GoogleFonts.lato(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    Text('${nightTemp.round()}°',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, color: tempColor)),
                    Text('Night',
                        style: GoogleFonts.lato(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description,
                  style: GoogleFonts.lato(height: 1.4, color: cs.onSurface)),
              const SizedBox(height: 8),
              Text('Exact forecast available 10 days before hike',
                  style: GoogleFonts.lato(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForecastCard(Map<String, dynamic> data, ColorScheme cs) {
    final currentTemp = data['currentTemp'] as double;
    final currentSymbol = data['currentSymbol'] as String;
    final dailyForecast = data['dailyForecast'] as List<Map<String, dynamic>>;
    final tempColor = _getTempColor(currentTemp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tempColor.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: tempColor.withOpacity(0.2),
                child: Icon(_getWeatherIcon(currentSymbol), color: tempColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Weather',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('${currentTemp.round()}°C',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 24,
                            color: tempColor)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
        if (dailyForecast.isNotEmpty)
          Container(
            height: 72,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: dailyForecast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final day = dailyForecast[i];
                final isToday = i == 0;
                final dayName = isToday
                    ? 'Today'
                    : day['dayName'].toString().substring(0, 3);
                final high = (day['high'] as double).round();
                final low = (day['low'] as double).round();

                return Container(
                  width: 64,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isToday
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(dayName,
                          style: GoogleFonts.lato(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? cs.onPrimaryContainer
                                  : cs.onSurface)),
                      const SizedBox(height: 3),
                      Text('$high°',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? cs.onPrimaryContainer
                                  : cs.onSurface)),
                      Text('$low°',
                          style: GoogleFonts.lato(
                              fontSize: 11,
                              color: isToday
                                  ? cs.onPrimaryContainer.withOpacity(0.7)
                                  : cs.onSurfaceVariant)),
                    ],
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text('Tap for detailed forecast',
              style: GoogleFonts.lato(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic)),
        ),
      ],
    );
  }
}

// ================= COLLABORATORS =================
class _CollaboratorsSection extends StatelessWidget {
  final List<_Participant> participants;
  final VoidCallback onInvite;
  const _CollaboratorsSection(
      {required this.participants, required this.onInvite});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.group_outlined, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Group & collaborators',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 16))),
            TextButton.icon(
                onPressed: onInvite,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Invite')),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100, // Increased height to prevent overflow
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8), // Better padding
            itemCount: participants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final p = participants[i];
              return SizedBox(
                width: 72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: cs.surfaceContainerHighest,
                      backgroundImage:
                          (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                              ? NetworkImage(p.avatarUrl!)
                              : null,
                      child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 20)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        p.name.split(' ').first,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lato(fontSize: 12, height: 1.2),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        )
      ],
    );
  }
}

class _Participant {
  final String uid;
  final String name;
  final String? avatarUrl;
  _Participant({required this.uid, required this.name, this.avatarUrl});
}

class _EmptyCollabState extends StatelessWidget {
  final VoidCallback onInvite;
  const _EmptyCollabState({required this.onInvite});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest, shape: BoxShape.circle),
              child: Icon(Icons.group_add_rounded,
                  size: 48, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text('No collaborators yet',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 6),
            Text('Invite friends and start planning together.',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: onInvite,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Invite friends')),
          ],
        ),
      ),
    );
  }
}
