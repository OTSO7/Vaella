import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../models/post_model.dart';
import '../widgets/star_rating_display.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late Future<Post> _postFuture;
  bool _isLiked = false;
  int _likeCount = 0;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _postFuture = _fetchAndIncrementViews();
  }

  Future<Post> _fetchAndIncrementViews() async {
    final doc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .get();
    if (!doc.exists) throw Exception("Post not found");
    final post = Post.fromFirestore(doc);
    _likeCount = post.likes.length;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.user?.uid;
    _isLiked = uid != null && post.likes.contains(uid);
    FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .update({'views': (post.views + 1)});
    return post.copyWith(views: post.views + 1);
  }

  Future<void> _toggleLike(Post post) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.uid;
    if (userId == null) return;
    final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.postId);

    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likeCount--;
      } else {
        _isLiked = true;
        _likeCount++;
      }
    });

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final freshSnap = await transaction.get(postRef);
      final likes = List<String>.from(freshSnap['likes'] ?? []);
      if (_isLiked) {
        if (!likes.contains(userId)) likes.add(userId);
      } else {
        likes.remove(userId);
      }
      transaction.update(postRef, {'likes': likes});
    });
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) return DateFormat('d MMM y').format(dateTime);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  void _goToUserProfile(String userId) {
    // Force the opened profile page to display a back button even if it's the current user's profile
    context.push('/profile/$userId', extra: {'forceBack': true});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: FutureBuilder<Post>(
        future: _postFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final post = snapshot.data!;

          // Kuvakaruselli
          final List<String> images = [
            if (post.postImageUrl != null && post.postImageUrl!.isNotEmpty)
              post.postImageUrl!,
            ...post.postImageUrls.where((url) => url.isNotEmpty)
          ];
          final bool hasImages = images.isNotEmpty;
          final bool hasRoute = post.dailyRoutes != null &&
              post.dailyRoutes!.isNotEmpty &&
              post.dailyRoutes!.any((r) =>
                  r != null &&
                  r.points != null &&
                  (r.points as List).isNotEmpty);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                backgroundColor: theme.colorScheme.background,
                expandedHeight: MediaQuery.of(context).size.height * 0.42,
                pinned: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      hasImages
                          ? PageView.builder(
                              itemCount: images.length,
                              controller:
                                  PageController(initialPage: _currentImage),
                              onPageChanged: (i) =>
                                  setState(() => _currentImage = i),
                              itemBuilder: (context, i) => ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(36),
                                  bottomRight: Radius.circular(36),
                                ),
                                child: Image.network(
                                  images[i],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(color: Colors.grey.shade800),
                                ),
                              ),
                            )
                          : hasRoute
                              ? ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(36),
                                    bottomRight: Radius.circular(36),
                                  ),
                                  child: _RouteMapBackground(
                                    dailyRoutes: post.dailyRoutes!,
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: Icon(Icons.image_not_supported,
                                        size: 60, color: Colors.grey.shade400),
                                  ),
                                ),
                      // Kuvakarusellin indikaattorit
                      if (hasImages && images.length > 1)
                        Positioned(
                          bottom: 18,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              images.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentImage == i ? 22 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentImage == i
                                      ? theme.colorScheme.primary
                                      : Colors.white.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Gradient overlay
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(36),
                                bottomRight: Radius.circular(36),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black54,
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black38,
                                ],
                                stops: [0, 0.25, 0.7, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Yläosan overlay: takaisin ja tykkäys
                      Positioned(
                        top: 36,
                        left: 16,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.45),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 36,
                        right: 16,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.45),
                          child: IconButton(
                            icon: const Icon(Icons.ios_share, color: Colors.white),
                            onPressed: () {
                              // TODO: Share logic
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Sisältö
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Käyttäjäkortti
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(22),
                        color: theme.colorScheme.surface,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: theme.colorScheme.surface,
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => _goToUserProfile(post.userId),
                                borderRadius: BorderRadius.circular(30),
                                child: UserAvatar(
                                  userId: post.userId,
                                  radius: 26,
                                  initialUrl: post.userAvatarUrl,
                                  backgroundColor: theme
                                      .colorScheme.surfaceContainerHighest,
                                  placeholderColor: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _goToUserProfile(post.userId),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("@${post.username}",
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                            color:
                                                theme.colorScheme.onSurface)),
                                    Text(_getTimeAgo(post.timestamp),
                                        style: GoogleFonts.lato(
                                            fontSize: 12.5,
                                            color: theme
                                                .colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Opacity(
                                    opacity: 0.7,
                                    child: _miniStat(
                                      icon: Icons.visibility_outlined,
                                      count: post.views,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  InkWell(
                                    onTap: () => _toggleLike(post),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _isLiked ? Icons.favorite : Icons.favorite_outline,
                                            color: _isLiked ? theme.colorScheme.error : theme.colorScheme.secondary,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$_likeCount',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700,
                                              color: _isLiked ? theme.colorScheme.error : theme.colorScheme.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      // Otsikko
                      Text(
                        post.title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Sijainti ja päiväys
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              post.location,
                              style: GoogleFonts.lato(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                  fontSize: 15.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            DateFormat('d MMM y').format(post.timestamp),
                            style: GoogleFonts.lato(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Tilastot
                      _buildStatsBar(context, post),
                      const SizedBox(height: 18),
                      // Kuvaus
                      if (post.caption.isNotEmpty)
                        Text(
                          post.caption,
                          style: GoogleFonts.lato(
                            fontSize: 16.5,
                            color: theme.colorScheme.onSurface,
                            height: 1.7,
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Arvostelut
                      _buildRatingsSection(context, post),
                      const SizedBox(height: 24),
                      // Kommentit-nappi
                      Center(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 12),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.mode_comment_outlined),
                          label: Text("View Comments (${post.commentCount})",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.7,
                                child: CommentsBottomSheet(
                                  postId: post.id,
                                  currentUserId: Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '',
                                  currentUsername: Provider.of<AuthProvider>(context, listen: false).userProfile?.username ?? post.username,
                                  currentUserAvatarUrl: Provider.of<AuthProvider>(context, listen: false).userProfile?.photoURL ?? post.userAvatarUrl,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      // --- ROUTE MAP KORTTI ---
                      if (hasRoute)
                        Card(
                          elevation: 4,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22)),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              height: 200,
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _RouteMapBackground(
                                  dailyRoutes: post.dailyRoutes!,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!hasRoute)
                        Center(
                          child: Text(
                            "No route data for this hike.",
                            style: GoogleFonts.lato(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _miniStat({
    required IconData icon,
    required int count,
    required Color color,
    bool filled = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: filled ? color : color.withOpacity(0.7),
          size: 19,
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.85),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statItem(
              Icons.hiking_rounded,
              "${post.distanceKm.toStringAsFixed(1)} km",
              theme.colorScheme.primary),
          if (post.nights > 0)
            _statItem(Icons.night_shelter_outlined, "${post.nights} nights",
                theme.colorScheme.secondary),
          if (post.weightKg != null)
            _statItem(Icons.backpack, "${post.weightKg!.toStringAsFixed(1)} kg",
                theme.colorScheme.tertiary),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 5),
        Text(text,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: color, fontSize: 14)),
      ],
    );
  }

  Widget _buildRatingsSection(BuildContext context, Post post) {
    final theme = Theme.of(context);

    String experienceHint(double v) {
      if (v >= 4.5) return "Amazing";
      if (v >= 3.5) return "Great";
      if (v >= 2.5) return "OK";
      if (v >= 1.5) return "Meh";
      return "Poor";
    }

    String difficultyHint(double v) {
      if (v >= 4.5) return "Extreme";
      if (v >= 3.5) return "Hard";
      if (v >= 2.5) return "Moderate";
      if (v >= 1.5) return "Easy";
      return "Very Easy";
    }

    String weatherHint(double v) {
      if (v >= 4.5) return "Perfect";
      if (v >= 3.5) return "Good";
      if (v >= 2.5) return "Mixed";
      if (v >= 1.5) return "Challenging";
      return "Bad";
    }

    Widget ratingTile({
      required IconData icon,
      required String label,
      required double rating,
      required String hint,
      required Color color,
    }) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.93),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.13), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.13),
              child: Icon(icon, color: color, size: 22),
              radius: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                        color: theme.colorScheme.onSurface,
                      )),
                  Text(
                    hint,
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StarRatingDisplay(
              rating: rating,
              size: 20,
              showLabel: false,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              rating.toStringAsFixed(1),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ratingTile(
          icon: Icons.emoji_events_rounded,
          label: "Overall Experience",
          rating: post.averageRating,
          color: theme.colorScheme.primary,
          hint: experienceHint(post.averageRating),
        ),
        ratingTile(
          icon: Icons.terrain_rounded,
          label: "Hike Difficulty",
          rating: post.ratings['difficulty'] ?? 0,
          color: Colors.orange,
          hint: difficultyHint(post.ratings['difficulty'] ?? 0),
        ),
        ratingTile(
          icon: Icons.wb_sunny_rounded,
          label: "Weather Conditions",
          rating: post.ratings['weather'] ?? 0,
          color: Colors.blueAccent,
          hint: weatherHint(post.ratings['weather'] ?? 0),
        ),
      ],
    );
  }
}

// --- ROUTE MAP KOMPONENTTI ---
class _RouteMapBackground extends StatelessWidget {
  final List<dynamic> dailyRoutes;

  const _RouteMapBackground({required this.dailyRoutes});

  List<LatLng> _collectAllPoints() {
    final List<LatLng> allPoints = [];
    for (var dr in dailyRoutes) {
      if (dr == null || dr.points == null) continue;
      if (dr.points is List<LatLng>) {
        allPoints.addAll(dr.points);
      } else if (dr.points is List) {
        for (var p in dr.points) {
          if (p is LatLng) {
            allPoints.add(p);
          } else if (p is List && p.length == 2) {
            allPoints.add(LatLng(p[0] as double, p[1] as double));
          }
        }
      }
    }
    return allPoints;
  }

  @override
  Widget build(BuildContext context) {
    final allPoints = _collectAllPoints();
    if (allPoints.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Center(
          child: Icon(Icons.route, color: Colors.grey.shade400, size: 40),
        ),
      );
    }

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(allPoints),
          padding: const EdgeInsets.all(30.0),
          maxZoom: 15,
          minZoom: 5,
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.treknoteflutter',
        ),
        PolylineLayer<Object>(
          polylines: dailyRoutes
              .where((route) =>
                  route != null &&
                  route.points != null &&
                  (route.points as List).isNotEmpty)
              .map((route) => Polyline<Object>(
                    points: List<LatLng>.from(route.points ?? []),
                    color: Colors.deepOrange.withOpacity(0.85),
                    strokeWidth: 5.0,
                    borderColor: Colors.black.withOpacity(0.18),
                    borderStrokeWidth: 1.3,
                  ))
              .toList(),
        ),
        MarkerLayer(
          markers: [
            if (allPoints.isNotEmpty)
              Marker(
                point: allPoints.first,
                width: 24,
                height: 24,
                child: Icon(Icons.place,
                    color: Colors.green.shade600,
                    size: 22,
                    shadows: [
                      Shadow(
                          color: Colors.black.withOpacity(0.7),
                          blurRadius: 4,
                          offset: Offset(0, 1))
                    ]),
              ),
            if (allPoints.length > 1)
              Marker(
                point: allPoints.last,
                width: 24,
                height: 24,
                child: Icon(Icons.flag_rounded,
                    color: Colors.red.shade700,
                    size: 22,
                    shadows: [
                      Shadow(
                          color: Colors.black.withOpacity(0.7),
                          blurRadius: 4,
                          offset: Offset(0, 1))
                    ]),
              ),
          ],
        ),
      ],
    );
  }
}
