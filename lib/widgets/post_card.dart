// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final timeAgo = _getTimeAgo(post.timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header: Avatar, Username, Location, Options
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 12.0, 8.0),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(post.userAvatarUrl),
                    backgroundColor:
                        theme.colorScheme.secondary.withOpacity(0.5),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.username,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            fontSize: 17,
                          ),
                        ),
                        if (post.location.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 15,
                                    color: theme.colorScheme.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  post.location,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_horiz,
                        color: theme.colorScheme.onSurface.withOpacity(0.8)),
                    onPressed: () {
                      _showFeatureComingSoon(context, "Post settings");
                    },
                  ),
                ],
              ),
            ),

            // Post Image (if available)
            if (post.postImageUrl != null && post.postImageUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  post.postImageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (BuildContext context, Widget child,
                      ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: theme.colorScheme.secondary,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[850],
                    child: Icon(Icons.broken_image,
                        color: Colors.grey[600], size: 40),
                  ),
                ),
              ),
            if (post.postImageUrl != null && post.postImageUrl!.isNotEmpty)
              const SizedBox(height: 12.0),

            // Caption
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16.0,
                  post.postImageUrl != null && post.postImageUrl!.isNotEmpty
                      ? 0.0
                      : 12.0,
                  16.0,
                  12.0),
              child: Text(
                post.caption,
                style: textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.95),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
            // Divider before actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(
                  color: theme.colorScheme.onSurface.withOpacity(0.15),
                  height: 1),
            ),
            const SizedBox(height: 8.0),

            // Footer: Actions (Likes, Comments, Share), Timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _buildActionButton(
                          context, Icons.favorite_border, post.likes.toString(),
                          () {
                        _showFeatureComingSoon(context, "Like feature");
                      }),
                      const SizedBox(width: 16.0),
                      _buildActionButton(context, Icons.chat_bubble_outline,
                          post.comments.toString(), () {
                        _showFeatureComingSoon(context, "Comment feature");
                      }),
                      const SizedBox(width: 16.0),
                      _buildActionButton(context, Icons.share_outlined, "Share",
                          () {
                        _showFeatureComingSoon(context, "Share feature");
                      }),
                    ],
                  ),
                  Text(
                    timeAgo,
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label,
      VoidCallback onPressed) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        splashColor: theme.colorScheme.primary.withOpacity(0.2),
        highlightColor: theme.colorScheme.primary.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon,
                  size: 22.0,
                  color: theme.colorScheme.onSurface.withOpacity(0.75)),
              const SizedBox(width: 6.0),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.75),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) {
      return DateFormat('d MMM', 'en_US').format(dateTime);
    } else if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} min ago';
    } else {
      return 'Just now';
    }
  }

  void _showFeatureComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName is not implemented yet.'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
