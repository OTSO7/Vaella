import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../models/daily_route_model.dart';
import '../providers/route_planner_provider.dart';
import '../widgets/smooth_route_animator.dart';
import '../widgets/elevation_profile_chart.dart';

class Route3DFlyoverPage extends StatefulWidget {
  final List<DailyRoute>? dailyRoutes;
  final String? hikeName;

  const Route3DFlyoverPage({
    super.key,
    this.dailyRoutes,
    this.hikeName,
  });

  @override
  State<Route3DFlyoverPage> createState() => _Route3DFlyoverPageState();
}

class _Route3DFlyoverPageState extends State<Route3DFlyoverPage> {
  double _animationSpeed = 1.0;
  double _cameraHeight = 500.0;
  double _cameraAngle = 45.0;
  bool _isPlaying = false;
  bool _showTerrain = true;
  bool _showLabels = true;
  int _selectedDayIndex = -1; // -1 means all days
  
  late List<DailyRoute> _routes;
  late String _hikeName;

  @override
  void initState() {
    super.initState();
    if (widget.dailyRoutes != null) {
      _routes = widget.dailyRoutes!;
      _hikeName = widget.hikeName ?? 'Route';
    } else {
      final provider = context.read<RoutePlannerProvider>();
      _routes = provider.plan.dailyRoutes;
      _hikeName = provider.plan.hikeName;
    }
  }

  List<LatLng> _getSelectedRoutePoints() {
    if (_selectedDayIndex == -1) {
      // All routes combined
      return _routes.expand((route) => route.points).toList();
    } else if (_selectedDayIndex < _routes.length) {
      // Specific day route
      return _routes[_selectedDayIndex].points;
    }
    return [];
  }

