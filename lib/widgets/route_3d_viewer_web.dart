import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class Route3DViewer extends StatefulWidget {
  final List<LatLng> routePoints;
  final Color routeColor;
  final double animationSpeed;
  final double cameraHeight;
  final double cameraAngle;
  final bool isPlaying;
  final bool showTerrain;
  final bool showLabels;
  final VoidCallback? onPlaybackComplete;

  const Route3DViewer({
    super.key,
    required this.routePoints,
    required this.routeColor,
    this.animationSpeed = 1.0,
    this.cameraHeight = 500.0,
    this.cameraAngle = 45.0,
    this.isPlaying = false,
    this.showTerrain = true,
    this.showLabels = true,
    this.onPlaybackComplete,
  });

  @override
  State<Route3DViewer> createState() => _Route3DViewerState();
}

class _Route3DViewerState extends State<Route3DViewer> {
  late String _htmlContent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateHtmlContent();
  }

  void _generateHtmlContent() {
    final routeData = widget.routePoints.map((point) => {
      'lat': point.latitude,
      'lng': point.longitude,
    }).toList();

    _htmlContent = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>3D Route Viewer</title>
    <link rel="stylesheet" href="https://unpkg.com/maplibre-gl@4.0.0/dist/maplibre-gl.css">
    <script src="https://unpkg.com/maplibre-gl@4.0.0/dist/maplibre-gl.js"></script>
    <style>
        body { margin: 0; padding: 0; }
        #map { position: absolute; top: 0; bottom: 0; width: 100%; }
        .controls {
            position: absolute;
            top: 10px;
            right: 10px;
            background: rgba(0,0,0,0.8);
            padding: 10px;
            border-radius: 8px;
            color: white;
            font-family: Arial, sans-serif;
            z-index: 1000;
        }
        .control-group {
            margin-bottom: 10px;
        }
        .control-label {
            display: block;
            margin-bottom: 5px;
            font-size: 12px;
        }
        input[type="range"] {
            width: 150px;
        }
        button {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
            margin-right: 5px;
        }
        button:hover {
            background: #45a049;
        }
        button.pause {
            background: #f44336;
        }
        button.pause:hover {
            background: #da190b;
        }
    </style>
</head>
<body>
    <div id="map"></div>
    <div class="controls">
        <div class="control-group">
            <button id="playBtn" onclick="toggleAnimation()">Play</button>
            <button onclick="resetAnimation()">Reset</button>
        </div>
        <div class="control-group">
            <label class="control-label">Speed: <span id="speedValue">1.0</span>x</label>
            <input type="range" id="speed" min="0.25" max="4" step="0.25" value="1" onchange="updateSpeed(this.value)">
        </div>
        <div class="control-group">
            <label class="control-label">Pitch: <span id="pitchValue">60</span>°</label>
            <input type="range" id="pitch" min="0" max="85" step="5" value="60" onchange="updatePitch(this.value)">
        </div>
        <div class="control-group">
            <label class="control-label">Zoom: <span id="zoomValue">14</span></label>
            <input type="range" id="zoom" min="10" max="18" step="0.5" value="14" onchange="updateZoom(this.value)">
        </div>
    </div>

    <script>
        const routePoints = ${jsonEncode(routeData)};
        const routeColor = '${_colorToHex(widget.routeColor)}';
        
        // Initialize map with MapLibre GL JS
        const map = new maplibregl.Map({
            container: 'map',
            style: {
                version: 8,
                sources: {
                    osm: {
                        type: 'raster',
                        tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
                        tileSize: 256,
                        attribution: '© OpenStreetMap Contributors'
                    },
                    terrain: {
                        type: 'raster-dem',
                        tiles: ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],
                        tileSize: 256,
                        encoding: 'terrarium'
                    }
                },
                layers: [
                    {
                        id: 'osm',
                        type: 'raster',
                        source: 'osm'
                    }
                ],
                terrain: ${widget.showTerrain} ? {
                    source: 'terrain',
                    exaggeration: 1.5
                } : undefined,
                sky: {
                    'sky-color': '#199EF3',
                    'sky-horizon-blend': 0.5,
                    'horizon-color': '#ffffff',
                    'horizon-fog-blend': 0.5,
                    'fog-color': '#0000ff',
                    'fog-ground-blend': 0.5
                }
            },
            center: routePoints.length > 0 ? [routePoints[0].lng, routePoints[0].lat] : [0, 0],
            zoom: 14,
            pitch: 60,
            bearing: 0,
            antialias: true
        });

        let animationIndex = 0;
        let isAnimating = false;
        let animationId = null;
        let animationSpeed = 1.0;

        map.on('load', () => {
            // Add 3D terrain if enabled
            if (${widget.showTerrain}) {
                map.addSource('mapbox-dem', {
                    type: 'raster-dem',
                    url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
                    tileSize: 512,
                    maxzoom: 14
                });
                map.setTerrain({ source: 'mapbox-dem', exaggeration: 1.5 });
            }

            // Add route line
            if (routePoints.length > 0) {
                const routeGeoJson = {
                    type: 'Feature',
                    geometry: {
                        type: 'LineString',
                        coordinates: routePoints.map(p => [p.lng, p.lat])
                    }
                };

                map.addSource('route', {
                    type: 'geojson',
                    data: routeGeoJson
                });

                map.addLayer({
                    id: 'route-line',
                    type: 'line',
                    source: 'route',
                    layout: {
                        'line-join': 'round',
                        'line-cap': 'round'
                    },
                    paint: {
                        'line-color': routeColor,
                        'line-width': 4,
                        'line-opacity': 0.8
                    }
                });

                // Add start marker
                map.addSource('start', {
                    type: 'geojson',
                    data: {
                        type: 'Feature',
                        geometry: {
                            type: 'Point',
                            coordinates: [routePoints[0].lng, routePoints[0].lat]
                        }
                    }
                });

                map.addLayer({
                    id: 'start-point',
                    type: 'circle',
                    source: 'start',
                    paint: {
                        'circle-radius': 8,
                        'circle-color': '#4CAF50'
                    }
                });

                // Add end marker
                const lastPoint = routePoints[routePoints.length - 1];
                map.addSource('end', {
                    type: 'geojson',
                    data: {
                        type: 'Feature',
                        geometry: {
                            type: 'Point',
                            coordinates: [lastPoint.lng, lastPoint.lat]
                        }
                    }
                });

                map.addLayer({
                    id: 'end-point',
                    type: 'circle',
                    source: 'end',
                    paint: {
                        'circle-radius': 8,
                        'circle-color': '#F44336'
                    }
                });

                // Fit map to route bounds
                const bounds = new maplibregl.LngLatBounds();
                routePoints.forEach(point => {
                    bounds.extend([point.lng, point.lat]);
                });
                map.fitBounds(bounds, { padding: 50 });
            }
        });

        function animate() {
            if (!isAnimating || animationIndex >= routePoints.length - 1) {
                isAnimating = false;
                document.getElementById('playBtn').textContent = 'Play';
                document.getElementById('playBtn').classList.remove('pause');
                return;
            }

            const current = routePoints[animationIndex];
            const next = routePoints[animationIndex + 1];

            // Calculate bearing
            const bearing = getBearing(current, next);

            // Animate camera along route
            map.easeTo({
                center: [current.lng, current.lat],
                bearing: bearing,
                duration: 1000 / animationSpeed,
                easing: (t) => t
            });

            animationIndex++;
            animationId = setTimeout(animate, 1000 / animationSpeed);
        }

        function getBearing(start, end) {
            const startLat = start.lat * Math.PI / 180;
            const startLng = start.lng * Math.PI / 180;
            const endLat = end.lat * Math.PI / 180;
            const endLng = end.lng * Math.PI / 180;
            const dLng = endLng - startLng;

            const x = Math.sin(dLng) * Math.cos(endLat);
            const y = Math.cos(startLat) * Math.sin(endLat) - 
                      Math.sin(startLat) * Math.cos(endLat) * Math.cos(dLng);

            return (Math.atan2(x, y) * 180 / Math.PI + 360) % 360;
        }

        function toggleAnimation() {
            isAnimating = !isAnimating;
            const btn = document.getElementById('playBtn');
            
            if (isAnimating) {
                btn.textContent = 'Pause';
                btn.classList.add('pause');
                animate();
            } else {
                btn.textContent = 'Play';
                btn.classList.remove('pause');
                if (animationId) {
                    clearTimeout(animationId);
                }
            }
        }

        function resetAnimation() {
            isAnimating = false;
            animationIndex = 0;
            document.getElementById('playBtn').textContent = 'Play';
            document.getElementById('playBtn').classList.remove('pause');
            
            if (animationId) {
                clearTimeout(animationId);
            }
            
            if (routePoints.length > 0) {
                map.flyTo({
                    center: [routePoints[0].lng, routePoints[0].lat],
                    zoom: 14,
                    pitch: 60,
                    bearing: 0
                });
            }
        }

        function updateSpeed(value) {
            animationSpeed = parseFloat(value);
            document.getElementById('speedValue').textContent = value;
        }

        function updatePitch(value) {
            map.setPitch(parseInt(value));
            document.getElementById('pitchValue').textContent = value;
        }

        function updateZoom(value) {
            map.setZoom(parseFloat(value));
            document.getElementById('zoomValue').textContent = value;
        }
    </script>
</body>
</html>
    ''';

    setState(() {
      _isLoading = false;
    });
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  void didUpdateWidget(Route3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routePoints != widget.routePoints ||
        oldWidget.showTerrain != widget.showTerrain) {
      _generateHtmlContent();
    }
  }

  void _openInBrowser() async {
    // Create a data URI with the HTML content
    final dataUri = Uri.dataFromString(
      _htmlContent,
      mimeType: 'text/html',
      encoding: Encoding.getByName('utf-8'),
    );
    
    if (await canLaunchUrl(dataUri)) {
      await launchUrl(dataUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.routePoints.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.terrain,
              size: 64,
              color: Colors.white30,
            ),
            SizedBox(height: 16),
            Text(
              'No route data available',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Plan a route first to see the 3D fly-over',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    // For mobile/desktop, show a preview and button to open in browser
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.view_in_ar,
            size: 80,
            color: Colors.white54,
          ),
          const SizedBox(height: 24),
          const Text(
            '3D Route Visualization',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Route: ${widget.routePoints.length} waypoints',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Terrain: ${widget.showTerrain ? "Enabled" : "Disabled"}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open 3D View in Browser'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Click to view an interactive 3D fly-over of your route',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}