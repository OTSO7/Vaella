// lib/widgets/post_card.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/post_model.dart';
import 'star_rating_display.dart';

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

  @override
  void initState() {
    super.initState();
    initializeDateFormatting();
    _updateStateFromWidget();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id) {
      _updateStateFromWidget();
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

  Future<void> _deletePost() async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .delete();
      widget.onPostDeleted?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error deleting post: $e')));
      }
    }
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
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
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
    bool isOwnPost = widget.currentUserId == widget.post.userId;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: widget.isSelected
            ? Border.all(color: theme.colorScheme.primary, width: 2.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isSelected ? 0.15 : 0.08),
            blurRadius: widget.isSelected ? 12 : 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap:
                widget.onTap ?? () => context.push('/post/${widget.post.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isOwnPost),
                if (widget.post.postImageUrl != null) _buildImage(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    widget.post.title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildInfoBar(context),
                Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 16,
                    endIndent: 16,
                    color: theme.dividerColor.withOpacity(0.5)),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, curve: Curves.easeOutCubic);
  }

  Widget _buildHeader(BuildContext context, bool isOwnPost) {
    return ListTile(
      onTap: () => context.push('/profile/${widget.post.userId}'),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Theme.of(context).cardColor,
        backgroundImage: widget.post.userAvatarUrl.isNotEmpty
            ? CachedNetworkImageProvider(widget.post.userAvatarUrl)
            : null,
        child: widget.post.userAvatarUrl.isEmpty
            ? const Icon(Icons.person_rounded)
            : null,
      ),
      title: Text(
        "@${widget.post.username}",
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        _getTimeAgo(widget.post.timestamp),
        style:
            GoogleFonts.lato(fontSize: 13, color: Theme.of(context).hintColor),
      ),
      trailing: isOwnPost ? _buildMoreOptionsButton(context) : null,
      contentPadding:
          const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
    );
  }

  Widget _buildImage() {
    return Hero(
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
    );
  }

  Widget _buildInfoBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoBarItem(
            context,
            icon: Icons.hiking_rounded,
            value: widget.post.distanceKm.toStringAsFixed(1),
            unit: 'km',
          ),
          _buildInfoBarItem(
            context,
            icon: Icons.night_shelter_outlined,
            value: '${widget.post.nights}',
            unit: widget.post.nights == 1 ? 'night' : 'nights',
          ),
          Column(
            children: [
              StarRatingDisplay(
                rating: widget.post.averageRating,
                showLabel: false,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text('Rating',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoBarItem(BuildContext context,
      {required IconData icon, required String value, required String unit}) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.secondary, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(unit,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
      ],
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
                // **KORJATTU**: Poistettu 'const' tästä.
                icon: Icon(Icons.mode_comment_outlined,
                    color: theme.colorScheme.onSurfaceVariant),
                tooltip: "Comment",
                onPressed: () => context.push('/post/${widget.post.id}'),
              ),
              Text('${widget.post.commentCount}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          IconButton(
            // **KORJATTU**: Poistettu 'const' tästä.
            icon: Icon(Icons.share_outlined,
                color: theme.colorScheme.onSurfaceVariant),
            tooltip: "Share",
            onPressed: () {/* Jaa-toiminnallisuus tähän */},
          ),
        ],
      ),
    );
  }

  Widget _buildMoreOptionsButton(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded,
          color: color ?? theme.colorScheme.onSurfaceVariant),
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