  Color _getRouteColor() {
    if (_selectedDayIndex >= 0 && _selectedDayIndex < _routes.length) {
      return _routes[_selectedDayIndex].routeColor;
    }
    return Colors.blue; // Default color for combined routes
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routePoints = _getSelectedRoutePoints();
    
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3D Route Visualization',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            Text(
              _hikeName,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _showTerrain ? Icons.satellite_alt : Icons.map,
              color: _showTerrain ? Colors.blue : Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _showTerrain = !_showTerrain;
              });
            },
            tooltip: _showTerrain ? 'Show Map' : 'Show Satellite',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 3D Map Viewer with smooth animation
          SmoothRouteAnimator(
            routePoints: routePoints,
            routeColor: _getRouteColor(),
            animationSpeed: _animationSpeed,
            cameraHeight: _cameraHeight,
            cameraAngle: _cameraAngle,
            isPlaying: _isPlaying,
            showTerrain: _showTerrain,
            onPlaybackComplete: () {
              setState(() {
                _isPlaying = false;
              });
            },
          ),
          
          // Simplified Control Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Day Selector (if multiple days)
                  if (_routes.length > 1) ...[
                    SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _routes.length + 1,
                        itemBuilder: (context, index) {
                          final isSelected = _selectedDayIndex == (index - 1);
                          final label = index == 0 ? 'All' : 'Day $index';
                          final color = index == 0 
                              ? Colors.blue 
                              : _routes[index - 1].routeColor;
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedDayIndex = index - 1;
                                  _isPlaying = false;
                                });
                              },
                              selectedColor: color,
                              backgroundColor: Colors.grey[800],
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Main Playback Control
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Play/Pause Button
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isPlaying 
                                ? [Colors.orange, Colors.deepOrange]
                                : [Colors.blue, Colors.blueAccent],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isPlaying ? Colors.orange : Colors.blue).withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPlaying = !_isPlaying;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Simplified Controls Row
                  Row(
                    children: [
                      // Speed Control
                      Expanded(
                        child: _buildCompactControl(
                          Icons.speed,
                          'Speed',
                          '${_animationSpeed.toStringAsFixed(1)}x',
                          () {
                            setState(() {
                              _animationSpeed = _animationSpeed >= 4 ? 0.5 : _animationSpeed + 0.5;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // View Control
                      Expanded(
                        child: _buildCompactControl(
                          Icons.remove_red_eye,
                          'View',
                          '${_cameraAngle.toStringAsFixed(0)}°',
                          () {
                            setState(() {
                              _cameraAngle = _cameraAngle >= 75 ? 15 : _cameraAngle + 15;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Altitude Control
                      Expanded(
                        child: _buildCompactControl(
                          Icons.flight,
                          'Height',
                          '${(_cameraHeight / 100).toStringAsFixed(0)}00m',
                          () {
                            setState(() {
                              _cameraHeight = _cameraHeight >= 2000 ? 200 : _cameraHeight + 300;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Route Statistics Overlay
          Positioned(
            top: 16,
            left: 16,
            child: _buildStatsOverlay(),
          ),
          
          // Elevation Profile (responsive)
          if (!_isPlaying && MediaQuery.of(context).size.width > 600)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: MediaQuery.of(context).size.width > 800 ? 300 : 250,
                height: 150,
                child: ElevationProfileChart(
                  routePoints: _getSelectedRoutePoints(),
                  routeColor: _getRouteColor(),
                  height: 150,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _routes.length + 1,
        itemBuilder: (context, index) {
          final isSelected = _selectedDayIndex == (index - 1);
          final label = index == 0 ? 'All Days' : 'Day $index';
          final color = index == 0 
              ? Colors.blue 
              : _routes[index - 1].routeColor;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedDayIndex = index - 1;
                  _isPlaying = false;
                });
              },
              backgroundColor: color.withOpacity(0.3),
              selectedColor: color.withOpacity(0.7),
              checkmarkColor: Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white),
          iconSize: 32,
          onPressed: () {
            // Reset to beginning
            setState(() {
              _isPlaying = false;
            });
          },
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary,
          ),
          child: IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            iconSize: 40,
            onPressed: () {
              setState(() {
                _isPlaying = !_isPlaying;
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white),
          iconSize: 32,
          onPressed: () {
            // Skip to end
            setState(() {
              _isPlaying = false;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCompactControl(
    IconData icon,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverlay() {
    final selectedRoutes = _selectedDayIndex == -1
        ? _routes
        : (_selectedDayIndex < _routes.length 
            ? [_routes[_selectedDayIndex]]
            : []);
    
    if (selectedRoutes.isEmpty) return const SizedBox.shrink();
    
    final totalSummary = selectedRoutes.fold(
      RouteSummary(),
      (sum, route) => sum + route.summary,
    );
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatRow(
            Icons.route,
            '${_formatDistance(totalSummary.distance)}',
          ),
          const SizedBox(height: 4),
          _buildStatRow(
            Icons.timer,
            _formatDuration(totalSummary.duration),
          ),
          const SizedBox(height: 4),
          _buildStatRow(
            Icons.trending_up,
            '↑ ${totalSummary.ascent.toStringAsFixed(0)}m',
          ),
          const SizedBox(height: 4),
          _buildStatRow(
            Icons.trending_down,
            '↓ ${totalSummary.descent.toStringAsFixed(0)}m',
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  String _formatDuration(double seconds) {
    final d = Duration(seconds: seconds.round());
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}min';
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('3D Fly-over Controls'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('• Use play button to start/pause animation'),
              SizedBox(height: 8),
              Text('• Adjust speed to control flyover pace'),
              SizedBox(height: 8),
              Text('• Change altitude for different perspectives'),
              SizedBox(height: 8),
              Text('• Modify camera angle for viewing preference'),
              SizedBox(height: 8),
              Text('• Toggle terrain for 3D elevation view'),
              SizedBox(height: 8),
              Text('• Select specific days or view entire route'),
              SizedBox(height: 16),
              Text(
                'Terrain data provided by Cesium Ion',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}