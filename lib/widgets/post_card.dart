import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
import 'package:intl/date_symbol_data_local.dart'; // Import for initializeDateFormatting
import '../models/post_model.dart'; // Varmista, että Post-malli on tuotu

class PostCard extends StatefulWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  @override
  void initState() {
    super.initState();
    // Initialize date formatting for the 'fi_FI' locale
    // This needs to be called once, typically at app startup or before using DateFormat for a specific locale.
    // For this widget, calling it in initState is fine, but it's more efficient to do it globally if many widgets use it.
    initializeDateFormatting('fi_FI', null).then((_) {
      if (mounted) {
        setState(
            () {}); // Trigger a rebuild if formatting initializes after build
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final timeAgo = _getTimeAgo(widget.post.timestamp);
    final hikeDuration =
        '${widget.post.nights} yö${widget.post.nights != 1 ? 'tä' : ''}'; // Esim. "3 yötä"

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
                    backgroundImage: NetworkImage(widget.post.userAvatarUrl),
                    backgroundColor:
                        theme.colorScheme.secondary.withOpacity(0.5),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.username,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            fontSize: 17,
                          ),
                        ),
                        if (widget.post.location.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 15,
                                    color: theme.colorScheme.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  widget.post.location,
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
            if (widget.post.postImageUrl != null &&
                widget.post.postImageUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  widget.post.postImageUrl!,
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
            if (widget.post.postImageUrl != null &&
                widget.post.postImageUrl!.isNotEmpty)
              const SizedBox(height: 12.0),

            // NEW: Post Title
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16.0,
                  widget.post.postImageUrl != null &&
                          widget.post.postImageUrl!.isNotEmpty
                      ? 0.0
                      : 12.0,
                  16.0,
                  4.0),
              child: Text(
                widget.post.title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: 20,
                ),
              ),
            ),

            // NEW: Dates, Distance, Nights
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: theme.colorScheme.secondary),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('d.M.yyyy').format(widget.post.startDate)} - ${DateFormat('d.M.yyyy').format(widget.post.endDate)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.hiking_outlined,
                      size: 18, color: theme.colorScheme.secondary),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.post.distanceKm.toStringAsFixed(1)} km, $hikeDuration',
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // NEW: Optional shared data (Weight, Calories)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Wrap(
                spacing: 12.0, // horizontal space between chips
                runSpacing: 4.0, // vertical space between lines of chips
                children: [
                  if (widget.post.sharedData.contains('packing') &&
                      widget.post.weightKg != null)
                    _buildInfoChip(context, Icons.backpack_outlined,
                        '${widget.post.weightKg!.toStringAsFixed(1)} kg'),
                  if (widget.post.sharedData.contains('food') &&
                      widget.post.caloriesPerDay != null)
                    _buildInfoChip(context, Icons.restaurant_menu_outlined,
                        '${widget.post.caloriesPerDay!.round()} kcal/pv'),
                  // Add more shared data chips here if needed, e.g., 'route' for a map button
                ],
              ),
            ),

            // Caption
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
              child: Text(
                widget.post.caption.isNotEmpty
                    ? widget.post.caption
                    : 'Ei lisäkommenttia tähän vaellukseen.',
                style: textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.95),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),

            // NEW: Action buttons for "Route Map" and "Copy Plan"
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (widget.post.sharedData.contains('route'))
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showFeatureComingSoon(context, "Reittikartta"),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Reittikartta'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.secondary,
                          side: BorderSide(
                              color:
                                  theme.colorScheme.secondary.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  if (widget.post.sharedData.contains('route') &&
                      widget.post.planId != null)
                    const SizedBox(width: 12), // Space between buttons
                  if (widget.post.planId != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showFeatureComingSoon(
                            context, "Kopioi suunnitelma"),
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Kopioi suunnitelma'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                ],
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
                          context,
                          widget.post.likes.contains('current_user_id')
                              ? Icons.favorite
                              : Icons
                                  .favorite_border, // TODO: Replace with actual current user ID check
                          widget.post.likes.length.toString(), () {
                        _showFeatureComingSoon(context, "Like feature");
                      }),
                      const SizedBox(width: 16.0),
                      _buildActionButton(context, Icons.chat_bubble_outline,
                          widget.post.commentCount.toString(), () {
                        // FIXED: Changed post.comments to post.commentCount
                        _showFeatureComingSoon(context, "Comment feature");
                      }),
                      const SizedBox(width: 16.0),
                      _buildActionButton(context, Icons.share_outlined, "Jaa",
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

  // Helper for info chips (weight, calories)
  Widget _buildInfoChip(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
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
      // Ensure 'fi_FI' locale data is loaded for accurate formatting
      return DateFormat('d.M.yyyy', 'fi_FI').format(dateTime);
    } else if (diff.inDays >= 1) {
      return '${diff.inDays} pv sitten';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours} t sitten';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} min sitten';
    } else {
      return 'Juuri nyt';
    }
  }

  void _showFeatureComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName ei ole vielä toteutettu.'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
