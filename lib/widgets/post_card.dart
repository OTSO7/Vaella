import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import 'star_rating_display.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'comments_bottom_sheet.dart';
import 'user_avatar.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final String? currentUserId;
  final VoidCallback? onPostDeleted;
  final bool isSelected;
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.post,
    this.currentUserId,
    this.onPostDeleted,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _likeLoading = false;

  // --- UUSI TILA: kumpi näkymä on aktiivinen ---
  bool _showRouteMap = false;

  @override
  void initState() {
    super.initState();
    _updateStateFromWidget();
    _listenToLikes();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id) {
      _updateStateFromWidget();
      _listenToLikes();
      _showRouteMap = false; // Resetoi näkymä kun postaus vaihtuu
    }
  }

  void _updateStateFromWidget() {
    _likeCount = widget.post.likes.length;
    if (widget.currentUserId != null) {
      _isLiked = widget.post.likes.contains(widget.currentUserId);
    } else {
      _isLiked = false;
    }
  }

  void _listenToLikes() {
    FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      final likes = List<String>.from(data['likes'] ?? []);
      setState(() {
        _likeCount = likes.length;
        _isLiked = widget.currentUserId != null &&
            likes.contains(widget.currentUserId);
      });
    });
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    if (widget.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please log in to like posts.")));
      return;
    }
    setState(() {
      _likeLoading = true;
    });

    final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.post.id);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final freshSnap = await transaction.get(postRef);
      final likes = List<String>.from(freshSnap['likes'] ?? []);
      bool isLikedNow = likes.contains(widget.currentUserId);

      if (isLikedNow) {
        likes.remove(widget.currentUserId);
      } else {
        likes.add(widget.currentUserId!);
      }
      transaction.update(postRef, {'likes': likes});
    });

    setState(() {
      _likeLoading = false;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwnPost = widget.currentUserId == widget.post.userId;

    final String? mainImageUrl = (widget.post.postImageUrl != null &&
            widget.post.postImageUrl!.isNotEmpty)
        ? widget.post.postImageUrl
        : (widget.post.postImageUrls.isNotEmpty
            ? widget.post.postImageUrls.first
            : null);

    final bool hasRouteImage = widget.post.dailyRoutes != null &&
        widget.post.dailyRoutes!.isNotEmpty &&
        widget.post.dailyRoutes!.any((r) =>
            r != null && r.points != null && (r.points as List).isNotEmpty);

    final bool hasPostImage = mainImageUrl != null && mainImageUrl.isNotEmpty;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProfile = authProvider.userProfile;
    final currentUserId = authProvider.user?.uid ?? "";
    final currentUsername = userProfile?.username ?? "";
    final currentUserAvatarUrl = userProfile?.photoURL ?? "";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: GestureDetector(
        onTap: widget.onTap ?? () => context.push('/post/${widget.post.id}'),
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? Colors.white
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: widget.isSelected
                    ? theme.colorScheme.primary.withOpacity(0.85)
                    : theme.dividerColor.withOpacity(0.10),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.07),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER: User, time, save, menu ---
                Padding(
                  padding: const EdgeInsets.only(
                      left: 18, right: 8, top: 14, bottom: 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            context.push('/profile/${widget.post.userId}'),
                        child: UserAvatar(
                          userId: widget.post.userId,
                          radius: 22,
                          initialUrl: widget.post.userAvatarUrl,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          placeholderColor: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "@${widget.post.username}",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.5,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              _getTimeAgo(widget.post.timestamp),
                              style: GoogleFonts.lato(
                                fontSize: 12.2,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.bookmark_border_rounded,
                            color: theme.colorScheme.primary, size: 26),
                        tooltip: "Save",
                        onPressed: () {
                          // TODO: Implement save
                        },
                      ),
                      if (isOwnPost)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              color: theme.colorScheme.onSurfaceVariant),
                          onSelected: (value) {
                            if (value == 'delete' &&
                                widget.onPostDeleted != null) {
                              widget.onPostDeleted!();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // --- LOCATION ---
                if (widget.post.location.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 20, right: 20, bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            widget.post.location,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                              fontSize: 15.5,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // --- IMAGE/ROUTE MAP SWITCHER ---
                if (hasPostImage && hasRouteImage)
                  Stack(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _showRouteMap
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: _RouteMapBackgroundFlutterMap7(
                                      dailyRoutes: widget.post.dailyRoutes!,
                                      borderRadius: 0,
                                      fitPoints: true,
                                    ),
                                  ),
                                ),
                              )
                            : Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: CachedNetworkImage(
                                      imageUrl: mainImageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                          color: theme
                                              .colorScheme.surfaceContainer),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                              color: theme
                                                  .colorScheme.surfaceVariant,
                                              child: const Icon(
                                                  Icons.broken_image_outlined)),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        right: 18,
                        bottom: 18,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _showRouteMap
                              ? _MiniImageSquare(
                                  imageUrl: mainImageUrl!,
                                  onTap: () {
                                    setState(() {
                                      _showRouteMap = false;
                                    });
                                  },
                                )
                              : _MiniRouteMapSquare(
                                  dailyRoutes: widget.post.dailyRoutes!,
                                  onTap: () {
                                    setState(() {
                                      _showRouteMap = true;
                                    });
                                  },
                                ),
                        ),
                      ),
                    ],
                  )
                else if (hasPostImage)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: mainImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                              color: theme.colorScheme.surfaceContainer),
                          errorWidget: (context, url, error) => Container(
                              color: theme.colorScheme.surfaceVariant,
                              child: const Icon(Icons.broken_image_outlined)),
                        ),
                      ),
                    ),
                  )
                else if (hasRouteImage)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _RouteMapBackgroundFlutterMap7(
                          dailyRoutes: widget.post.dailyRoutes!,
                          borderRadius: 0,
                          fitPoints: true,
                        ),
                      ),
                    ),
                  ),

                // --- TITLE & CAPTION ---
                Padding(
                  padding: const EdgeInsets.only(
                      left: 18, right: 18, top: 14, bottom: 2),
                  child: Text(
                    widget.post.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 19.5,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.post.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 18, right: 18, top: 2),
                    child: Text(
                      widget.post.caption,
                      style: GoogleFonts.lato(
                        fontSize: 15.2,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 16),
                // --- INFO ROW ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _infoIconText(
                        context,
                        icon: Icons.hiking_rounded,
                        text: "${widget.post.distanceKm.toStringAsFixed(1)} km",
                        color: theme.colorScheme.primary,
                      ),
                      if (widget.post.nights > 0)
                        _infoIconText(
                          context,
                          icon: Icons.night_shelter_outlined,
                          text: "${widget.post.nights} nights",
                          color: theme.colorScheme.secondary,
                        ),
                      if (widget.post.weightKg != null)
                        _infoIconText(
                          context,
                          icon: Icons.backpack,
                          text:
                              "${widget.post.weightKg!.toStringAsFixed(1)} kg",
                          color: theme.colorScheme.tertiary,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // --- Star review sijoitettu info rivin alle ---
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                  child: Row(
                    children: [
                      StarRatingDisplay(
                        rating: widget.post.averageRating,
                        showLabel: false,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.post.averageRating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(
                    color: theme.dividerColor.withOpacity(0.18),
                    thickness: 1,
                    height: 16,
                  ),
                ),
                // --- SOCIAL BAR ---
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Row(
                          children: [
                            Icon(
                              _isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_outline_rounded,
                              color: _isLiked
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                              size: 22,
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 22,
                              child: Text(
                                '$_likeCount',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text("Like", style: GoogleFonts.lato(fontSize: 14)),
                          ],
                        ),
                      ),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .doc(widget.post.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          int commentCount = widget.post.commentCount;
                          if (snapshot.hasData &&
                              snapshot.data!.data() != null) {
                            final data =
                                snapshot.data!.data() as Map<String, dynamic>;
                            commentCount = (data['commentCount'] ?? 0) as int;
                          }
                          return _socialAction(
                            icon: Icons.mode_comment_outlined,
                            color: theme.colorScheme.primary,
                            count: commentCount,
                            label: "Comment",
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.7,
                                  child: CommentsBottomSheet(
                                    postId: widget.post.id,
                                    currentUserId: currentUserId,
                                    currentUsername: currentUsername,
                                    currentUserAvatarUrl: currentUserAvatarUrl,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      _socialAction(
                        icon: Icons.share_outlined,
                        color: theme.colorScheme.primary.withOpacity(0.82),
                        label: "Share",
                        onTap: () {
                          // TODO: Implement share
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoIconText(BuildContext context,
      {required IconData icon, required String text, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 13.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialAction({
    required IconData icon,
    required Color color,
    int? count,
    String? label,
    VoidCallback? onTap,
  }) {
    const double numberWidth = 22;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          if (count != null) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: numberWidth,
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.lato(fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

// --- PIENI KARTTANELIÖ ---
class _MiniRouteMapSquare extends StatelessWidget {
  final List<dynamic>? dailyRoutes;
  final VoidCallback? onTap;

  const _MiniRouteMapSquare({required this.dailyRoutes, this.onTap});

  @override
  Widget build(BuildContext context) {
    final allPoints = dailyRoutes == null
        ? <LatLng>[]
        : dailyRoutes!
            .where((r) =>
                r != null && r.points != null && (r.points as List).isNotEmpty)
            .expand((r) => List<LatLng>.from(r.points ?? []))
            .toList();
    if (allPoints.isEmpty) {
      return const SizedBox(width: 54, height: 54);
    }
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 54,
          height: 54,
          child: FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(allPoints),
                padding: const EdgeInsets.all(8.0),
                maxZoom: 13,
                minZoom: 5,
              ),
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.treknoteflutter',
              ),
              PolylineLayer<Object>(
                polylines: dailyRoutes == null
                    ? []
                    : dailyRoutes!
                        .where((route) =>
                            route != null &&
                            route.points != null &&
                            (route.points as List).isNotEmpty)
                        .map((route) => Polyline<Object>(
                              points: List<LatLng>.from(route.points ?? []),
                              color: Colors.deepOrange.withOpacity(0.85),
                              strokeWidth: 3.0,
                              borderColor: Colors.black.withOpacity(0.18),
                              borderStrokeWidth: 1.0,
                            ))
                        .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- PIENI KUVA NELIÖ ---
class _MiniImageSquare extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onTap;

  const _MiniImageSquare({required this.imageUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 54,
          height: 54,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
                color: Theme.of(context).colorScheme.surfaceContainer),
            errorWidget: (context, url, error) => Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: const Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }
}

// flutter_map 7.x -yhteensopiva taustakarttawidget
class _RouteMapBackgroundFlutterMap7 extends StatelessWidget {
  final List<dynamic>? dailyRoutes;
  final double borderRadius;
  final bool fitPoints;

  const _RouteMapBackgroundFlutterMap7({
    super.key,
    required this.dailyRoutes,
    this.borderRadius = 16,
    this.fitPoints = false,
  });

  List<LatLng> _collectAllPoints() {
    if (dailyRoutes == null) return [];
    final List<LatLng> allPoints = [];
    for (var dr in dailyRoutes!) {
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
      return Container(color: Theme.of(context).colorScheme.surfaceContainer);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: FlutterMap(
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
            polylines: dailyRoutes == null
                ? []
                : dailyRoutes!
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
      ),
    );
  }
}
