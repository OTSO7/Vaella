// lib/pages/post_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/post_model.dart';
import '../utils/rating_utils.dart';
import '../utils/map_helpers.dart';
import '../widgets/detailed_rating_display.dart';
import 'full_screen_map_page.dart';

class PostDetailPage extends StatelessWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future:
            FirebaseFirestore.instance.collection('posts').doc(postId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(context, 'Error loading post.');
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorState(context, 'Post not found.');
          }

          final post = Post.fromFirestore(snapshot.data!);

          // Successful load -> display content
          return _buildPostContent(context, post);
        },
      ),
    );
  }

  /// Unified error state display to avoid code repetition.
  Widget _buildErrorState(BuildContext context, String message) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Center(child: Text(message)),
    );
  }

  Widget _buildPostContent(BuildContext context, Post post) {
    final hasRoute = post.dailyRoutes != null && post.dailyRoutes!.isNotEmpty;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, post),
        SliverToBoxAdapter(
          child: AnimationLimiter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 500),
                  childAnimationBuilder: (widget) => SlideAnimation(
                    verticalOffset: 50.0, // Subtle animation
                    child: FadeInAnimation(child: widget),
                  ),
                  children: [
                    const SizedBox(height: 24),
                    _buildHeader(context, post),
                    const SizedBox(height: 24),
                    _buildStatsRow(context, post),
                    const SizedBox(height: 32),
                    _buildSection(
                      context,
                      title: "Story",
                      icon: Icons.article_outlined,
                      content: Text(
                        post.caption.isEmpty
                            ? "No story available."
                            : post.caption,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.7, // Better readability
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color
                                  ?.withOpacity(0.85),
                            ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSection(
                      context,
                      title: "Ratings",
                      icon: Icons.star_half_rounded,
                      content:
                          _buildRatingsList(post), // Dynamic ratings creation
                    ),
                    if (hasRoute) ...[
                      const SizedBox(height: 32),
                      _buildSection(
                        context,
                        title: "Route",
                        icon: Icons.route_outlined,
                        content: _buildRouteMap(context, post),
                      ),
                    ],
                    const SizedBox(height: 48), // Space at the end
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Revamped app bar: modern, minimal, and functional.
  Widget _buildSliverAppBar(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 350.0,
      pinned: true,
      stretch: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0, // Seamless transition to content
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share_outlined),
          onPressed: () {/* Share functionality */},
        ),
        IconButton(
          icon: const Icon(Icons.bookmark_border_rounded),
          onPressed: () {/* Save functionality */},
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (post.postImageUrl != null)
              Image.network(
                post.postImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.grey.shade800),
              )
            else
              Container(color: Colors.grey.shade800),
            // Subtle gradient to ensure icon visibility
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                    Colors.black.withOpacity(0.2),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Combined header area: Title and author info.
  Widget _buildHeader(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.title,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: 28, height: 1.2),
        ),
        const SizedBox(height: 16),
        _buildAuthorInfo(context, post),
      ],
    );
  }

  Widget _buildAuthorInfo(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundImage: post.userAvatarUrl.isNotEmpty
              ? NetworkImage(post.userAvatarUrl)
              : null,
          child: post.userAvatarUrl.isEmpty
              ? const Icon(Icons.person, size: 24)
              : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${post.username}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Published: ${DateFormat.yMMMd('en_US').format(post.timestamp)}',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ],
    );
  }

  /// Stats are now integrated directly into the content without a separate card.
  Widget _buildStatsRow(BuildContext context, Post post) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(context, Icons.hiking_rounded,
              '${post.distanceKm.toStringAsFixed(1)} km', 'Distance'),
          _buildStatItem(
              context,
              Icons.night_shelter_outlined,
              '${post.nights} ${post.nights == 1 ? "night" : "nights"}',
              'Duration'),
          _buildStatItem(context, Icons.location_on_outlined,
              post.location.split(',').first, 'Location',
              isLocation: true),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context, IconData icon, String value, String label,
      {bool isLocation = false}) {
    final theme = Theme.of(context);
    return Flexible(
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: isLocation ? 2 : 1),
          const SizedBox(height: 2),
          Text(label,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
        ],
      ),
    );
  }

  /// Generic section builder.
  Widget _buildSection(BuildContext context,
      {required String title,
      required IconData icon,
      required Widget content}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon,
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7)),
            const SizedBox(width: 12),
            Text(title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 4.0), // Indent content
          child: content,
        ),
      ],
    );
  }

  /// Refactored ratings display: dynamic and clean.
  Widget _buildRatingsList(Post post) {
    // Convert Map to a List to maintain order
    final ratings = [
      MapEntry(
          RatingType.experience, post.ratings[RatingType.experience] ?? 0.0),
      MapEntry(
          RatingType.difficulty, post.ratings[RatingType.difficulty] ?? 0.0),
      MapEntry(RatingType.weather, post.ratings[RatingType.weather] ?? 0.0),
    ];

    return Column(
      children: ratings.map((entry) {
        final ratingType = entry.key;
        final ratingValue = entry.value;
        final ratingData = getRatingData(ratingType);
        final label = ratingData['labels'][(ratingValue).toInt()] ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: DetailedRatingDisplay(
            icon: ratingData['icon'],
            title: ratingData['title'],
            label: label,
            ratingValue: ratingValue,
          ),
        );
      }).toList(),
    );
  }

  /// Visually improved map preview.
  Widget _buildRouteMap(BuildContext context, Post post) {
    final allPoints =
        post.dailyRoutes!.expand((route) => route.points).toList();
    final bounds = LatLngBounds.fromPoints(allPoints);
    final arrowMarkers = generateArrowMarkersForDays(post.dailyRoutes!);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FullScreenMapPage(routes: post.dailyRoutes!),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 250,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(
                          40.0), // Add padding around bounds
                    ),
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    ),
                    PolylineLayer(
                      polylines: post.dailyRoutes!
                          .map((route) => Polyline(
                                points: route.points,
                                color: route.routeColor.withOpacity(0.9),
                                strokeWidth: 4.5,
                                borderColor: Colors.black.withOpacity(0.2),
                                borderStrokeWidth: 1.5,
                              ))
                          .toList(),
                    ),
                    MarkerLayer(markers: arrowMarkers),
                  ],
                ),
              ),
              // Prompt to make interaction clearer
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_out_map_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tap to explore map',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
