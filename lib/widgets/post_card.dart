import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _likeLoading = false;
  bool _showRouteMap = false;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
          parent: _likeAnimationController, curve: Curves.easeInOut),
    );
    _updateStateFromWidget();
    _listenToLikes();
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id) {
      _updateStateFromWidget();
      _listenToLikes();
      _showRouteMap = false;
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
      final data = doc.data();
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

    // Trigger animation
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
    });

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
    if (diff.inDays > 7) return DateFormat('MMM d').format(dateTime);
    if (diff.inDays >= 1) return '${diff.inDays}d';
    if (diff.inHours >= 1) return '${diff.inHours}h';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOwnPost = widget.currentUserId == widget.post.userId;

    final String? mainImageUrl = (widget.post.postImageUrl != null &&
            widget.post.postImageUrl!.isNotEmpty)
        ? widget.post.postImageUrl
        : (widget.post.postImageUrls.isNotEmpty
            ? widget.post.postImageUrls.first
            : null);

    final bool hasRouteImage = widget.post.dailyRoutes != null &&
        widget.post.dailyRoutes!.isNotEmpty &&
        widget.post.dailyRoutes!.any((r) => (r.points as List).isNotEmpty);

    final bool hasPostImage = mainImageUrl != null && mainImageUrl.isNotEmpty;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProfile = authProvider.userProfile;
    final currentUserId = authProvider.user?.uid ?? "";
    final currentUsername = userProfile?.username ?? "";
    final currentUserAvatarUrl = userProfile?.photoURL ?? "";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: GestureDetector(
        onTap: widget.onTap ?? () => context.push('/post/${widget.post.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: widget.isSelected
                ? Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.22)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          context.push('/profile/${widget.post.userId}'),
                      child: UserAvatar(
                        userId: widget.post.userId,
                        radius: 20,
                        initialUrl: widget.post.userAvatarUrl,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        placeholderColor: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.post.username,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getTimeAgo(widget.post.timestamp),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.6),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOwnPost)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (context) => CupertinoActionSheet(
                              actions: [
                                CupertinoActionSheetAction(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    if (widget.onPostDeleted != null) {
                                      widget.onPostDeleted!();
                                    }
                                  },
                                  isDestructiveAction: true,
                                  child: const Text('Delete Post'),
                                ),
                              ],
                              cancelButton: CupertinoActionSheetAction(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                          );
                        },
                        child: Icon(
                          CupertinoIcons.ellipsis,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),

              // Clean Image/Map Display
              if (hasPostImage || hasRouteImage)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Stack(
                        children: [
                          Stack(
                            children: [
                              if (hasPostImage)
                                Positioned.fill(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    opacity: _showRouteMap ? 0.0 : 1.0,
                                    child: IgnorePointer(
                                      ignoring: _showRouteMap,
                                      child: CachedNetworkImage(
                                        key: const ValueKey('image'),
                                        imageUrl: mainImageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: theme.colorScheme.surfaceContainer.withOpacity(0.5),
                                          child: const Center(child: CupertinoActivityIndicator()),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: Icon(
                                            CupertinoIcons.photo,
                                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else if (!hasRouteImage)
                                Positioned.fill(
                                  child: Container(
                                    color: theme.colorScheme.surfaceContainer,
                                    child: const Center(
                                      child: Icon(CupertinoIcons.photo, size: 40),
                                    ),
                                  ),
                                ),
                              if (hasRouteImage)
                                Positioned.fill(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    opacity: _showRouteMap ? 1.0 : 0.0,
                                    child: IgnorePointer(
                                      ignoring: !_showRouteMap,
                                      child: _ModernRouteMap(
                                        dailyRoutes: widget.post.dailyRoutes!,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (hasPostImage && hasRouteImage)
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _showRouteMap = !_showRouteMap),
                                child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.black.withOpacity(0.7)
                                          : Colors.white.withOpacity(0.95),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      _showRouteMap
                                          ? CupertinoIcons.photo
                                          : CupertinoIcons.map,
                                      size: 20,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Content Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.post.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.3,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Location
                    if (widget.post.location.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.location_solid,
                            size: 14,
                            color: theme.colorScheme.primary.withOpacity(0.85),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.post.location,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.primary.withOpacity(0.85),
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Caption
                    if (widget.post.caption.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.post.caption,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.8),
                          height: 1.4,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Minimal Stats
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _MinimalStat(
                          value:
                              '${widget.post.distanceKm.toStringAsFixed(1)} km',
                          isDark: isDark,
                        ),
                        if (widget.post.nights > 0) ...[
                          _buildDot(isDark),
                          _MinimalStat(
                            value:
                                '${widget.post.nights} ${widget.post.nights == 1 ? 'night' : 'nights'}',
                            isDark: isDark,
                          ),
                        ],
                        if (widget.post.averageRating > 0) ...[
                          _buildDot(isDark),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.star_fill,
                                size: 14,
                                color: Colors.amber[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.post.averageRating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Clean Action Bar
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.dividerColor.withOpacity(0.06),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Like Button
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      onPressed: _toggleLike,
                      child: AnimatedBuilder(
                        animation: _likeAnimation,
                        builder: (context, child) => Transform.scale(
                          scale: _likeAnimation.value,
                          child: Row(
                            children: [
                              Icon(
                                _isLiked
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.heart,
                                color: _isLiked
                                    ? CupertinoColors.systemRed
                                    : theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.7),
                                size: 20,
                              ),
                              if (_likeCount > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '$_likeCount',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Comment Button
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(widget.post.id)
                          .snapshots(),
                      builder: (context, snapshot) {
                        int commentCount = widget.post.commentCount;
                        if (snapshot.hasData && snapshot.data!.data() != null) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          commentCount = (data['commentCount'] ?? 0) as int;
                        }
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          onPressed: () {
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
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.chat_bubble,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.7),
                                size: 20,
                              ),
                              if (commentCount > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '$commentCount',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),

                    // Share Button
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      onPressed: () {
                        // TODO: Implement share
                      },
                      child: Icon(
                        CupertinoIcons.share,
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                        size: 20,
                      ),
                    ),

                    // Save Button
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      onPressed: () {
                        // TODO: Implement save
                      },
                      child: Icon(
                        CupertinoIcons.bookmark,
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MinimalStat extends StatelessWidget {
  final String value;
  final bool isDark;

  const _MinimalStat({
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      value,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontSize: 14,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _ModernRouteMap extends StatelessWidget {
  final List<dynamic> dailyRoutes;

  const _ModernRouteMap({
    super.key,
    required this.dailyRoutes,
  });

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allPoints = _collectAllPoints();

    if (allPoints.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceContainer,
        child: Center(
          child: Icon(
            CupertinoIcons.map,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
            size: 40,
          ),
        ),
      );
    }

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(allPoints),
          padding: const EdgeInsets.all(40),
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
                    color: theme.colorScheme.primary.withOpacity(0.8),
                    strokeWidth: 3.5,
                    borderColor: isDark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.black.withOpacity(0.1),
                    borderStrokeWidth: 1.0,
                  ))
              .toList(),
        ),
        MarkerLayer(
          markers: [
            if (allPoints.isNotEmpty)
              Marker(
                point: allPoints.first,
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.location_fill,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            if (allPoints.length > 1)
              Marker(
                point: allPoints.last,
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.flag_fill,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
