import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/daily_route_model.dart';
import '../providers/route_planner_provider.dart';
import '../widgets/ultra_smooth_3d_route.dart';

class Simple3DFlyoverPage extends StatefulWidget {
  final List<DailyRoute>? dailyRoutes;
  final String? hikeName;

  const Simple3DFlyoverPage({
    super.key,
    this.dailyRoutes,
    this.hikeName,
  });

  @override
  State<Simple3DFlyoverPage> createState() => _Simple3DFlyoverPageState();
}

class _Simple3DFlyoverPageState extends State<Simple3DFlyoverPage> {
  // Animation controls
  bool _isPlaying = false;
  double _speed = 1.0;
  double _height = 200.0; // Lower default height for better terrain view
  bool _showTerrain = true;
  bool _showControls = true;
  
  // Route data
  late List<DailyRoute> _routes;
  late String _hikeName;
  int _selectedDay = -1; // -1 = all days
  
  @override
  void initState() {
    super.initState();
    
    // Set fullscreen for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Initialize route data
    if (widget.dailyRoutes != null) {
      _routes = widget.dailyRoutes!;
      _hikeName = widget.hikeName ?? 'Route';
    } else {
      final provider = context.read<RoutePlannerProvider>();
      _routes = provider.plan.dailyRoutes;
      _hikeName = provider.plan.hikeName;
    }
  }
  
  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
  
  List<LatLng> _getRoutePoints() {
    if (_selectedDay == -1) {
      return _routes.expand((r) => r.points).toList();
    } else if (_selectedDay < _routes.length) {
      return _routes[_selectedDay].points;
    }
    return [];
  }
  
  Color _getRouteColor() {
    if (_selectedDay >= 0 && _selectedDay < _routes.length) {
      return _routes[_selectedDay].routeColor;
    }
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final routePoints = _getRoutePoints();
    
    if (routePoints.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.terrain, size: 64, color: Colors.white30),
              const SizedBox(height: 16),
              const Text(
                'No route data available',
                style: TextStyle(color: Colors.white54, fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Main 3D route viewer
          UltraSmooth3DRoute(
            routePoints: routePoints,
            routeColor: _getRouteColor(),
            animationSpeed: _speed,
            cameraHeight: _height,
            cameraAngle: 45,
            isPlaying: _isPlaying,
            showTerrain: _showTerrain,
            onPlaybackComplete: () {
              setState(() {
                _isPlaying = false;
              });
            },
          ),
          
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _hikeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _selectedDay == -1 
                              ? 'All Days' 
                              : 'Day ${_selectedDay + 1}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showTerrain ? Icons.terrain : Icons.map,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _showTerrain = !_showTerrain;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Control panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _showControls ? 0 : -200,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Day selector (if multiple days)
                      if (_routes.length > 1) ...[
                        SizedBox(
                          height: 32,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _routes.length + 1,
                            itemBuilder: (context, index) {
                              final isSelected = _selectedDay == index - 1;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    index == 0 ? 'All' : 'Day $index',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected ? Colors.white : Colors.white70,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: index == 0 
                                      ? Colors.blue 
                                      : _routes[index - 1].routeColor,
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedDay = index - 1;
                                      _isPlaying = false;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Play controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Speed control
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.speed, color: Colors.white70, size: 16),
                                const SizedBox(width: 8),
                                DropdownButton<double>(
                                  value: _speed,
                                  dropdownColor: Colors.grey[900],
                                  underline: const SizedBox(),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  items: const [
                                    DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                                    DropdownMenuItem(value: 1.0, child: Text('1x')),
                                    DropdownMenuItem(value: 2.0, child: Text('2x')),
                                    DropdownMenuItem(value: 4.0, child: Text('4x')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _speed = value ?? 1.0;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Play/Pause button
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isPlaying
                                    ? [Colors.orange, Colors.deepOrange]
                                    : [Colors.blue, Colors.lightBlue],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isPlaying ? Colors.orange : Colors.blue)
                                      .withOpacity(0.3),
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
                          
                          const SizedBox(width: 16),
                          
                          // Height control
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.height, color: Colors.white70, size: 16),
                                const SizedBox(width: 8),
                                DropdownButton<double>(
                                  value: _height,
                                  dropdownColor: Colors.grey[900],
                                  underline: const SizedBox(),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  items: const [
                                    DropdownMenuItem(value: 100, child: Text('Very Low')),
                                    DropdownMenuItem(value: 200, child: Text('Low')),
                                    DropdownMenuItem(value: 400, child: Text('Medium')),
                                    DropdownMenuItem(value: 800, child: Text('High')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _height = value ?? 500;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Hide/Show controls button
          Positioned(
            bottom: _showControls ? 180 : 20,
            right: 20,
            child: FloatingActionButton.small(
              backgroundColor: Colors.black54,
              onPressed: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              child: Icon(
                _showControls ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}