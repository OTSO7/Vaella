// lib/pages/user_posts_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // Lisätty Provider
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import '../providers/auth_provider.dart'; // Lisätty AuthProvider

class UserPostsListPage extends StatefulWidget {
  final String userId;
  final String? username;

  const UserPostsListPage({
    super.key,
    required this.userId,
    this.username,
  });

  @override
  State<UserPostsListPage> createState() => _UserPostsListPageState();
}

class _UserPostsListPageState extends State<UserPostsListPage> {
  // Future<List<Post>> _userPostsFuture; // Ei enää Future, vaan paikallinen lista
  List<Post> _localPosts = []; // Paikallinen lista postausten hallintaan
  bool _isLoading = true; // Tila lataukselle
  String? _errorMessage; // Tila virheviestille

  @override
  void initState() {
    super.initState();
    _fetchUserPostsAndSetLocal();
  }

  Future<void> _fetchUserPostsAndSetLocal() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.userId.isEmpty) {
      if (mounted) {
        setState(() {
          _localPosts = [];
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _localPosts = [];
            _isLoading = false;
          });
        }
        return;
      }

      List<Post> posts = [];
      for (var doc in querySnapshot.docs) {
        try {
          posts.add(Post.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>));
        } catch (e) {
          // Virhe yksittäisen dokumentin parsimisessa, logitetaan ja jatketaan
          // print('UserPostsListPage: Error parsing post document ${doc.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _localPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Failed to load posts. Error: ${e.toString().split(':').first.trim()}.';
        });
      }
    }
  }

  // Callback-metodi, joka poistaa postauksen paikallisesta listasta ja päivittää UI:n
  void _handlePostDeletedInList(String postId) {
    if (mounted) {
      setState(() {
        _localPosts.removeWhere((post) => post.id == postId);
      });
      // AuthProvider.handlePostDeletionSuccess() on jo kutsuttu PostCardin sisällä,
      // joten postsCount päivittyy erikseen ProfilePagella.
    }
  }

  Future<void> _refreshPosts() async {
    // print("UserPostsListPage: Refreshing posts..."); // DEBUG
    await _fetchUserPostsAndSetLocal(); // Hae data uudelleen

    if (mounted && _errorMessage == null) {
      // Näytä SnackBar vain jos ei virhettä
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Posts refreshed!', style: GoogleFonts.lato()),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarTitle =
        widget.username != null ? "@${widget.username}'s Posts" : "User Posts";
    final authProvider = Provider.of<AuthProvider>(context,
        listen: false); // Ei tarvitse kuunnella, haetaan vain kerran
    final String? currentLoggedInUserId = authProvider.user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Builder(
          // Käytä Builderia, jotta tilat ovat selkeät
          builder: (context) {
            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_errorMessage != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('Could not load posts',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.error),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(_errorMessage!,
                          style: GoogleFonts.lato(
                              fontSize: 14, color: theme.hintColor),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }

            if (_localPosts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.feed_outlined,
                          size: 50, color: theme.hintColor.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('No posts from this user yet.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 17,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              itemCount: _localPosts.length,
              itemBuilder: (context, index) {
                final post = _localPosts[index];
                return PostCard(
                  key: ValueKey(
                      post.id), // Tärkeä avain listan oikeaan päivitykseen
                  post: post,
                  currentUserId:
                      currentLoggedInUserId, // Välitä nykyisen käyttäjän ID
                  onPostDeleted: () {
                    // Välitä callback
                    _handlePostDeletedInList(post.id);
                  },
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 12.0),
            );
          },
        ),
      ),
    );
  }
}
