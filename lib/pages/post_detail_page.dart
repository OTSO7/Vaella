import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/post_model.dart';
import '../widgets/star_rating_display.dart';

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
    _isLiked = post.likes
        .contains("CURRENT_USER_ID"); // TODO: Replace with real user id
    FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .update({'views': (post.views + 1)});
    return post.copyWith(views: post.views + 1);
  }

  Future<void> _toggleLike(Post post) async {
    final userId = "CURRENT_USER_ID"; // TODO: Replace with real user id
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
          // _isLiked ja _likeCount päivitetään initStatessa ja toggleLikessa

          return Stack(
            children: [
              // Kansikuva
              _buildHeaderImage(context, post),
              // Sisältö
              DraggableScrollableSheet(
                initialChildSize: 0.68,
                minChildSize: 0.68,
                maxChildSize: 0.98,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            _buildUserCard(context, post),
                            const SizedBox(height: 18),
                            // Likes & Views minimalistisesti oikeaan yläkulmaan
                            Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // LIKE BUTTON tässä, helposti löydettävä mutta ei liian keskeinen
                                    GestureDetector(
                                      onTap: () => _toggleLike(post),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _isLiked
                                              ? theme.colorScheme.error
                                                  .withOpacity(0.13)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.favorite,
                                              color: _isLiked
                                                  ? theme.colorScheme.error
                                                  : theme.colorScheme.error
                                                      .withOpacity(0.7),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$_likeCount',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.error
                                                    .withOpacity(0.85),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    _miniStat(
                                      icon: Icons.visibility_outlined,
                                      count: post.views,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              post.title,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 25,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
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
                            _buildStatsBar(context, post),
                            const SizedBox(height: 18),
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
                            _buildRatingsSection(context, post),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Takaisin-nappi ja SHARE-nappi oikealle ylös
              Positioned(
                top: 36,
                left: 16,
                child: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.45),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
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

  Widget _buildHeaderImage(BuildContext context, Post post) {
    if (post.postImageUrl != null) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.42,
        width: double.infinity,
        child: Image.network(
          post.postImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Container(color: Colors.grey.shade800),
        ),
      );
    } else if (post.dailyRoutes != null && post.dailyRoutes!.isNotEmpty) {
      final allPoints = post.dailyRoutes!.expand((r) => r.points).toList();
      final bounds = LatLngBounds.fromPoints(allPoints);
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.42,
        width: double.infinity,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
                bounds: bounds, padding: const EdgeInsets.all(40)),
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.treknoteflutter',
            ),
            PolylineLayer(
              polylines: post.dailyRoutes!
                  .map((route) => Polyline(
                        points: route.points,
                        color: Colors.deepOrange.withOpacity(0.85),
                        strokeWidth: 5.0,
                        borderColor: Colors.black.withOpacity(0.2),
                        borderStrokeWidth: 1.5,
                      ))
                  .toList(),
            ),
          ],
        ),
      );
    } else {
      return Container(
        height: MediaQuery.of(context).size.height * 0.42,
        width: double.infinity,
        color: Colors.grey.shade200,
      );
    }
  }

  Widget _buildUserCard(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          backgroundImage: post.userAvatarUrl.isNotEmpty
              ? NetworkImage(post.userAvatarUrl)
              : null,
          child: post.userAvatarUrl.isEmpty
              ? Icon(Icons.person, color: theme.colorScheme.primary, size: 28)
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("@${post.username}",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: theme.colorScheme.onSurface)),
              Text(
                  "Published: ${DateFormat.yMMMd('en_US').format(post.timestamp)}",
                  style: GoogleFonts.lato(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text("Follow",
                style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () {
              // TODO: Follow logic
            },
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

  // Eye-candy ratings section
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
