// lib/pages/full_screen_map_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/post_model.dart';
import '../widgets/post_card.dart';

class FullScreenMapPage extends StatefulWidget {
  // TÄMÄ ON KORJATTU KOHTA: Widgetti vastaanottaa nyt 'posts'-nimisen parametrin.
  final List<Post> posts;
  const FullScreenMapPage({super.key, required this.posts});

  @override
  State<FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<FullScreenMapPage> {
  final MapController _mapController = MapController();
  Post? _selectedPost;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.posts.isNotEmpty && mounted) {
        final bounds = LatLngBounds.fromPoints(
          widget.posts.map((p) => LatLng(p.latitude!, p.longitude!)).toList(),
        );
        _mapController.fitCamera(CameraFit.bounds(
            bounds: bounds, padding: const EdgeInsets.all(50.0)));
      }
    });
  }

  void _onMarkerTap(Post post) {
    setState(() => _selectedPost = post);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor:
                Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
                initialCenter: LatLng(64.9, 27.5), initialZoom: 5),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              PolylineLayer(polylines: _buildPolylinesForSelectedPost()),
              MarkerLayer(
                markers: widget.posts
                    .map((post) => _buildMarkerForPost(post))
                    .toList(),
              ),
              RichAttributionWidget(attributions: [
                TextSourceAttribution('© OpenStreetMap',
                    onTap: () => launchUrl(
                        Uri.parse('https://openstreetmap.org/copyright'))),
              ]),
            ],
          ),
          _buildPostPopup(context),
        ],
      ),
    );
  }

  List<Polyline> _buildPolylinesForSelectedPost() {
    if (_selectedPost?.dailyRoutes == null) return [];
    return _selectedPost!.dailyRoutes!.map((route) {
      return Polyline(
        points: route.points,
        color: route.routeColor.withOpacity(0.8),
        strokeWidth: 5.0,
      );
    }).toList();
  }

  Marker _buildMarkerForPost(Post post) {
    final bool isSelected = _selectedPost?.id == post.id;
    return Marker(
      width: 40,
      height: 40,
      point: LatLng(post.latitude!, post.longitude!),
      child: GestureDetector(
        onTap: () => _onMarkerTap(post),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: isSelected ? 1.2 : 1.0,
          child: Icon(
            Icons.location_on,
            size: isSelected ? 40 : 35,
            color: isSelected
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.primary,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
        ),
      ),
    );
  }

  Widget _buildPostPopup(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      bottom: _selectedPost != null
          ? MediaQuery.of(context).padding.bottom + 16
          : -300,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: _selectedPost != null ? 1.0 : 0.0,
        child: _selectedPost != null
            ? PostCard(
                post: _selectedPost!,
                onTap: () => context.push('/post/${_selectedPost!.id}'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
