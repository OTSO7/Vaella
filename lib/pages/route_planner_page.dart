import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

import '../models/hike_plan_model.dart';
import '../models/daily_route_model.dart';
import '../services/hike_plan_service.dart';

class RoutePlannerPage extends StatefulWidget {
  final HikePlan plan;

  const RoutePlannerPage({super.key, required this.plan});

  @override
  State<RoutePlannerPage> createState() => _RoutePlannerPageState();
}

class _RoutePlannerPageState extends State<RoutePlannerPage> {
  final HikePlanService _hikePlanService = HikePlanService();
  final MapController _mapController = MapController();

  late List<DailyRoute> _dailyRoutes;
  late int _selectedDayIndex;
  late List<bool> _daySelections;
  int _numberOfDays = 1;
  bool _isLoading = false;

  // TÄRKEÄÄ: Hanki API-avain osoitteesta https://openrouteservice.org/
  final String _orsApiKey = 'YOUR_OPENROUTESERVICE_API_KEY';

  @override
  void initState() {
    super.initState();

    if (widget.plan.endDate != null) {
      _numberOfDays =
          widget.plan.endDate!.difference(widget.plan.startDate).inDays + 1;
    }
    if (_numberOfDays <= 0) _numberOfDays = 1;

    _selectedDayIndex = 0;
    _daySelections = List.generate(_numberOfDays, (index) => index == 0);

    _dailyRoutes = List.from(widget.plan.dailyRoutes);
    if (_dailyRoutes.length < _numberOfDays) {
      for (int i = _dailyRoutes.length; i < _numberOfDays; i++) {
        _dailyRoutes.add(DailyRoute(dayIndex: i, points: []));
      }
    }
  }

  Future<List<LatLng>?> _fetchRouteFromORS(LatLng start, LatLng end) async {
    if (_orsApiKey == 'YOUR_OPENROUTESERVICE_API_KEY') return null;

    final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/foot-hiking/geojson');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': _orsApiKey,
    };
    final body = json.encode({
      "coordinates": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude]
      ]
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coords =
            data['features'][0]['geometry']['coordinates'];
        return coords.map((c) => LatLng(c[1], c[0])).toList();
      } else {
        print("ORS API Error: ${response.body}");
      }
    } catch (e) {
      print("ORS Exception: $e");
    }
    return null;
  }

  void _addPointToRoute(LatLng point) async {
    setState(() {
      _isLoading = true;
    });

    final currentRoute = _dailyRoutes[_selectedDayIndex];
    if (currentRoute.points.isNotEmpty) {
      final lastPoint = currentRoute.points.last;

      List<LatLng>? snappedRoute = await _fetchRouteFromORS(lastPoint, point);

      if (snappedRoute != null && snappedRoute.isNotEmpty) {
        // Poista edellinen piste, koska ORS palauttaa reitin alusta loppuun
        snappedRoute.removeAt(0);
        currentRoute.points.addAll(snappedRoute);
      } else {
        currentRoute.points.add(point);
      }
    } else {
      currentRoute.points.add(point);
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _clearCurrentDayRoute() {
    setState(() {
      _dailyRoutes[_selectedDayIndex].points.clear();
    });
  }

  void _undoLastPoint() {
    if (_dailyRoutes[_selectedDayIndex].points.isNotEmpty) {
      setState(() {
        _dailyRoutes[_selectedDayIndex].points.removeLast();
      });
    }
  }

  Future<void> _saveRoutes() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final updatedPlan = widget.plan.copyWith(dailyRoutes: _dailyRoutes);
      await _hikePlanService.updateHikePlan(updatedPlan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Route saved successfully!'),
            backgroundColor: Colors.green.shade700));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving route: $e'),
            backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Route Planner',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save Route',
            onPressed: _isLoading ? null : _saveRoutes,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.plan.latitude != null
                  ? LatLng(widget.plan.latitude!, widget.plan.longitude!)
                  : const LatLng(65.0, 25.5),
              initialZoom: 10.0,
              onTap: (_, point) => _addPointToRoute(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.treknoteflutter',
              ),
              PolylineLayer(
                polylines: _dailyRoutes.asMap().entries.map((entry) {
                  int dayIndex = entry.key;
                  DailyRoute route = entry.value;
                  return Polyline(
                    points: route.points,
                    strokeWidth: 5.0,
                    color: dayIndex == _selectedDayIndex
                        ? theme.colorScheme.primary
                        : Colors.grey.withOpacity(0.6),
                  );
                }).toList(),
              ),
              MarkerLayer(
                markers: _dailyRoutes
                    .expand((route) => route.points)
                    .map((point) => Marker(
                          width: 12.0,
                          height: 12.0,
                          point: point,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2.0),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.cardColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ToggleButtons(
                      isSelected: _daySelections,
                      onPressed: (int index) {
                        setState(() {
                          for (int i = 0; i < _daySelections.length; i++) {
                            _daySelections[i] = i == index;
                          }
                          _selectedDayIndex = index;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      selectedColor: theme.colorScheme.onPrimary,
                      color: theme.colorScheme.onSurface,
                      fillColor: theme.colorScheme.primary,
                      children: List.generate(
                        _numberOfDays,
                        (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('Day ${index + 1}'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'undo_fab',
                  mini: true,
                  onPressed: _undoLastPoint,
                  child: const Icon(Icons.undo),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'clear_fab',
                  onPressed: _clearCurrentDayRoute,
                  backgroundColor: theme.colorScheme.error,
                  child: const Icon(Icons.delete_sweep_outlined),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
