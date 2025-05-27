// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Lisää intl-paketti pubspec.yaml-tiedostoon: dependencies: intl: ^0.19.0 (tai uusin)
// Aja 'flutter pub get' tämän jälkeen
import '../models/post_model.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = _getTimeAgo(post.timestamp);

    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: theme.colorScheme.surface
          .withOpacity(0.95), // Hieman läpikuultava kortin tausta
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header: Avatar, Username, Location, Options
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage(post.userAvatarUrl),
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.5),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.username,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (post.location.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14, color: theme.colorScheme.secondary),
                            const SizedBox(width: 4),
                            Text(
                              post.location,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert,
                      color: theme.colorScheme.onSurface.withOpacity(0.8)),
                  onPressed: () {
                    // TODO: Toteuta postausasetukset (esim. muokkaa, poista, ilmoita)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Postausasetuksia ei ole vielä toteutettu.')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            // Post Image (if available)
            if (post.postImageUrl != null && post.postImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: AspectRatio(
                  aspectRatio: 16 / 9, // Tai muu sopiva kuvasuhde
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
                    errorBuilder: (context, error, stackTrace) => AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: Colors.grey[800],
                        child: Icon(Icons.broken_image,
                            color: Colors.grey[600], size: 40),
                      ),
                    ),
                  ),
                ),
              ),
            if (post.postImageUrl != null && post.postImageUrl!.isNotEmpty)
              const SizedBox(height: 12.0),

            // Caption
            Text(
              post.caption,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.9),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10.0),
            Divider(color: theme.colorScheme.onSurface.withOpacity(0.1)),
            const SizedBox(height: 6.0),

            // Footer: Actions (Likes, Comments), Timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _buildActionButton(
                        context, Icons.favorite_border, post.likes.toString(),
                        () {
                      // TODO: Tykkäystoiminto
                    }),
                    const SizedBox(width: 16.0),
                    _buildActionButton(context, Icons.chat_bubble_outline,
                        post.comments.toString(), () {
                      // TODO: Kommenttitoiminto
                    }),
                    const SizedBox(width: 16.0),
                    _buildActionButton(context, Icons.share_outlined, "Jaa",
                        () {
                      // TODO: Jakotoiminto
                    }),
                  ],
                ),
                Text(
                  timeAgo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label,
      VoidCallback onPressed) {
    final theme = Theme.of(context);
    return InkWell(
      // InkWell antaa ripple-efektin
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        child: Row(
          children: <Widget>[
            Icon(icon,
                size: 20.0,
                color: theme.colorScheme.onSurface.withOpacity(0.7)),
            const SizedBox(width: 4.0),
            if (label.isNotEmpty &&
                int.tryParse(label) !=
                    null) // Näytä label vain jos se on numero
              Text(label,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) {
      return DateFormat('d MMM').format(dateTime); // Esim. "23 May"
    } else if (diff.inDays >= 1) {
      return '${diff.inDays} p sitten'; // "p" = päivää
    } else if (diff.inHours >= 1) {
      return '${diff.inHours} t sitten'; // "t" = tuntia
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} min sitten';
    } else {
      return 'Juuri nyt';
    }
  }
}
