import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/hike_plan_model.dart';
import '../models/daily_route_model.dart';
import '../providers/route_planner_provider.dart';
import '../utils/app_colors.dart';
import '../utils/map_helpers.dart';

class HikePlanHubPage extends StatefulWidget {
  final HikePlan initialPlan;
  const HikePlanHubPage({super.key, required this.initialPlan});

  @override
  State<HikePlanHubPage> createState() => _HikePlanHubPageState();
}

class _HikePlanHubPageState extends State<HikePlanHubPage> {
  late HikePlan _currentPlan;

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.initialPlan;
  }

  bool get _hasRoute =>
      _currentPlan.dailyRoutes.any((r) => r.points.isNotEmpty);
  bool get _hasPlanLocation =>
      _currentPlan.latitude != null && _currentPlan.longitude != null;

  String _smartDateRange(DateTime start, DateTime? end) {
    if (end == null ||
        (start.year == end.year &&
            start.month == end.month &&
            start.day == end.day)) {
      return DateFormat('d.M.yyyy').format(start);
    }
    final sameYear = start.year == end.year;
    final sameMonth = sameYear && start.month == end.month;

    if (sameMonth) {
      final left = DateFormat('d').format(start);
      final right = DateFormat('d.M.yyyy').format(end);
      return '$left–$right';
    } else if (sameYear) {
      final left = DateFormat('d.M').format(start);
      final right = DateFormat('d.M.yyyy').format(end);
      return '$left–$right';
    } else {
      final left = DateFormat('d.M.yyyy').format(start);
      final right = DateFormat('d.M.yyyy').format(end);
      return '$left–$right';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateRange =
        _smartDateRange(_currentPlan.startDate, _currentPlan.endDate);
    final totalDistance =
        _currentPlan.lengthKm != null && _currentPlan.lengthKm! > 0
            ? '${_currentPlan.lengthKm!.toStringAsFixed(1)} km'
            : '—';
    final daysCount = _currentPlan.dailyRoutes.length;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // Hero: koko ruudun kartta + läpinäkyvä appbar + lasi-infot
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 420,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground],
              background: _MapHero(
                hasRoute: _hasRoute,
                hasLocation: _hasPlanLocation,
                dailyRoutes: _currentPlan.dailyRoutes,
                imageUrl: _currentPlan.imageUrl,
                planCenter: _hasPlanLocation
                    ? LatLng(_currentPlan.latitude!, _currentPlan.longitude!)
                    : null,
                title: _currentPlan.hikeName,
                dateRange: dateRange,
                distanceText: totalDistance,
                daysCount: daysCount,
              ),
            ),
          ),

          // Pikanapit
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _QuickActionsSection(
                onOpenPlanner: () async {
                  context.read<RoutePlannerProvider>().loadPlan(_currentPlan);
                  await context.push('/route-planner');
                  if (!mounted) return;
                  setState(() {
                    _currentPlan = context.read<RoutePlannerProvider>().plan;
                  });
                },
                onOpenWeather: () {
                  if (_currentPlan.latitude != null &&
                      _currentPlan.longitude != null) {
                    GoRouter.of(context).pushNamed(
                      'weatherPage',
                      pathParameters: {'planId': _currentPlan.id},
                      extra: _currentPlan,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            'Sääennuste vaatii kohteen koordinaatit.'),
                        backgroundColor: AppColors.errorColor(context),
                      ),
                    );
                  }
                },
                onOpenPacking: () {
                  GoRouter.of(context).pushNamed(
                    'packingListPage',
                    pathParameters: {'planId': _currentPlan.id},
                    extra: _currentPlan,
                  );
                },
                onOpenMeals: () {
                  context.pushNamed(
                    'foodPlannerPage',
                    pathParameters: {'planId': _currentPlan.id},
                    extra: _currentPlan,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Map Hero lasi-overlaylla =====

class _MapHero extends StatelessWidget {
  final bool hasRoute;
  final bool hasLocation;
  final List<DailyRoute> dailyRoutes;
  final String? imageUrl;
  final LatLng? planCenter;
  final String title;

  // Kaikki info overlayhin
  final String dateRange;
  final String distanceText;
  final int daysCount;

  const _MapHero({
    required this.hasRoute,
    required this.hasLocation,
    required this.dailyRoutes,
    required this.imageUrl,
    required this.planCenter,
    required this.title,
    required this.dateRange,
    required this.distanceText,
    required this.daysCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget content;
    if (hasRoute) {
      content = _RoutePreviewMap(daily: dailyRoutes);
    } else if (hasLocation && planCenter != null) {
      content = _LocationMapPreview(center: planCenter!);
    } else if ((imageUrl ?? '').isNotEmpty) {
      content = CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover);
    } else {
      content = Container(
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
        content,

        // Pehmeä scrim luettavuuteen
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.25, 0.7, 1],
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.10),
                    Colors.transparent,
                    Colors.black.withOpacity(0.25),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Lasi-työkalupalkki
        Positioned(
          left: 16,
          right: 16,
          top: MediaQuery.of(context).padding.top + 10,
          child: Row(
            children: [
              _GlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => context.pop(),
                tooltip: 'Takaisin',
              ),
              const Spacer(),
              _GlassIconButton(
                icon: Icons.more_horiz_rounded,
                onTap: () {
                  showMenu<String>(
                    context: context,
                    position: const RelativeRect.fromLTRB(1000, 60, 16, 0),
                    items: const [
                      PopupMenuItem(
                        value: 'invite',
                        child: Text('Kutsu mukaan'),
                      ),
                    ],
                  ).then((v) {
                    if (v == 'invite') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kutsu-ominaisuus tulossa pian'),
                        ),
                      );
                    }
                  });
                },
                tooltip: 'Lisää',
              ),
            ],
          ),
        ),

        // Pohjan lasi-info (otsikko + metat)
        Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: _GlassInfoOverlay(
            title: title,
            dateRange: dateRange,
            distanceText: distanceText,
            daysCount: daysCount,
          ),
        ),
      ],
    );
  }
}

