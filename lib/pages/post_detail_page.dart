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
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('Postausta ei löytynyt.')));
          }
          if (snapshot.hasError) {
            return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('Virhe ladatessa postausta.')));
          }

          final post = Post.fromFirestore(snapshot.data!);

          if (post == null) {
            return Scaffold(
                appBar: AppBar(),
                body: const Center(
                    child: Text('Postauksen tietoja ei voitu lukea.')));
          }

          return _buildPostContent(context, post);
        },
      ),
    );
  }

  Widget _buildPostContent(BuildContext context, Post post) {
    final theme = Theme.of(context);
    final hasRoute = post.dailyRoutes != null && post.dailyRoutes!.isNotEmpty;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, post),
        SliverToBoxAdapter(
          child: AnimationLimiter(
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 500),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 75.0,
                  child: FadeInAnimation(
                    child: widget,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAuthorInfo(context, post),
                        const SizedBox(height: 24),
                        _buildStatsBar(context, post),
                        const Divider(height: 48, thickness: 0.5),
                        _buildSection(
                          context,
                          title: "Tarinani",
                          icon: Icons.article_outlined,
                          content: Text(
                            post.caption.isEmpty ? "Ei tarinaa." : post.caption,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                              color: theme.textTheme.bodyLarge?.color
                                  ?.withOpacity(0.85),
                            ),
                          ),
                        ),
                        const Divider(height: 48, thickness: 0.5),
                        _buildSection(
                          context,
                          title: "Arvostelut",
                          icon: Icons.star_half_rounded,
                          content: Column(
                            children: [
                              DetailedRatingDisplay(
                                icon: getRatingData(RatingType.weather)['icon'],
                                title:
                                    getRatingData(RatingType.weather)['title'],
                                label:
                                    getRatingData(RatingType.weather)['labels'][
                                            (post.ratings[RatingType.weather] ??
                                                    0.0)
                                                .toInt()] ??
                                        '',
                                ratingValue:
                                    post.ratings[RatingType.weather] ?? 0.0,
                              ),
                              const SizedBox(height: 16),
                              DetailedRatingDisplay(
                                icon: getRatingData(
                                    RatingType.difficulty)['icon'],
                                title: getRatingData(
                                    RatingType.difficulty)['title'],
                                label: getRatingData(
                                            RatingType.difficulty)['labels'][
                                        (post.ratings[RatingType.difficulty] ??
                                                0.0)
                                            .toInt()] ??
                                    '',
                                ratingValue:
                                    post.ratings[RatingType.difficulty] ?? 0.0,
                              ),
                              const SizedBox(height: 16),
                              DetailedRatingDisplay(
                                icon: getRatingData(
                                    RatingType.experience)['icon'],
                                title: getRatingData(
                                    RatingType.experience)['title'],
                                label: getRatingData(
                                            RatingType.experience)['labels'][
                                        (post.ratings[RatingType.experience] ??
                                                0.0)
                                            .toInt()] ??
                                    '',
                                ratingValue:
                                    post.ratings[RatingType.experience] ?? 0.0,
                              ),
                            ],
                          ),
                        ),
                        if (hasRoute) ...[
                          const Divider(height: 48, thickness: 0.5),
                          _buildSection(
                            context,
                            title: "Reitti",
                            icon: Icons.route_outlined,
                            content: _buildRouteMap(context, post),
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 300.0,
      pinned: true,
      stretch: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
        title: Text(
          post.title,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
        titlePadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
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
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorInfo(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: post.userAvatarUrl.isNotEmpty
              ? NetworkImage(post.userAvatarUrl)
              : null,
          child: post.userAvatarUrl.isEmpty ? const Icon(Icons.person) : null,
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
              'Julkaistu: ${DateFormat.yMMMd().format(post.timestamp)}',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsBar(BuildContext context, Post post) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(context, Icons.hiking_rounded,
                '${post.distanceKm.toStringAsFixed(1)} km', 'Matka'),
            _buildStatItem(context, Icons.night_shelter_outlined,
                '${post.nights} yötä', 'Kesto'),
            _buildStatItem(context, Icons.location_on_outlined,
                post.location.split(',').first, 'Sijainti',
                isLocation: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context, IconData icon, String value, String label,
      {bool isLocation = false}) {
    final theme = Theme.of(context);
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor)),
          ],
        ),
      ),
    );
  }

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
            Text(title, style: theme.textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 16),
        content,
      ],
    );
  }

  Widget _buildRouteMap(BuildContext context, Post post) {
    final List<LatLng> allPoints =
        post.dailyRoutes!.expand((route) => route.points).toList();
    final LatLngBounds bounds = LatLngBounds.fromPoints(allPoints);

    return GestureDetector(
      // KORJAUS TÄSSÄ: Tämä rivi pakottaa GestureDetectorin reagoimaan
      // napautuksiin koko alueellaan, myös läpinäkyvissä kohdissa.
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FullScreenMapPage(routes: post.dailyRoutes!),
          ),
        );
      },
      child: SizedBox(
        height: 250,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(24.0),
                    ),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    PolylineLayer(
                      polylines: post.dailyRoutes!
                          .map((route) => Polyline(
                                points: route.points,
                                color: route.routeColor,
                                strokeWidth: 4.0,
                                borderColor: Colors.black.withOpacity(0.4),
                                borderStrokeWidth: 1.5,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(8.0),
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: const Icon(Icons.fullscreen,
                      color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
