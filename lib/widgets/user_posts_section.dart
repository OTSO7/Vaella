// lib/widgets/user_posts_section.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/post_model.dart';
import 'post_list_item.dart'; // UUSI WIDGET

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
          .map((doc) =>
              Post.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onPostsLoaded(posts.length);
        }
      });
      return posts;
    } catch (e) {
      if (mounted) {
        widget.onPostsLoaded(0);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Post>>(
      future: _userPostsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error loading posts: ${snapshot.error}"));
        }
        final posts = snapshot.data;
        if (posts == null || posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 50, color: theme.hintColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('No posts yet.',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        }

        // KORVATTU: GridView on nyt ListView.builder.
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          itemCount: posts.length,
          itemBuilder: (BuildContext context, int index) {
            final post = posts[index];
            // KORVATTU: Käytetään uutta PostListItem-widgettiä.
            return PostListItem(
              post: post,
              onTap: () {
                // Navigoi postauksen yksityiskohtaiseen näkymään
                context.push('/post/${post.id}');
              },
            );
          },
        );
      },
    );
  }
}
