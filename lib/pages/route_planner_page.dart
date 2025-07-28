import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/daily_route_model.dart';
import '../providers/route_planner_provider.dart';
import '../utils/map_helpers.dart';
import 'map_editing_page.dart';

enum _ExitAction { save, discard, cancel }

// Esimerkkivärit reiteille, voit muokata näitä
const List<Color> kRouteColors = [
  Colors.blue,
  Colors.red,
  Colors.green,
  Colors.purple,
  Colors.orange,
  Colors.teal,
  Colors.pink,
  Colors.amber,
];

class RoutePlannerPage extends StatefulWidget {
  const RoutePlannerPage({super.key});

  @override
  State<RoutePlannerPage> createState() => _RoutePlannerPageState();
}

class _RoutePlannerPageState extends State<RoutePlannerPage> {
  late List<TextEditingController> _notesControllers;
  late RoutePlannerProvider _plannerProvider;

  @override
  void initState() {
    super.initState();
    _plannerProvider = context.read<RoutePlannerProvider>();
    _initializeNotesControllers();
    _plannerProvider.addListener(_onProviderUpdate);
  }

  void _onProviderUpdate() {
    if (_notesControllers.length != _plannerProvider.plan.dailyRoutes.length) {
      _disposeControllers();
      _initializeNotesControllers();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _initializeNotesControllers() {
    _notesControllers = _plannerProvider.plan.dailyRoutes
        .map((route) => TextEditingController(text: route.notes))
        .toList();
  }

  void _disposeControllers() {
    for (var controller in _notesControllers) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _plannerProvider.removeListener(_onProviderUpdate);
    _disposeControllers();
    super.dispose();
  }

  Future<void> _navigateToMapEditor(int dayIndex) async {
    final provider = context.read<RoutePlannerProvider>();
    final result = await Navigator.of(context).push<List<DailyRoute>>(
      MaterialPageRoute(
        builder: (context) => MapEditingPage(
          allDailyRoutes: provider.plan.dailyRoutes,
          editingDayIndex: dayIndex,
          planLocation: (provider.plan.latitude != null &&
                  provider.plan.longitude != null)
              ? LatLng(provider.plan.latitude!, provider.plan.longitude!)
              : null,
        ),
      ),
    );

    if (result != null && mounted) {
      context.read<RoutePlannerProvider>().updateRoutes(result);
    }
  }

  Future<_ExitAction?> _showUnsavedChangesDialog() {
    return showDialog<_ExitAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Do you want to save your changes before exiting?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(_ExitAction.cancel),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(_ExitAction.discard),
              child: const Text('Discard')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(_ExitAction.save),
              child: const Text('Save')),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(double seconds) {
    final d = Duration(seconds: seconds.round());
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoutePlannerProvider>(
      builder: (context, provider, child) {
        final plan = provider.plan;
        final totalSummary = plan.dailyRoutes
            .fold(RouteSummary(), (sum, route) => sum + route.summary);

        return PopScope(
          canPop: !provider.hasChanges,
          onPopInvoked: (didPop) async {
            if (didPop) return;

            final action = await _showUnsavedChangesDialog();

            if (action == _ExitAction.save) {
              final success = await provider.saveChanges();
              if (success && mounted) Navigator.of(context).pop();
            } else if (action == _ExitAction.discard) {
              if (mounted) Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(plan.hikeName,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
            floatingActionButton: Visibility(
              visible: provider.hasChanges,
              child: FloatingActionButton.extended(
                onPressed: provider.isSaving
                    ? null
                    : () async {
                        final success = await provider.saveChanges();
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Plan saved!'),
                                backgroundColor: Colors.green),
                          );
                        }
                      },
                label: provider.isSaving
                    ? const Text('Saving...')
                    : const Text('Save Changes'),
                icon: provider.isSaving
                    ? Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ))
                    : const Icon(Icons.save_alt_rounded),
              ),
            ),
            body: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
              itemCount: plan.dailyRoutes.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildOverviewSection(
                      context, plan.dailyRoutes, totalSummary);
                }
                final dayIndex = index - 1;
                final dayRoute = plan.dailyRoutes[dayIndex];
                return _buildDayCard(context, dayRoute, dayIndex);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewSection(BuildContext context,
      List<DailyRoute> dailyRoutes, RouteSummary totalSummary) {
    final allPoints = dailyRoutes.expand((route) => route.points).toList();
    return Column(
      children: [
        _buildOverviewMap(context, dailyRoutes, allPoints),
        if (allPoints.isNotEmpty) _buildTotalSummaryCard(context, totalSummary),
      ],
    );
  }

  Widget _buildDayCard(
      BuildContext context, DailyRoute dayRoute, int dayIndex) {
    final theme = Theme.of(context);
    final provider = context.read<RoutePlannerProvider>();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ExpansionTile(
        title: Text('Day ${dayIndex + 1}',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Builder(builder: (context) {
          bool isRoutePlanned = dayRoute.summary.distance > 0;
          return Text(
            isRoutePlanned
                ? '${_formatDistance(dayRoute.summary.distance)} · ${_formatDuration(dayRoute.summary.duration)}'
                : 'Plan your route',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isRoutePlanned
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          );
        }),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMapPreviewContainer(context, dayRoute, dayIndex),
          const SizedBox(height: 16),
          _buildColorSelector(context, dayRoute, dayIndex),
          const SizedBox(height: 16),
          Text('Notes for Day ${dayIndex + 1}',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesControllers[dayIndex],
            decoration: InputDecoration(
              hintText: 'E.g., Parking location, water sources, huts...',
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            maxLines: 3,
            onChanged: (text) => provider.updateNoteForDay(dayIndex, text),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector(
      BuildContext context, DailyRoute dayRoute, int dayIndex) {
    final provider = context.read<RoutePlannerProvider>();
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
                onTap: () => provider.updateColorForDay(dayIndex, color.value),
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
    final provider = context.read<RoutePlannerProvider>();
    final LatLng? planLocation =
        (provider.plan.latitude != null && provider.plan.longitude != null)
            ? LatLng(provider.plan.latitude!, provider.plan.longitude!)
            : null;

    return GestureDetector(
      onTap: () => _navigateToMapEditor(index),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: _RoutePreviewMap(
            key: ValueKey(dayRoute.points.hashCode),
            dayRoute: dayRoute,
            planLocation: planLocation,
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewMap(BuildContext context, List<DailyRoute> dailyRoutes,
      List<LatLng> allPoints) {
    if (allPoints.isEmpty) return _buildMapPlaceholder(context);

    final arrowMarkers = generateArrowMarkersForDays(dailyRoutes);

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
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.treknoteflutter',
            ),
            PolylineLayer(
              polylines: dailyRoutes.map((route) {
                return Polyline(
                  points: route.points,
                  strokeWidth: 5.0,
                  color: route.routeColor.withOpacity(0.8),
                  borderColor: Colors.black.withOpacity(0.2),
                  borderStrokeWidth: 1.0,
                );
              }).toList(),
            ),
            MarkerLayer(markers: arrowMarkers),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  '© OpenStreetMap contributors',
                  onTap: () => launchUrl(
                      Uri.parse('https://openstreetmap.org/copyright')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSummaryCard(BuildContext context, RouteSummary summary) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
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
      ),
    );
  }

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
              Text('Your Adventure Overview',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Plan a route below to see an overview',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutePreviewMap extends StatefulWidget {
  final DailyRoute dayRoute;
  final LatLng? planLocation;
  const _RoutePreviewMap(
      {super.key, required this.dayRoute, this.planLocation});

  @override
  State<_RoutePreviewMap> createState() => _RoutePreviewMapState();
}

class _RoutePreviewMapState extends State<_RoutePreviewMap> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant _RoutePreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dayRoute.points != oldWidget.dayRoute.points) {
      _fitMapToRoute();
    }
  }

  void _fitMapToRoute() {
    if (!mounted) return;
    if (widget.dayRoute.points.isNotEmpty) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(widget.dayRoute.points),
          padding: const EdgeInsets.all(25.0),
        ),
      );
    } else if (widget.planLocation != null) {
      _mapController.move(widget.planLocation!, 10.0);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arrowMarkers = generateArrowMarkersForDays([widget.dayRoute]);

    return AbsorbPointer(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          // KORJATTU: Lisätään pieni viive onMapReady-kutsuun varmistamaan,
          // että kartan piirtäminen ehtii valmiiksi ennen kameran siirtoa.
          onMapReady: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _fitMapToRoute();
              }
            });
          },
          initialCenter: widget.planLocation ?? const LatLng(65, 25.5),
          initialZoom: 5,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.treknoteflutter',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.dayRoute.points,
                strokeWidth: 5.0,
                color: widget.dayRoute.routeColor.withOpacity(0.8),
                borderColor: Colors.black.withOpacity(0.2),
                borderStrokeWidth: 1.0,
              ),
            ],
          ),
          MarkerLayer(markers: arrowMarkers),
        ],
      ),
    );
  }
}
