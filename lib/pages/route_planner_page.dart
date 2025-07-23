// lib/pages/route_planner_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/hike_plan_model.dart';
import '../models/daily_route_model.dart';
import '../services/hike_plan_service.dart';
import 'map_editing_page.dart'; // Uusi sivu, jonka luomme seuraavaksi

// Siirretään RouteSummary tänne, jotta molemmat sivut voivat käyttää sitä
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

class RoutePlannerPage extends StatefulWidget {
  final HikePlan plan;
  const RoutePlannerPage({super.key, required this.plan});

  @override
  State<RoutePlannerPage> createState() => _RoutePlannerPageState();
}

class _RoutePlannerPageState extends State<RoutePlannerPage> {
  final HikePlanService _hikePlanService = HikePlanService();
  late List<DailyRoute> _dailyRoutes;
  late List<TextEditingController> _notesControllers;
  bool _isLoading = false;

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
    // Varmistetaan, että reittejä on oikea määrä
    if (_dailyRoutes.length < numberOfDays) {
      for (int i = _dailyRoutes.length; i < numberOfDays; i++) {
        _dailyRoutes.add(DailyRoute(dayIndex: i, points: []));
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
    for (var controller in _notesControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _savePlan() async {
    setState(() => _isLoading = true);

    // Päivitetään muistiinpanot controllereista malleihin ennen tallennusta
    for (int i = 0; i < _dailyRoutes.length; i++) {
      _dailyRoutes[i].notes = _notesControllers[i].text;
    }

    try {
      final updatedPlan = widget.plan.copyWith(dailyRoutes: _dailyRoutes);
      await _hikePlanService.updateHikePlan(updatedPlan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToMapEditor(int dayIndex) async {
    final DailyRoute currentRoute = _dailyRoutes[dayIndex];

    // Navigoidaan karttaeditoriin ja odotetaan tulosta
    final result = await Navigator.of(context).push<DailyRoute>(
      MaterialPageRoute(
        builder: (context) => MapEditingPage(initialRoute: currentRoute),
      ),
    );

    // Jos karttaeditorista palattiin ja saatiin päivitetty reitti, päivitetään tila
    if (result != null) {
      setState(() {
        _dailyRoutes[dayIndex] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.hikeName,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save Plan',
            onPressed: _isLoading ? null : _savePlan,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _dailyRoutes.length,
        itemBuilder: (context, index) {
          final dayRoute = _dailyRoutes[index];
          return _buildDayCard(context, dayRoute, index);
        },
      ),
    );
  }

  Widget _buildDayCard(BuildContext context, DailyRoute dayRoute, int index) {
    final theme = Theme.of(context);

    String formatDistance(double meters) {
      if (meters == 0) return '0 km';
      if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }

    String formatDuration(double seconds) {
      if (seconds == 0) return '0 min';
      final d = Duration(seconds: seconds.round());
      if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
      return '${d.inMinutes}m';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ExpansionTile(
        title: Text('Day ${index + 1}',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${formatDistance(dayRoute.summary.distance)} · ${formatDuration(dayRoute.summary.duration)}',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.secondary),
        ),
        childrenPadding: const EdgeInsets.all(12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Karttaesikatselu
          GestureDetector(
            onTap: () => _navigateToMapEditor(index),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(12)),
                child: AbsorbPointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: dayRoute.points.isNotEmpty
                          ? dayRoute.points.first
                          : LatLng(65, 25.5),
                      initialZoom: 10,
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
                              points: dayRoute.points,
                              strokeWidth: 5,
                              color: theme.colorScheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Muistiinpanot
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
              _dailyRoutes[index].notes =
                  text; // Päivitetään heti kun kirjoitetaan
            },
          ),
          const SizedBox(height: 16),
          // Tarkemmat tilastot
          _buildStatsRow(dayRoute.summary),
        ],
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
