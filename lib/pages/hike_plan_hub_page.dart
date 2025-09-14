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

  void _openPacking() {
    GoRouter.of(context).pushNamed('packingListPage',
        pathParameters: {'planId': _plan.id}, extra: _plan);
  }

  void _openFood() {
    context.pushNamed('foodPlannerPage',
        pathParameters: {'planId': _plan.id}, extra: _plan);
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

          if (_hasRoute || _hasLocation)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
                child: _GearSummaryCard(plan: _plan, onOpen: _openPacking)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
                child: _FoodSummaryCard(plan: _plan, onOpen: _openFood)),
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

class _DifficultyPill extends StatelessWidget {
  final HikeDifficulty difficulty;
  const _DifficultyPill({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final color = difficulty.getColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            difficulty.toShortString(),
            style: GoogleFonts.lato(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  _QuickAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.color});
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: action.onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
          color: Colors.white.withOpacity(0.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
                radius: 14,
                backgroundColor: action.color.withOpacity(0.15),
                child: Icon(action.icon, color: action.color, size: 16)),
            const SizedBox(width: 8),
            Text(action.label,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _PrepChip extends StatelessWidget {
  final String label;
  final bool done;
  const _PrepChip({required this.label, required this.done});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done ? cs.primary.withOpacity(0.12) : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: (done ? cs.primary : cs.outlineVariant).withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 16, color: done ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.lato(
                  fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ================= STATS =================
class _StatsGrid extends StatelessWidget {
  final String distance;
  final int days;
  final HikeDifficulty difficulty;
  final HikeStatus status;
  const _StatsGrid(
      {required this.distance,
      required this.days,
      required this.difficulty,
      required this.status});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          Expanded(
              child: _StatTile(
                  icon: Icons.route_outlined,
                  label: 'Distance',
                  value: distance)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Days',
                  value: '$days')),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  icon: Icons.fitness_center_rounded,
                  label: 'Difficulty',
                  value: difficulty.toShortString(),
                  color: difficulty.getColor(context))),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _StatTile(
      {required this.icon,
      required this.label,
      required this.value,
      this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                  radius: 16,
                  backgroundColor: (color ?? cs.primary).withOpacity(0.12),
                  child: Icon(icon, color: color ?? cs.primary, size: 18)),
              const Spacer(),
              Text(label,
                  style: GoogleFonts.lato(
                      color: cs.onSurfaceVariant,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700))
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800, fontSize: 16)),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(top: 12.0), // Added top padding here
      child: _SectionCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Route preview',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  TextButton.icon(
                      onPressed: onOpenPlanner,
                      icon: const Icon(Icons.fullscreen_rounded),
                      label: const Text('Open Planner')),
                ],
              ),
            ),
          ],
        ),
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

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Gear list',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 16))),
              TextButton(onPressed: onOpen, child: const Text('Open')),
            ],
          ),
          const SizedBox(height: 6),
          if (totalCount == 0)
            Text('No items yet. Start adding gear in the Gear list.',
                style: GoogleFonts.lato(color: cs.onSurfaceVariant))
          else ...[
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: plan.packingList.length.clamp(0, 12),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) =>
                    _ChipPill(text: plan.packingList[i].name),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: totalCount == 0 ? 0 : packedCount / totalCount,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text('$packedCount/$totalCount packed',
                style:
                    GoogleFonts.lato(color: cs.onSurfaceVariant, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _FoodSummaryCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback onOpen;
  const _FoodSummaryCard({required this.plan, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_menu_outlined,
                  color: Colors.orangeAccent.shade200),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Food planner',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 16))),
              TextButton(onPressed: onOpen, child: const Text('Open')),
            ],
          ),
          const SizedBox(height: 6),
          Text('Plan meals, share responsibilities, and balance weights.',
              style: GoogleFonts.lato(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  final String text;
  const _ChipPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.drag_indicator_rounded, size: 16),
          const SizedBox(width: 6),
          Text(text,
              style: GoogleFonts.lato(
                  fontWeight: FontWeight.w700, fontSize: 13.5)),
        ],
      ),
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
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: participants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final p = participants[i];
              return Column(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: cs.surfaceContainerHighest,
                    backgroundImage:
                        (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                            ? NetworkImage(p.avatarUrl!)
                            : null,
                    child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                      width: 76,
                      child: Text(p.name.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(fontSize: 12.5)))
                ],
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
