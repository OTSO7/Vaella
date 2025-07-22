import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../widgets/select_visibility_modal.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();

  Stream<List<Post>> _getPublicPostsStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('visibility', isEqualTo: 'public')
        .where('latitude', isNotEqualTo: null)
        // MUUTETTU: Lisätty vaaditut orderBy-ehdot. Tämä vaatii uuden Firestore-indeksin!
        .orderBy('latitude')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Post.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  void _showRecentPostsList(BuildContext context, List<Post> posts) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Expanded(
                    child: posts.isEmpty
                        ? Center(
                            child: Text("No posts yet.",
                                style: theme.textTheme.bodyLarge),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                              final post = posts[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: post.userAvatarUrl.isNotEmpty
                                      ? NetworkImage(post.userAvatarUrl)
                                      : null,
                                  child: post.userAvatarUrl.isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(post.title,
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    "by @${post.username} in ${post.location}"),
                                onTap: () {
                                  Navigator.pop(context);
                                  if (post.latitude != null &&
                                      post.longitude != null) {
                                    _mapController.move(
                                      LatLng(post.latitude!, post.longitude!),
                                      14.0,
                                    );
                                  }
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
      },
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
        backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
        elevation: 0,
        actions: [
          StreamBuilder<List<Post>>(
            stream: _getPublicPostsStream(),
            builder: (context, snapshot) {
              return IconButton(
                icon: const Icon(Icons.list_rounded),
                tooltip: "Recent Posts",
                onPressed: () {
                  if (snapshot.hasData) {
                    _showRecentPostsList(context, snapshot.data!);
                  }
                },
              );
            },
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(65.0, 25.5),
          initialZoom: 5.0,
          maxZoom: 18.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.treknoteflutter',
          ),
          StreamBuilder<List<Post>>(
            stream: _getPublicPostsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // Tämä printtaa virheen konsoliin, josta voit kopioida indeksin luontilinkin
                print("⛔️ Firestore Query Error: ${snapshot.error}");
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Could not load posts. A Firestore index is likely required. Please check the console log for an error link.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }

              final posts = snapshot.data!;
              final markers = posts
                  .where(
                      (post) => post.latitude != null && post.longitude != null)
                  .map((post) => Marker(
                        point: LatLng(post.latitude!, post.longitude!),
                        width: 50,
                        height: 60,
                        child: _buildPostMarker(context, post),
                      ))
                  .toList();

              return MarkerClusterLayerWidget(
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
              );
            },
          ),
        ],
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
