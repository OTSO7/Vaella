// lib/widgets/user_posts_section.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/post_model.dart';
import 'post_thumbnail_card.dart';

class UserPostsSection extends StatefulWidget {
  final String userId;
  final Function(int) onPostsLoaded;

  const UserPostsSection({
    super.key,
    required this.userId,
    required this.onPostsLoaded,
  });

  @override
  State<UserPostsSection> createState() => _UserPostsSectionState();
}

class _UserPostsSectionState extends State<UserPostsSection> {
  late Future<List<Post>> _userPostsFuture;

  @override
  void initState() {
    super.initState();
    _userPostsFuture = _fetchUserPosts();
  }

  @override
  void didUpdateWidget(covariant UserPostsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      setState(() {
        _userPostsFuture = _fetchUserPosts();
      });
    }
  }

  Future<List<Post>> _fetchUserPosts() async {
    if (widget.userId.isEmpty) {
      widget.onPostsLoaded(0);
      return [];
    }
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        widget.onPostsLoaded(0);
        return [];
      }
      final posts = querySnapshot.docs
          .map((doc) {
            try {
              return Post.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>);
            } catch (e) {
              // print('Error parsing post document ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Post>()
          .toList();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onPostsLoaded(posts.length);
        }
      });
      return posts;
    } catch (e) {
      // print('Critical error fetching user posts for ${widget.userId}: $e\nStackTrace: $stackTrace');
      if (mounted) {
        widget.onPostsLoaded(0);
      }
      throw Exception(
          'Failed to load posts. Please check your connection or try again later.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Post>>(
      future: _userPostsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.cloud_off_rounded,
                      color: theme.colorScheme.error, size: 48),
                  const SizedBox(height: 16),
                  Text('Could not load posts',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          color: theme.colorScheme.error,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                      snapshot.error.toString().replaceFirst("Exception: ", ""),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                          color: theme.hintColor, fontSize: 14)),
                ]),
              ),
            ),
          );
        }
        final posts = snapshot.data;
        if (posts == null || posts.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
              widget.onPostsLoaded(0);
            }
          });
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.photo_library_outlined,
                    size: 50, color: theme.hintColor.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text('No posts yet.',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Create your first adventure post!',
                    style:
                        GoogleFonts.lato(fontSize: 14, color: theme.hintColor),
                    textAlign: TextAlign.center),
              ])),
            ),
          );
        }
        return SliverPadding(
          padding:
              const EdgeInsets.all(4.0), // Lisätty yleinen padding ruudukolle
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4.0, // KORJATTU: Lisätty välistystä
              mainAxisSpacing: 4.0, // KORJATTU: Lisätty välistystä
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final post = posts[index];
                return PostThumbnailCard(
                  post: post,
                  onTap: () {
                    // TODO: Navigoi julkaisun yksityiskohtaiseen näkymään
                    // Esim. context.push('/post/${post.id}');
                  },
                );
              },
              childCount: posts.length,
            ),
          ),
        );
      },
    );
  }
}
