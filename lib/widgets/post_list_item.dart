// lib/widgets/post_list_item.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';

class PostListItem extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const PostListItem({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool hasImage =
        post.postImageUrl != null && post.postImageUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Location
                      if (post.location.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.location_solid,
                              size: 12,
                              color: theme.colorScheme.primary.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                post.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Minimal stats
                      Row(
                        children: [
                          _buildStat(
                            context,
                            '${post.distanceKm.toStringAsFixed(1)} km',
                          ),
                          _buildDot(isDark),
                          _buildStat(
                            context,
                            DateFormat('MMM d').format(post.startDate),
                          ),
                          if (post.averageRating > 0) ...[
                            _buildDot(isDark),
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.star_fill,
                                  size: 12,
                                  color: Colors.amber[600],
                                ),
                                const SizedBox(width: 4),
                                _buildStat(
                                  context,
                                  post.averageRating.toStringAsFixed(1),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: post.postImageUrl!,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 70,
                            height: 70,
                            color: theme.colorScheme.surfaceContainer
                                .withOpacity(0.5),
                            child: const Center(
                              child: CupertinoActivityIndicator(radius: 10),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              _buildPlaceholder(theme, isDark),
                        )
                      : _buildPlaceholder(theme, isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, bool isDark) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[800]
            : theme.colorScheme.surfaceContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Icon(
        CupertinoIcons.photo,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
        size: 28,
      ),
    );
  }

  Widget _buildStat(BuildContext context, String value) {
    final theme = Theme.of(context);
    return Text(
      value,
      style: TextStyle(
        fontSize: 13,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildDot(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
