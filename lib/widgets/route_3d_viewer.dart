import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
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
  late String _viewId;
  html.IFrameElement? _iFrame;

  @override
  void initState() {
    super.initState();
    _viewId = 'cesium-3d-viewer-${DateTime.now().millisecondsSinceEpoch}';
    _setupViewer();
  }

  void _setupViewer() {
    final routeData = widget.routePoints.map((point) => {
      'lat': point.latitude,
      'lng': point.longitude,
    }).toList();

    final htmlContent = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <script src="https://cesium.com/downloads/cesiumjs/releases/1.119/Build/Cesium/Cesium.js"></script>
    <link href="https://cesium.com/downloads/cesiumjs/releases/1.119/Build/Cesium/Widgets/widgets.css" rel="stylesheet">
    <style>
        html, body, #cesiumContainer {
            width: 100%; height: 100%; margin: 0; padding: 0; overflow: hidden;
            background: #000;
        }
        .cesium-widget-credits {
            display: none !important;
        }
    </style>
</head>
<body>
    <div id="cesiumContainer"></div>
    <script>
        // Initialize Cesium with free Ion token for terrain
        Cesium.Ion.defaultAccessToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiJlYWE1OWUxNy1mMWZiLTQzYjYtYTQ0OS1kMWFjYmFkNjc5YzciLCJpZCI6NTU3NjgsImlhdCI6MTYyMzI1NTU5MH0.WafrBABa8RgDLCL7hO-PCvANnDUAZPvMZCIxYUqFD7A';
        
        // Create viewer with terrain
        const viewer = new Cesium.Viewer('cesiumContainer', {
            terrainProvider: ${widget.showTerrain} ? Cesium.createWorldTerrain() : new Cesium.EllipsoidTerrainProvider(),
            baseLayerPicker: false,
            geocoder: false,
            homeButton: false,
            sceneModePicker: false,
            navigationHelpButton: false,
            animation: false,
            timeline: false,
            fullscreenButton: false,
            vrButton: false,
            scene3DOnly: true,
            shadows: true,
            terrainShadows: Cesium.ShadowMode.ENABLED,
        });

        // Configure scene
        viewer.scene.globe.enableLighting = true;
        viewer.scene.globe.depthTestAgainstTerrain = true;
        
        // Route data
        const routePoints = ${jsonEncode(routeData)};
        const routeColor = Cesium.Color.fromCssColorString('${_colorToHex(widget.routeColor)}');
        
        if (routePoints.length > 0) {
            // Convert route points to Cartesian3 positions
            const positions = routePoints.map(point => 
                Cesium.Cartesian3.fromDegrees(point.lng, point.lat)
            );
            
            // Sample heights for terrain following
            const terrainProvider = viewer.terrainProvider;
            const promise = Cesium.sampleTerrainMostDetailed(terrainProvider, 
                routePoints.map(point => Cesium.Cartographic.fromDegrees(point.lng, point.lat))
            );
            
            promise.then(function(updatedPositions) {
                // Create positions with terrain heights
                const terrainPositions = updatedPositions.map((cartographic, index) => {
                    const height = cartographic.height || 0;
                    return Cesium.Cartesian3.fromDegrees(
                        routePoints[index].lng,
                        routePoints[index].lat,
                        height + 10 // Add 10m offset above ground
                    );
                });
                
                // Add route polyline
                viewer.entities.add({
                    name: 'Route',
                    polyline: {
                        positions: terrainPositions,
                        width: 5,
                        material: new Cesium.PolylineGlowMaterialProperty({
                            glowPower: 0.2,
                            color: routeColor
                        }),
                        clampToGround: false,
                        followSurface: true
                    }
                });
                
                // Add start and end markers
                if (terrainPositions.length > 0) {
                    // Start marker
                    viewer.entities.add({
                        position: terrainPositions[0],
                        billboard: {
                            image: 'data:image/svg+xml;base64,' + btoa(\`
                                <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24">
                                    <circle cx="12" cy="12" r="10" fill="#4CAF50"/>
                                    <text x="12" y="16" text-anchor="middle" fill="white" font-size="12" font-weight="bold">S</text>
                                </svg>
                            \`),
                            verticalOrigin: Cesium.VerticalOrigin.BOTTOM,
                            scale: 1.0
                        },
                        label: ${widget.showLabels} ? {
                            text: 'Start',
                            font: '14pt sans-serif',
                            style: Cesium.LabelStyle.FILL_AND_OUTLINE,
                            outlineWidth: 2,
                            verticalOrigin: Cesium.VerticalOrigin.TOP,
                            pixelOffset: new Cesium.Cartesian2(0, 20)
                        } : undefined
                    });
                    
                    // End marker
                    viewer.entities.add({
                        position: terrainPositions[terrainPositions.length - 1],
                        billboard: {
                            image: 'data:image/svg+xml;base64,' + btoa(\`
                                <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24">
                                    <circle cx="12" cy="12" r="10" fill="#F44336"/>
                                    <text x="12" y="16" text-anchor="middle" fill="white" font-size="12" font-weight="bold">F</text>
                                </svg>
                            \`),
                            verticalOrigin: Cesium.VerticalOrigin.BOTTOM,
                            scale: 1.0
                        },
                        label: ${widget.showLabels} ? {
                            text: 'Finish',
                            font: '14pt sans-serif',
                            style: Cesium.LabelStyle.FILL_AND_OUTLINE,
                            outlineWidth: 2,
                            verticalOrigin: Cesium.VerticalOrigin.TOP,
                            pixelOffset: new Cesium.Cartesian2(0, 20)
                        } : undefined
                    });
                }
                
                // Setup camera for flyover
                setupFlyover(terrainPositions);
            });
            
            // Flyover animation setup
            let animationStartTime = null;
            let isAnimating = false;
            let currentIndex = 0;
            
            function setupFlyover(positions) {
                if (positions.length < 2) return;
                
                // Calculate total route distance for timing
                let totalDistance = 0;
                for (let i = 1; i < positions.length; i++) {
                    totalDistance += Cesium.Cartesian3.distance(positions[i-1], positions[i]);
                }
                
                // Initial camera position
                viewer.camera.setView({
                    destination: positions[0],
                    orientation: {
                        heading: Cesium.Math.toRadians(0),
                        pitch: Cesium.Math.toRadians(-${widget.cameraAngle}),
                        roll: 0.0
                    }
                });
                
                // Zoom to show entire route initially
                viewer.zoomTo(viewer.entities);
            }
            
            // Animation control
            window.startAnimation = function() {
                isAnimating = true;
                animationStartTime = Date.now();
                currentIndex = 0;
                animate();
            };
            
            window.stopAnimation = function() {
                isAnimating = false;
            };
            
            window.updateSettings = function(settings) {
                // Update camera height and angle
                if (viewer.camera) {
                    const currentPosition = viewer.camera.position;
                    viewer.camera.setView({
                        destination: currentPosition,
                        orientation: {
                            heading: viewer.camera.heading,
                            pitch: Cesium.Math.toRadians(-settings.cameraAngle),
                            roll: 0.0
                        }
                    });
                }
            };
            
            function animate() {
                if (!isAnimating) return;
                
                const positions = viewer.entities.values[0].polyline.positions.getValue();
                if (!positions || currentIndex >= positions.length - 1) {
                    isAnimating = false;
                    window.parent.postMessage({type: 'playbackComplete'}, '*');
                    return;
                }
                
                const speed = ${widget.animationSpeed};
                const cameraHeight = ${widget.cameraHeight};
                
                // Calculate interpolation along the route
                const elapsed = (Date.now() - animationStartTime) / 1000;
                const progress = (elapsed * speed * 10) / positions.length;
                
                currentIndex = Math.min(Math.floor(progress * positions.length), positions.length - 1);
                
                if (currentIndex < positions.length - 1) {
                    const currentPos = positions[currentIndex];
                    const nextPos = positions[currentIndex + 1];
                    
                    // Calculate heading between points
                    const heading = Cesium.Cartesian3.angleBetween(currentPos, nextPos);
                    
                    // Get terrain height at current position
                    const cartographic = Cesium.Cartographic.fromCartesian(currentPos);
                    const terrainHeight = cartographic.height || 0;
                    
                    // Set camera position above the route
                    const cameraPosition = Cesium.Cartesian3.fromDegrees(
                        Cesium.Math.toDegrees(cartographic.longitude),
                        Cesium.Math.toDegrees(cartographic.latitude),
                        terrainHeight + cameraHeight
                    );
                    
                    viewer.camera.setView({
                        destination: cameraPosition,
                        orientation: {
                            heading: heading,
                            pitch: Cesium.Math.toRadians(-${widget.cameraAngle}),
                            roll: 0.0
                        }
                    });
                    
                    requestAnimationFrame(animate);
                }
            }
        }
        
        // Listen for control messages from Flutter
        window.addEventListener('message', function(event) {
            if (event.data.type === 'play') {
                startAnimation();
            } else if (event.data.type === 'pause') {
                stopAnimation();
            } else if (event.data.type === 'updateSettings') {
                updateSettings(event.data.settings);
            }
        });
    </script>
</body>
</html>
    ''';

    _iFrame = html.IFrameElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..srcdoc = htmlContent;

    // Register the iframe
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => _iFrame!,
    );
  }

  @override
  void didUpdateWidget(Route3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Send updates to the iframe
    if (_iFrame != null) {
      final message = {
        'type': widget.isPlaying ? 'play' : 'pause',
        'settings': {
          'animationSpeed': widget.animationSpeed,
          'cameraHeight': widget.cameraHeight,
          'cameraAngle': widget.cameraAngle,
        }
      };
      
      _iFrame!.contentWindow?.postMessage(message, '*');
    }
    
    // If route points changed significantly, recreate the viewer
    if (oldWidget.routePoints.length != widget.routePoints.length ||
        oldWidget.showTerrain != widget.showTerrain) {
      _setupViewer();
      setState(() {});
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  void dispose() {
    _iFrame?.remove();
    super.dispose();
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

    return HtmlElementView(viewType: _viewId);
  }
}