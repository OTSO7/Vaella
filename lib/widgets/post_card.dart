// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../models/post_model.dart';
import '../providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  bool _isLiked = false;
  int _likeCount = 0;
  String _currentLocale = 'en_US';
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likes.length;
    if (widget.currentUserId != null) {
      _isLiked = widget.post.likes.contains(widget.currentUserId);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.maybeLocaleOf(context);
    if (locale != null) {
      _currentLocale = locale.toLanguageTag();
      initializeDateFormatting(_currentLocale, null)
          .catchError((_) => initializeDateFormatting('en_US', null));
    } else {
      initializeDateFormatting('en_US', null);
    }
  }

  // --- Kaikki logiikkafunktiot (toggleLike, delete, jne.) pysyvät ennallaan ---
  void _toggleLike() {/* ... */}
  Future<void> _confirmDeletePost() async {/* ... */}
  Future<void> _deletePost() async {/* ... */}
  void _showFeatureComingSoon(BuildContext context, String featureName) {
    /* ... */
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final timeAgo = _getTimeAgo(widget.post.timestamp);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _isDeleting ? 0.4 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(context, theme, textTheme, timeAgo),
            const SizedBox(height: 8),
            _buildContent(context, theme, textTheme),
            const SizedBox(height: 12),
            if (widget.post.postImageUrl != null &&
                widget.post.postImageUrl!.isNotEmpty)
              _buildPostImage(context, theme),
            _buildActionButtonsFooter(context, theme),
            Padding(
              padding: const EdgeInsets.only(top: 12.0, left: 16, right: 16),
              child: Divider(
                  height: 1, color: theme.dividerColor.withOpacity(0.5)),
            )
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 450.ms)
          .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme,
      TextTheme textTheme, String timeAgo) {
    final bool isOwnPost = widget.currentUserId == widget.post.userId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => context.push('/profile/${widget.post.userId}'),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: widget.post.userAvatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(widget.post.userAvatarUrl)
                  : null,
              child: widget.post.userAvatarUrl.isEmpty
                  ? const Icon(Icons.person_outline_rounded, size: 22)
                  : null,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("@${widget.post.username}",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade300,
                        fontSize: 15),
                    overflow: TextOverflow.ellipsis),
                Text(timeAgo,
                    style: textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (isOwnPost)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
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
                          style: textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.error)),
                    ])),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, ThemeData theme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.post.title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  height: 1.3,
                  color: theme.colorScheme.onSurface)),
          if (widget.post.caption.isNotEmpty) ...[
            const SizedBox(height: 6.0),
            Text(widget.post.caption,
                style: textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.55)),
          ],
        ],
      ),
    );
  }

  Widget _buildPostImage(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: GestureDetector(
        onDoubleTap: _toggleLike,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: CachedNetworkImage(
            imageUrl: widget.post.postImageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (context, url) => Container(
                height: 300,
                color: theme.colorScheme.surfaceContainerLowest,
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.0, color: theme.colorScheme.primary))),
            errorWidget: (context, url, error) => Container(
              height: 300,
              color: theme.colorScheme.errorContainer.withOpacity(0.2),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image_outlined,
                        color: theme.colorScheme.onErrorContainer, size: 50),
                    const SizedBox(height: 10),
                    Text("Image failed to load",
                        style: GoogleFonts.lato(
                            color: theme.colorScheme.onErrorContainer)),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtonsFooter(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 0, 16.0, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: [
              _buildFooterButton(
                  theme,
                  _isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  _isLiked
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  _likeCount > 0 ? '$_likeCount' : '',
                  _toggleLike),
              _buildFooterButton(
                  theme,
                  Icons.mode_comment_outlined,
                  theme.colorScheme.onSurfaceVariant,
                  widget.post.commentCount > 0
                      ? '${widget.post.commentCount}'
                      : '',
                  () => _showFeatureComingSoon(context, "Comments")),
            ],
          ),
          _buildFooterButton(
              theme,
              Icons.share_outlined,
              theme.colorScheme.onSurfaceVariant,
              null,
              () => _showFeatureComingSoon(context, "Share")),
        ],
      ),
    );
  }

  Widget _buildFooterButton(ThemeData theme, IconData icon, Color iconColor,
      String? label, VoidCallback onPressed) {
    return TextButton.icon(
      style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          foregroundColor: iconColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0))),
      icon: Icon(icon, size: 22.0),
      label: Text(label ?? "",
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: iconColor, fontSize: 14)),
      onPressed: onPressed,
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays >= 7) {
      return DateFormat('d MMM', _currentLocale).format(dateTime);
    }
    if (diff.inDays > 1) {
      return '${diff.inDays} days ago';
    }
    if (diff.inDays == 1) {
      return 'Yesterday';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    }
    if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m ago';
    }
    return 'Just now';
  }
}
