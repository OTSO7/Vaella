import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import '../widgets/select_visibility_modal.dart';

enum HomeView { map, feed }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  HomeView _currentView = HomeView.map;
  static const double _swipeVelocityThreshold = 300;

  Stream<List<Post>> _getPublicPostsStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('visibility', isEqualTo: 'public')
        .where('latitude', isNotEqualTo: null)
        .orderBy('latitude')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Post.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  // --- WIDGET-METODIT ---

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

  Widget _buildMapView(BuildContext context, List<Post> posts) {
    final markers = posts
        .where((post) => post.latitude != null && post.longitude != null)
        .map((post) => Marker(
              point: LatLng(post.latitude!, post.longitude!),
              width: 50,
              height: 60,
              child: _buildPostMarker(context, post),
            ))
        .toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(65.0, 25.5),
        initialZoom: 5.0,
        maxZoom: 18.0,
      ),
      children: [
        // MUUTETTU: Vaihdettu karttatyyli CARTO Voyageriksi.
        // Tämä on hillitty, selkeä ja graafinen tyyli haaleilla väreillä.
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.treknoteflutter',
        ),

        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 80,
            size: const Size(50, 50),
            markers: markers,
            polygonOptions: const PolygonOptions(
                borderColor: Colors.blueAccent,
                color: Colors.black12,
                borderStrokeWidth: 3),
            builder: (context, markers) {
              return _buildClusterMarker(context, markers.length);
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
        title: Image.asset('assets/images/white2.png',
            height: 35, fit: BoxFit.contain),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Could not load posts. A Firestore index is likely required. Please check the console log.",
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
                  context.push('/create-post', extra: selectedVisibility);
                });
              },
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  // --- APUFUNKTIOT KARTTAMERKINNÖILLE ---

  Widget _buildPostMarker(BuildContext context, Post post) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => _buildPostModal(context, post),
        );
      },
      child: Tooltip(
        message: post.title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).cardColor,
                border: Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 2),
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
              child: Container(
                color: Theme.of(context).colorScheme.primary,
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
          Text(post.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text("by @${post.username}",
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.secondary)),
          const SizedBox(height: 12),
          Text(post.caption,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('View Full Post'),
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
