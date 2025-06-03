// Korjattu HomePage, jossa ei näytetä turhia virheilmoituksia profiilin latauksessa

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../models/user_profile_model.dart';
import '../widgets/post_card.dart';
import '../pages/create_post_page.dart';
import '../widgets/select_visibility_modal.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Post> _posts = [];
  bool _isLoadingPosts = true;
  String? _errorMessage;
  StreamSubscription<List<Post>>? _postsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.addListener(_onAuthChanged);
        _onAuthChanged();
      }
    });
  }

  @override
  void dispose() {
    if (mounted) {
      try {
        Provider.of<AuthProvider>(context, listen: false)
            .removeListener(_onAuthChanged);
      } catch (_) {}
    }
    _postsSubscription?.cancel();
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn && authProvider.userProfile != null) {
      _startPostsStream(authProvider.userProfile!);
    } else {
      _postsSubscription?.cancel();
      if (mounted) {
        setState(() {
          _posts = [];
          _isLoadingPosts = false;
          _errorMessage = null;
        });
      }
    }
  }

  void _startPostsStream(UserProfile currentUserProfile) {
    _postsSubscription?.cancel();

    if (mounted) {
      setState(() {
        _isLoadingPosts = true;
        _errorMessage = null;
      });
    }

    final stream = _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Post.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList())
        .map((allPosts) => allPosts.where((post) {
              if (post.visibility == PostVisibility.public) return true;
              if (post.visibility == PostVisibility.private) {
                return post.userId == currentUserProfile.uid;
              }
              if (post.visibility == PostVisibility.friends) {
                return post.userId == currentUserProfile.uid ||
                    (currentUserProfile.followingIds.contains(post.userId));
              }
              return false;
            }).toList());

    _postsSubscription = stream.listen((posts) {
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoadingPosts = false;
          _errorMessage = null;
        });
      }
    }, onError: (_) {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
          _errorMessage = 'Error loading posts. Please try again.';
        });
      }
    });
  }

  Future<void> _refreshPosts() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn && authProvider.userProfile != null) {
      _startPostsStream(authProvider.userProfile!);
      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
          _errorMessage = null;
          _posts = [];
        });
      }
    }
    if (mounted && _errorMessage == null) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Posts refreshed!', style: GoogleFonts.lato()),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: theme.appBarTheme.elevation ?? 0.5,
        leading: authProvider.isLoggedIn
            ? IconButton(
                icon: Icon(Icons.logout_outlined,
                    color: theme.colorScheme.onSurfaceVariant),
                tooltip: "Log out",
                onPressed: () => authProvider.logout(),
              )
            : null,
        title: Hero(
          tag: 'appLogo',
          child: Image.asset('assets/images/white2.png',
              height: 35, fit: BoxFit.contain),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.search_outlined,
                color: theme.colorScheme.onSurfaceVariant),
            tooltip: "Search",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Search feature is not implemented yet.',
                      style: GoogleFonts.lato()),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(10),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Builder(
          builder: (context) {
            if (!authProvider.isLoggedIn) {
              return _buildEmptyState(
                icon: Icons.feed_outlined,
                title: 'Sign in to see hiking posts.',
              );
            }

            if (authProvider.userProfile == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_isLoadingPosts && _posts.isEmpty) {
              return Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary));
            }

            if (_errorMessage != null) {
              return _buildErrorState(_errorMessage!, theme);
            }

            if (_posts.isEmpty) {
              return _buildEmptyState(
                icon: Icons.feed_outlined,
                title: 'No posts to show right now.',
                subtitle: 'Follow others or create your first post!',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.only(top: 8.0, bottom: 90.0),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                return PostCard(key: ValueKey(post.id), post: post);
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 12.0),
            );
          },
        ),
      ),
      floatingActionButton: authProvider.isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: () {
                final currentAuthProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                if (!currentAuthProvider.isLoggedIn ||
                    currentAuthProvider.userProfile == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign in to create a post.',
                          style: GoogleFonts.lato()),
                      backgroundColor: theme.colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.all(10),
                    ),
                  );
                  return;
                }

                showSelectVisibilityModal(context, (selectedVisibility) async {
                  if (mounted) {
                    try {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (navContext) => CreatePostPage(
                              initialVisibility: selectedVisibility),
                        ),
                      );
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to open the page.',
                                style: GoogleFonts.lato()),
                            backgroundColor: theme.colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.all(10),
                          ),
                        );
                      }
                    }
                  }
                });
              },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text("New post",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState(
      {required IconData icon, required String title, String? subtitle}) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: theme.hintColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 17,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  color: theme.hintColor,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                color: theme.colorScheme.error,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