class _GlassInfoOverlay extends StatelessWidget {
  final String title;
  final String dateRange;
  final String distanceText;
  final int daysCount;

  const _GlassInfoOverlay({
    required this.title,
    required this.dateRange,
    required this.distanceText,
    required this.daysCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Otsikko
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              // Metat
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _MetaChip(
                      icon: Icons.calendar_month_outlined, label: dateRange),
                  _MetaChip(icon: Icons.route_outlined, label: distanceText),
                  _MetaChip(icon: Icons.today_outlined, label: '$daysCount pv'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: cs.onSurface, size: 20),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

// ===== Meta chip =====

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Pikanapit =====

class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onOpenPlanner;
  final VoidCallback onOpenWeather;
  final VoidCallback onOpenPacking;
  final VoidCallback onOpenMeals;

  const _QuickActionsSection({
    required this.onOpenPlanner,
    required this.onOpenWeather,
    required this.onOpenPacking,
    required this.onOpenMeals,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_QuickAction>[
      _QuickAction(
        icon: Icons.map_outlined,
        title: 'Route planner',
        subtitle: 'Plan your routes and days',
        color: Colors.lightBlueAccent.shade200,
        onTap: onOpenPlanner,
      ),
      _QuickAction(
        icon: Icons.wb_sunny_outlined,
        title: 'Weather',
        subtitle: 'Forecast and conditions',
        color: Colors.orangeAccent.shade200,
        onTap: onOpenWeather,
      ),
      _QuickAction(
        icon: Icons.backpack_outlined,
        title: 'Gear list',
        subtitle: 'Stay organized',
        color: Colors.lightGreenAccent.shade400,
        onTap: onOpenPacking,
      ),
      _QuickAction(
        icon: Icons.restaurant_menu_outlined,
        title: 'Food planner',
        subtitle: 'Plan your meals',
        color: Colors.purpleAccent.shade200,
        onTap: onOpenMeals,
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.22,
      ),
      itemBuilder: (context, i) => _QuickActionTile(item: items[i]),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction item;
  const _QuickActionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cs.surface, cs.surfaceContainerHighest.withOpacity(0.6)],
            ),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: item.color.withOpacity(0.18),
                  child: Icon(item.icon, color: item.color),
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(
                    fontSize: 13.2,
                    color: cs.onSurfaceVariant,
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

// ===== Karttaesikatselut =====

class _RoutePreviewMap extends StatelessWidget {
  final List<DailyRoute> daily;
  const _RoutePreviewMap({required this.daily});

  @override
  Widget build(BuildContext context) {
    final allPoints = daily.expand((r) => r.points).toList();
    final bounds =
        allPoints.isNotEmpty ? LatLngBounds.fromPoints(allPoints) : null;
    final arrows = generateArrowMarkersForDays(daily);

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: bounds != null
            ? CameraFit.bounds(
                bounds: bounds, padding: const EdgeInsets.all(48))
            : const CameraFit.coordinates(
                coordinates: [LatLng(65, 25)],
                minZoom: 5,
              ),
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
          polylines: daily
              .where((r) => r.points.isNotEmpty)
              .map((r) => Polyline(
                    points: r.points,
                    color: r.routeColor.withOpacity(0.96),
                    strokeWidth: 5,
                    borderColor: Colors.black.withOpacity(0.22),
                    borderStrokeWidth: 1.2,
                  ))
              .toList(),
        ),
        if (arrows.isNotEmpty) MarkerLayer(markers: arrows),
      ],
    );
  }
}

class _LocationMapPreview extends StatelessWidget {
  final LatLng center;
  const _LocationMapPreview({required this.center});

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
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
        MarkerLayer(markers: [
          Marker(
            point: center,
            width: 38,
            height: 38,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.place, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ],
    );
  }
}
