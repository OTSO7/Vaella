// lib/widgets/post_card.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../providers/auth_provider.dart';
import 'star_rating_display.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final String? currentUserId;
  final VoidCallback? onPostDeleted;

  const PostCard({
    super.key,
    required this.post,
    this.currentUserId,
    this.onPostDeleted,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  // ... (Luokan alku ja metodit pysyvät ennallaan) ...
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isDeleting = false;
  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likes.length;
    if (widget.currentUserId != null) {
      _isLiked = widget.post.likes.contains(widget.currentUserId);
    }
    initializeDateFormatting();
  }

  void _toggleLike() {
    if (widget.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please log in to like posts.")));
      return;
    }
    setState(() {
      if (_isLiked) {
        _likeCount--;
        _isLiked = false;
        widget.post.likes.remove(widget.currentUserId);
      } else {
        _likeCount++;
        _isLiked = true;
        widget.post.likes.add(widget.currentUserId!);
      }
    });
    FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
      'likes': widget.post.likes,
    });
  }

  Future<void> _confirmDeletePost() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deletePost();
            },
            child: Text('Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    setState(() => _isDeleting = true);
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .delete();
      if (widget.post.postImageUrl != null) {/* Kuvan poisto logiikka... */}
      Provider.of<AuthProvider>(context, listen: false)
          .handlePostDeletionSuccess();
      if (widget.onPostDeleted != null) {
        widget.onPostDeleted!();
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting post: $e')));
      setState(() => _isDeleting = false);
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) return DateFormat('d MMM y').format(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = _getTimeAgo(widget.post.timestamp);
    bool isOwnPost = widget.currentUserId == widget.post.userId;

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/post/${widget.post.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.post.postImageUrl != null)
              _buildImageHeader(context, timeAgo, isOwnPost),
            if (widget.post.postImageUrl == null)
              _buildNoImageHeader(context, timeAgo, isOwnPost),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.post.title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  if (widget.post.caption.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(widget.post.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5)),
                  ],
                ],
              ),
            ),

            // MUUTOS: Tässä on uusi, siistimpi info-palkki
            _buildInfoBar(context),

            Divider(
                height: 1,
                color: theme.dividerColor.withOpacity(0.5),
                indent: 16,
                endIndent: 16),
            _buildActionButtons(context),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, curve: Curves.easeOutCubic);
  }

  // LISÄTTY: Uusi metodi info-palkin rakentamiseen
  Widget _buildInfoBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoBarItem(context,
              icon: Icon(Icons.hiking_rounded,
                  color: theme.colorScheme.secondary),
              value: widget.post.distanceKm.toStringAsFixed(1),
              unit: 'km'),
          _buildInfoBarItem(context,
              icon: Icon(Icons.night_shelter_outlined,
                  color: theme.colorScheme.secondary),
              value: '${widget.post.nights}',
              unit: widget.post.nights == 1 ? 'night' : 'nights'),
          // Erillinen käsittely arvostelulle
          Column(
            children: [
              StarRatingDisplay(
                rating: widget.post.averageRating,
                showLabel: false,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.post.averageRating.toStringAsFixed(1)} Rating',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            ],
          )
        ],
      ),
    );
  }

  // LISÄTTY: Uusi apumetodi info-palkin osille
  Widget _buildInfoBarItem(BuildContext context,
      {required Icon icon, required String value, required String unit}) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(unit,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  // ... (Loput build-metodit ovat ennallaan)
  Widget _buildImageHeader(
      BuildContext context, String timeAgo, bool isOwnPost) {
    return Stack(
      children: [
        Hero(
          tag: 'post_image_${widget.post.id}',
          child: CachedNetworkImage(
            imageUrl: widget.post.postImageUrl!,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
                height: 220,
                color: Theme.of(context).colorScheme.surfaceContainerHighest),
            errorWidget: (context, url, error) => Container(
                height: 220,
                color: Colors.black,
                child: const Icon(Icons.broken_image,
                    color: Colors.white54, size: 50)),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                  Colors.black.withOpacity(0.8)
                ],
                stops: const [0.0, 0.4, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/profile/${widget.post.userId}'),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).cardColor,
                  backgroundImage: widget.post.userAvatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(widget.post.userAvatarUrl)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("@${widget.post.username}",
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(timeAgo,
                        style: GoogleFonts.lato(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              if (isOwnPost) _buildMoreOptionsButton(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoImageHeader(
      BuildContext context, String timeAgo, bool isOwnPost) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.push('/profile/${widget.post.userId}'),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).cardColor,
              backgroundImage: widget.post.userAvatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(widget.post.userAvatarUrl)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("@${widget.post.username}",
                    style: GoogleFonts.poppins(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text(timeAgo,
                    style: GoogleFonts.lato(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13)),
              ],
            ),
          ),
          if (isOwnPost)
            _buildMoreOptionsButton(context,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey(_isLiked),
                    color: _isLiked
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                tooltip: "Like",
                onPressed: _toggleLike,
              ),
              Text('$_likeCount',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined),
                tooltip: "Comment",
                onPressed: () {},
              ),
              Text('${widget.post.commentCount}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: "Share",
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMoreOptionsButton(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: color ?? Colors.white),
      onSelected: (value) {
        if (value == 'delete') _confirmDeletePost();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded,
                color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Text('Delete Post',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error)),
          ]),
        ),
      ],
    );
  }
}
