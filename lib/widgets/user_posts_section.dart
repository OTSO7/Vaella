// lib/widgets/user_posts_section.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/post_model.dart';

class UserPostsSection extends StatefulWidget {
  final String userId;

  const UserPostsSection({super.key, required this.userId});

  @override
  State<UserPostsSection> createState() => _UserPostsSectionState();
}

class _UserPostsSectionState extends State<UserPostsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(theme);
        }

        final posts =
            snapshot.data!.docs.map((doc) => Post.fromFirestore(doc)).toList();

        return GridView.builder(
          padding: const EdgeInsets.all(2.0), // Pieni väli ruudukon reunoille
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            // Koko ruutu on nyt klikattava
            return GestureDetector(
              onTap: () => context.push('/post/${post.id}'),
              child: _buildPostTile(post, theme),
            );
          },
        );
      },
    );
  }

  // --- UUSI WIDGET POSTAUSRUUDUN LUOMISEEN ---
  /// Tämä widget päättää, näytetäänkö kuva vai informaatiokortti.
  Widget _buildPostTile(Post post, ThemeData theme) {
    final imageUrl = post.postImageUrl;

    // JOS KUVA ON OLEMASSA:
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          return progress == null
              ? child
              : Container(color: theme.colorScheme.surfaceVariant);
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: theme.colorScheme.surfaceVariant,
            child: Icon(Icons.broken_image_outlined, color: theme.hintColor),
          );
        },
      );
    }

    // JOS KUVAA EI OLE, NÄYTETÄÄN INFORMAATIOKORTTI:
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal.shade400,
            Colors.teal.shade800,
          ],
        ),
      ),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            Icons.map_outlined,
            color: Colors.white.withOpacity(0.8),
            size: 20,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  shadows: [
                    const Shadow(
                        blurRadius: 4,
                        color: Colors.black38,
                        offset: Offset(0, 1))
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${post.distanceKm.toStringAsFixed(1)} km',
                style: GoogleFonts.lato(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 50, color: theme.hintColor),
          const SizedBox(height: 16),
          Text('No Posts Yet',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w500)),
          Text('Share your first adventure!',
              style: GoogleFonts.lato(color: theme.hintColor)),
        ],
      ),
    );
  }
}
