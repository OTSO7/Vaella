// lib/pages/route_planner_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/hike_plan_model.dart';
import '../models/daily_route_model.dart';
import '../services/hike_plan_service.dart';
import 'map_editing_page.dart';

// ... (RouteSummary-luokka ja kRouteColors-lista pysyvät ennallaan)
class RouteSummary {
  final double distance;
  final double duration;
  final double ascent;
  final double descent;
  RouteSummary({
    this.distance = 0.0,
    this.duration = 0.0,
    this.ascent = 0.0,
    this.descent = 0.0,
  });
  RouteSummary operator +(RouteSummary other) {
    return RouteSummary(
      distance: distance + other.distance,
      duration: duration + other.duration,
      ascent: ascent + other.ascent,
      descent: descent + other.descent,
    );
  }
}

const List<Color> kRouteColors = [
  Colors.blue,
  Colors.green,
  Colors.purple,
  Colors.orange,
  Colors.red,
  Colors.teal,
  Colors.pink,
  Colors.indigo,
  Colors.amber,
  Colors.cyan,
];

class RoutePlannerPage extends StatefulWidget {
  final HikePlan plan;
  const RoutePlannerPage({super.key, required this.plan});

  @override
  State<RoutePlannerPage> createState() => _RoutePlannerPageState();
}

class _RoutePlannerPageState extends State<RoutePlannerPage> {
  // ... (Luokan alkuosa pysyy ennallaan)
  final HikePlanService _hikePlanService = HikePlanService();
  late List<DailyRoute> _dailyRoutes;
  late List<TextEditingController> _notesControllers;
  @override
  void initState() {
    super.initState();
    _initializeRoutesAndControllers();
  }

  void _initializeRoutesAndControllers() {
    int numberOfDays =
        (widget.plan.endDate?.difference(widget.plan.startDate).inDays ?? 0) +
            1;
    if (numberOfDays <= 0) numberOfDays = 1;
    _dailyRoutes = List.from(widget.plan.dailyRoutes);
    if (_dailyRoutes.length < numberOfDays) {
      for (int i = _dailyRoutes.length; i < numberOfDays; i++) {
        _dailyRoutes.add(DailyRoute(
          dayIndex: i,
          points: [],
          colorValue: kRouteColors[i % kRouteColors.length].value,
        ));
      }
    } else if (_dailyRoutes.length > numberOfDays) {
      _dailyRoutes = _dailyRoutes.sublist(0, numberOfDays);
    }
    _notesControllers = _dailyRoutes
        .map((route) => TextEditingController(text: route.notes))
        .toList();
  }

