// lib/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.addListener(_onAuthChanged);
      _onAuthChanged();
    });
  }

  @override
  void dispose() {
    Provider.of<AuthProvider>(context, listen: false)
        .removeListener(_onAuthChanged);
    _postsSubscription?.cancel();
    super.dispose();
  }

  void _onAuthChanged() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn && authProvider.userProfile != null) {
      _startPostsStream(authProvider.userProfile!);
    } else {
      _postsSubscription?.cancel();
      if (mounted) {
        setState(() {
          _posts = [];
          _isLoadingPosts = false;
          _errorMessage = 'Kirjaudu sisään nähdäksesi postaukset.';
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
        .map((snapshot) =>
            snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList())
        .map((allPosts) => allPosts.where((post) {
              if (post.visibility == PostVisibility.public) return true;
              if (post.visibility == PostVisibility.private) {
                return post.userId == currentUserProfile.uid;
              }
              if (post.visibility == PostVisibility.friends) {
                return post.userId == currentUserProfile.uid ||
                    (currentUserProfile.friends.contains(post.userId));
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
    }, onError: (error, stackTrace) {
      print('Posts stream error: $error \nStackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
          _errorMessage =
              'Virhe postausten lataamisessa.'; // Yksinkertaistettu virheilmoitus
        });
      }
    });
  }

  Future<void> _refreshPosts() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPosts = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn && authProvider.userProfile != null) {
      _startPostsStream(authProvider.userProfile!);
    } else {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
          _errorMessage = 'Kirjaudu sisään päivittääksesi postaukset.';
        });
      }
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted && _isLoadingPosts && _posts.isNotEmpty) {
      setState(() {
        _isLoadingPosts = false;
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Postaukset päivitetty.'),
            duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout),
          // tooltip: 'Kirjaudu ulos', // PIDÄ POIS, JOS TOOLTIP-VIRHEET JATKUVAT
          onPressed: () => authProvider.logout(),
        ),
        title: Hero(
          tag: 'appLogo',
          child: Image.asset('assets/images/white2.png',
              height: 80, fit: BoxFit.contain),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            // tooltip: 'Hae postauksia', // PIDÄ POIS, JOS TOOLTIP-VIRHEET JATKUVAT
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Hakuominaisuus ei ole vielä toteutettu.')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        color: theme.colorScheme.secondary,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: _isLoadingPosts
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: theme.colorScheme.error, fontSize: 16)),
                    ),
                  )
                : _posts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            authProvider.isLoggedIn
                                ? 'Ei vaelluspostauksia vielä.\nLuo ensimmäinen omasi!'
                                : 'Kirjaudu sisään nähdäksesi vaelluspostaukset.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7),
                                fontSize: 17,
                                height: 1.5),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 90.0),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          return PostCard(key: ValueKey(post.id), post: post);
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16.0),
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final currentAuthProvider =
              Provider.of<AuthProvider>(context, listen: false);
          if (!currentAuthProvider.isLoggedIn ||
              currentAuthProvider.userProfile == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Kirjaudu sisään luodaksesi postauksen.'),
                backgroundColor: theme.colorScheme.error,
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
                    builder: (navContext) =>
                        CreatePostPage(initialVisibility: selectedVisibility),
                  ),
                );
              } catch (e, s) {
                print(
                    'ERROR during Navigator.push or CreatePostPage build: $e\nStackTrace: $s');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: const Text('Sivun avaaminen epäonnistui.'),
                        backgroundColor: theme.colorScheme.error),
                  );
                }
              }
            }
          });
        },
        // tooltip: 'Lisää postaus', // PIDÄ POIS, JOS TOOLTIP-VIRHEET JATKUVAT
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text("Uusi vaellus"),
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
