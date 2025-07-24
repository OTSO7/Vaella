// lib/pages/home_page.dart

import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_marker_cluster/src/node/marker_node.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import '../widgets/select_visibility_modal.dart';
import '../widgets/star_rating_display.dart';
import '../models/daily_route_model.dart';
import '../utils/map_helpers.dart'; // UUSI IMPORT APUFUNKTIOLLE

enum HomeView { map, feed }

class PostMarker extends Marker {
  final Post post;

  PostMarker({
    required this.post,
    required Widget child,
    super.width = 50,
    super.height = 60,
  }) : super(
          point: LatLng(post.latitude!, post.longitude!),
          child: child,
        );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  HomeView _currentView = HomeView.map;
  static const double _swipeVelocityThreshold = 300;

  Post? _selectedPost;
  final List<Polyline> _selectedRoutePolylines = [];
  final List<Marker> _arrowMarkers = [];

  Stream<List<Post>> _getPublicPostsStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('visibility', isEqualTo: 'public')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Post.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>))
            .where((post) => post != null)
            .cast<Post>()
            .toList());
  }

  // POISTETTU: Paikallinen _generateArrowMarkers-metodi on siirretty map_helpers.dart-tiedostoon.

  void _updateSelectedRoute() {
    _selectedRoutePolylines.clear();
    _arrowMarkers.clear();

    if (_selectedPost != null &&
        _selectedPost!.dailyRoutes != null &&
        _selectedPost!.dailyRoutes!.isNotEmpty) {
      for (final route in _selectedPost!.dailyRoutes!) {
        final polyline = Polyline(
          points: route.points,
          color: route.routeColor.withOpacity(0.8),
          strokeWidth: 5.0,
          borderColor: Colors.black.withOpacity(0.2),
          borderStrokeWidth: 1.0,
        );
        _selectedRoutePolylines.add(polyline);
      }
      // KORJATTU: Käytetään keskitettyä apufunktiota.
      _arrowMarkers
          .addAll(generateArrowMarkersForDays(_selectedPost!.dailyRoutes!));
    }
  }

  void _handlePostSelection(Post post) {
    setState(() {
      _selectedPost = post;
      _updateSelectedRoute();
    });

    final bool hasRoute =
        post.dailyRoutes != null && post.dailyRoutes!.isNotEmpty;
    if (hasRoute) {
      final allPoints =
          post.dailyRoutes!.expand((route) => route.points).toList();
      if (allPoints.length > 1) {
        final bounds = LatLngBounds.fromPoints(allPoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50.0),
          ),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPostModal(context, post),
    ).whenComplete(() {
      setState(() {
        _selectedPost = null;
        _selectedRoutePolylines.clear();
        _arrowMarkers.clear();
      });
    });
  }

  void _showPostSelectionSheet(BuildContext context, List<Post> posts) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (builderContext) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Posts at this location',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Divider(),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: posts.length,
                  itemBuilder: (ctx, index) {
                    final post = posts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: post.userAvatarUrl.isNotEmpty
                            ? NetworkImage(post.userAvatarUrl)
                            : null,
                        child: post.userAvatarUrl.isEmpty
                            ? const Icon(Icons.person, size: 20)
                            : null,
                      ),
                      title: Text(post.title, style: theme.textTheme.bodyLarge),
                      subtitle: Text("by @${post.username}"),
                      onTap: () {
                        Navigator.pop(builderContext);
                        _handlePostSelection(post);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapView(BuildContext context, List<Post> posts) {
    final postMarkers = posts
        .where((post) => post.latitude != null && post.longitude != null)
        .map((post) => PostMarker(
              post: post,
              child: _buildPostMarkerWidget(context, post),
            ))
        .toList();

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(65.0, 25.5),
        initialZoom: 5.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
        ),
        PolylineLayer(polylines: _selectedRoutePolylines),
        MarkerLayer(markers: _arrowMarkers),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 80,
            size: const Size(50, 50),
            markers: postMarkers,
            polygonOptions: const PolygonOptions(
                borderColor: Colors.blueAccent,
                color: Colors.black12,
                borderStrokeWidth: 3),
            builder: (context, markers) {
              return _buildClusterMarker(context, markers.length);
            },
            onClusterTap: (cluster) {
              final firstPoint = cluster.markers.first.point;
              final allSameLocation =
                  cluster.markers.every((m) => m.point == firstPoint);

              if (allSameLocation && cluster.markers.length > 1) {
                final postsInCluster = cluster.markers
                    .map((node) =>
                        ((node as MarkerNode).marker as PostMarker).post)
                    .toList();
                _showPostSelectionSheet(context, postsInCluster);
              } else {
                _mapController.fitCamera(
                  CameraFit.bounds(
                      bounds: cluster.bounds,
                      padding: const EdgeInsets.all(50)),
                );
              }
            },
          ),
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () =>
                  launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
            ),
            TextSourceAttribution(
              'CARTO',
              onTap: () =>
                  launchUrl(Uri.parse('https://carto.com/attributions')),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/white2.png', height: 80),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            tooltip: "Search",
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<List<Post>>(
        stream: _getPublicPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print(snapshot.error);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Could not load posts. A Firestore index is likely required. Please check the console log for a link to create it.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            );
          }
          final posts = snapshot.data ?? [];
          return Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _currentView == HomeView.map
                    ? _buildMapView(context, posts)
                    : _buildPostFeed(context, posts, authProvider),
              ),
              Positioned(
                bottom: 15,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildFloatingViewSwitcher(context),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: authProvider.isLoggedIn
          ? FloatingActionButton(
              onPressed: () {
                showSelectVisibilityModal(context, (selectedVisibility) {
                  context.push('/create-post', extra: {
                    'visibility': selectedVisibility,
                    'plan': null,
                  });
                });
              },
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildFloatingViewSwitcher(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(30.0),
              border: Border.all(color: Colors.white.withOpacity(0.2))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSwitcherButton(context, HomeView.map, Icons.map_outlined),
              const SizedBox(width: 4),
              _buildSwitcherButton(
                  context, HomeView.feed, Icons.view_stream_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitcherButton(
      BuildContext context, HomeView view, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _currentView == view;
    return GestureDetector(
      onTap: () {
        if (_currentView != view) {
          setState(() {
            _currentView = view;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildPostFeed(
      BuildContext context, List<Post> posts, AuthProvider authProvider) {
    if (posts.isEmpty) {
      return Center(
        child: Text("No posts found.",
            style: Theme.of(context).textTheme.titleMedium),
      );
    }
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -_swipeVelocityThreshold) {
          setState(() {
            _currentView = HomeView.map;
          });
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(
            top: 8.0, left: 8.0, right: 8.0, bottom: 120.0),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          return PostCard(
            key: ValueKey(posts[index].id),
            post: posts[index],
            currentUserId: authProvider.user?.uid,
          );
        },
      ),
    );
  }

  Widget _buildPostMarkerWidget(BuildContext context, Post post) {
    final isSelected = _selectedPost?.id == post.id;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _handlePostSelection(post),
      child: Tooltip(
        message: post.title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.cardColor,
                border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary,
                    width: isSelected ? 3 : 2),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: post.userAvatarUrl.isNotEmpty
                    ? NetworkImage(post.userAvatarUrl)
                    : null,
                child: post.userAvatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
            ),
            ClipPath(
              clipper: _TriangleClipper(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: isSelected
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
                height: 8,
                width: 16,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildClusterMarker(BuildContext context, int count) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.secondary.withOpacity(0.9),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 6,
              spreadRadius: 2)
        ],
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPostModal(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "by @${post.username}",
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.secondary),
              ),
              StarRatingDisplay(
                  rating: post.averageRating, size: 18, showLabel: false),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () {
                Navigator.pop(context);
                context.push('/post/${post.id}');
              },
              child: const Text('View Full Post'),
            ),
          )
        ],
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