  @override
  void dispose() {
    _savePlanOnExit();
    for (var controller in _notesControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _savePlanOnExit() async {
    for (int i = 0; i < _dailyRoutes.length; i++) {
      _dailyRoutes[i].notes = _notesControllers[i].text;
    }
    final originalRoutesJson = jsonEncode(
        widget.plan.dailyRoutes.map((r) => r.toFirestore()).toList());
    final newRoutesJson =
        jsonEncode(_dailyRoutes.map((r) => r.toFirestore()).toList());
    if (originalRoutesJson == newRoutesJson) {
      print("No changes detected in routes, skipping save.");
      return;
    }
    try {
      print("Changes detected, auto-saving plan...");
      final updatedPlan = widget.plan.copyWith(dailyRoutes: _dailyRoutes);
      await _hikePlanService.updateHikePlan(updatedPlan);
    } catch (e) {
      print("Error auto-saving plan on exit: $e");
    }
  }

  Future<void> _navigateToMapEditor(int dayIndex) async {
    final result = await Navigator.of(context).push<List<DailyRoute>>(
      MaterialPageRoute(
        builder: (context) => MapEditingPage(
          allDailyRoutes: _dailyRoutes,
          editingDayIndex: dayIndex,
          planLocation:
              (widget.plan.latitude != null && widget.plan.longitude != null)
                  ? LatLng(widget.plan.latitude!, widget.plan.longitude!)
                  : null,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _dailyRoutes = result;
      });
    }
  }

  // Apufunktiot matkan ja keston muotoiluun, jotka ovat nyt helposti uudelleenkäytettävissä
  String _formatDistance(double meters) {
    if (meters == 0) return '0 km';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(double seconds) {
    if (seconds == 0) return '0 min';
    final d = Duration(seconds: seconds.round());
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    // MUUTOS: Lasketaan kokonaisyhteenveto tässä, jotta se on käytettävissä build-metodissa
    final totalSummary =
        _dailyRoutes.fold(RouteSummary(), (sum, route) => sum + route.summary);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.hikeName,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
        itemCount: _dailyRoutes.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // MUUTOS: Annetaan kokonaisyhteenveto yleiskatsaus-widgetille
            return _buildOverviewSection(context, totalSummary);
          }
          final dayIndex = index - 1;
          final dayRoute = _dailyRoutes[dayIndex];
          return _buildDayCard(context, dayRoute, dayIndex);
        },
      ),
    );
  }

  // MUUTOS: Tämä on nyt oma osionsa, joka sisältää sekä kartan että yhteenvetokortin
  Widget _buildOverviewSection(
      BuildContext context, RouteSummary totalSummary) {
    final allPoints = _dailyRoutes.expand((route) => route.points).toList();

    return Column(
      children: [
        _buildOverviewMap(context, allPoints),
        // LISÄTTY: Näytetään yhteenvetokortti, jos reittiä on suunniteltu
        if (allPoints.isNotEmpty) _buildTotalSummaryCard(context, totalSummary),
      ],
    );
  }

  // LISÄTTY: Koko uusi metodi yhteenvetokortin rakentamiseen
  Widget _buildTotalSummaryCard(BuildContext context, RouteSummary summary) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTotalStatItem(Icons.route_outlined,
                    _formatDistance(summary.distance), 'Distance'),
                _buildTotalStatItem(Icons.timer_outlined,
                    _formatDuration(summary.duration), 'Duration'),
                _buildTotalStatItem(Icons.arrow_upward_rounded,
                    '${summary.ascent.toStringAsFixed(0)} m', 'Ascent'),
                _buildTotalStatItem(Icons.arrow_downward_rounded,
                    '${summary.descent.toStringAsFixed(0)} m', 'Descent'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // LISÄTTY: Apumetodi yksittäiselle tilastolle yhteenvetokortissa
  Widget _buildTotalStatItem(IconData icon, String value, String label) {
    final theme = Theme.of(context);
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 28),
          const SizedBox(height: 6),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildOverviewMap(BuildContext context, List<LatLng> allPoints) {
    if (allPoints.isEmpty) {
      return _buildMapPlaceholder(context);
    }
    // ... (tämä metodi pysyy muuten ennallaan)
    final List<Marker> endpointMarkers = [];
    for (final route in _dailyRoutes) {
      if (route.points.isNotEmpty) {
        endpointMarkers.add(Marker(
          point: route.points.first,
          width: 12,
          height: 12,
          child:
              _buildRouteEndpointMarker(color: route.routeColor, isStart: true),
        ));
        if (route.points.length > 1) {
          endpointMarkers.add(Marker(
            point: route.points.last,
            width: 12,
            height: 12,
            child: _buildRouteEndpointMarker(
                color: route.routeColor, isStart: false),
          ));
        }
      }
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(allPoints),
              padding: const EdgeInsets.all(40.0),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
            ),
            PolylineLayer(
              polylines: _dailyRoutes.map((route) {
                return Polyline(
                  points: route.points,
                  strokeWidth: 5,
                  color: route.routeColor.withOpacity(0.8),
                );
              }).toList(),
            ),
            MarkerLayer(markers: endpointMarkers),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(BuildContext context, DailyRoute dayRoute, int index) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ExpansionTile(
        title: Text('Day ${index + 1}',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Builder(
          builder: (context) {
            bool isRoutePlanned = dayRoute.summary.distance > 0;
            bool canContinue = index > 0 &&
                !isRoutePlanned &&
                _dailyRoutes[index - 1].points.isNotEmpty;
            if (isRoutePlanned) {
              return Text(
                '${_formatDistance(dayRoute.summary.distance)} · ${_formatDuration(dayRoute.summary.duration)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.secondary),
              );
            } else if (canContinue) {
              return Text('Starts from Day ${index} endpoint',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontStyle: FontStyle.italic));
            } else {
              return Text('Plan your route',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant));
            }
          },
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMapPreviewContainer(context, dayRoute, index),
          const SizedBox(height: 16),
          _buildColorSelector(context, dayRoute, index),
          const SizedBox(height: 16),
          Text('Notes for Day ${index + 1}',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesControllers[index],
            decoration: InputDecoration(
              hintText: 'E.g., Parking location, water sources, huts...',
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            maxLines: 3,
            onChanged: (text) {
              _dailyRoutes[index].notes = text;
            },
          ),
          const SizedBox(height: 16),
          _buildStatsRow(dayRoute.summary),
        ],
      ),
    );
  }

  // ... (muut apuwidgetit pysyvät ennallaan)
  Widget _buildRouteEndpointMarker(
      {required Color color, bool isStart = false}) {
    return Container(
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isStart ? Colors.white : color,
          border: Border.all(color: color, width: 2.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)
          ]),
    );
  }

  Widget _buildMapPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined,
                  size: 50, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                'Your Adventure Overview',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Plan a route below to see it here',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorSelector(
      BuildContext context, DailyRoute dayRoute, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Route Color', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kRouteColors.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, colorIndex) {
              final color = kRouteColors[colorIndex];
              final isSelected = dayRoute.colorValue == color.value;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _dailyRoutes[index].colorValue = color.value;
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3)
                        : Border.all(
                            color: Theme.of(context).dividerColor, width: 1.5),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMapPreviewContainer(
      BuildContext context, DailyRoute dayRoute, int index) {
    final theme = Theme.of(context);
    final LatLng? planLocation =
        (widget.plan.latitude != null && widget.plan.longitude != null)
            ? LatLng(widget.plan.latitude!, widget.plan.longitude!)
            : null;
    return GestureDetector(
      onTap: () => _navigateToMapEditor(index),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor)),
          child: _RoutePreviewMap(
            dayRoute: dayRoute,
            planLocation: planLocation,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(RouteSummary summary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(Icons.arrow_upward,
            '${summary.ascent.toStringAsFixed(0)} m', 'Ascent'),
        _buildStatItem(Icons.arrow_downward,
            '${summary.descent.toStringAsFixed(0)} m', 'Descent'),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _RoutePreviewMap extends StatefulWidget {
  final DailyRoute dayRoute;
  final LatLng? planLocation;
  const _RoutePreviewMap({required this.dayRoute, this.planLocation});
  @override
  State<_RoutePreviewMap> createState() => _RoutePreviewMapState();
}

class _RoutePreviewMapState extends State<_RoutePreviewMap> {
  final MapController _mapController = MapController();
  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitMapToRoute() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      final dayRoute = widget.dayRoute;
      if (dayRoute.points.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(dayRoute.points),
            padding: const EdgeInsets.all(25.0),
          ),
        );
      } else if (widget.planLocation != null) {
        _mapController.move(widget.planLocation!, 10.0);
      }
    });
  }

  Widget _buildRouteEndpointMarker(
      {required Color color, bool isStart = false}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isStart ? Colors.white : color,
        border: Border.all(color: color, width: 2.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: widget.planLocation ?? const LatLng(65, 25.5),
          initialZoom: 5,
          onMapReady: _fitMapToRoute,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                  points: widget.dayRoute.points,
                  strokeWidth: 5,
                  color: widget.dayRoute.routeColor),
            ],
          ),
          if (widget.dayRoute.points.isNotEmpty)
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.dayRoute.points.first,
                  width: 10,
                  height: 10,
                  child: _buildRouteEndpointMarker(
                      color: widget.dayRoute.routeColor, isStart: true),
                ),
                if (widget.dayRoute.points.length > 1)
                  Marker(
                    point: widget.dayRoute.points.last,
                    width: 10,
                    height: 10,
                    child: _buildRouteEndpointMarker(
                        color: widget.dayRoute.routeColor, isStart: false),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
