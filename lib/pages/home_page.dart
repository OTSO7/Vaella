// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../models/user_profile_model.dart';
import '../widgets/post_card.dart';
import '../pages/create_post_page.dart';
import '../widgets/select_visibility_modal.dart';

// UUTTA: Erillinen widget postaussyötteelle, tekee koodista paljon siistimmän.
class _PostFeed extends StatelessWidget {
  final Stream<List<Post>> stream;
  final String emptyStateMessage;

  const _PostFeed({required this.stream, required this.emptyStateMessage});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return StreamBuilder<List<Post>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(context, message: emptyStateMessage);
        }

        final posts = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8.0, bottom: 120.0),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return PostCard(
              key: ValueKey(posts[index].id),
              post: posts[index],
              currentUserId: authProvider.user?.uid,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, {required String message}) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_off_outlined,
                size: 60, color: theme.hintColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // UUTTA: Stream-funktio julkisille postauksille ("For You")
  Stream<List<Post>> _getPublicPostsStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('visibility', isEqualTo: 'public')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Post.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  // UUTTA: Stream-funktio seurattujen käyttäjien postauksille ("Following")
  Stream<List<Post>> _getFollowingPostsStream(UserProfile? currentUserProfile) {
    if (currentUserProfile == null || currentUserProfile.followingIds.isEmpty) {
      return Stream.value([]); // Palauta tyhjä stream, jos ei seurata ketään
    }

    // HUOM: Firestore ei tue "OR" -kyselyitä tällä tavalla. Tehokkaampi tapa olisi
    // luoda käyttäjälle oma "feed" alacollection, mutta tämä on yksinkertaisempi
    // ja toimii pienellä datamäärällä. Tässä näytetään vain seurattujen julkiset ja ystävä-postaukset.
    List<String> userIdsToShow = [
      currentUserProfile.uid,
      ...currentUserProfile.followingIds
    ];

    return FirebaseFirestore.instance
        .collection('posts')
        .where('userId', whereIn: userIdsToShow)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Post.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>))
            .where((post) =>
                post.visibility != PostVisibility.private ||
                post.userId == currentUserProfile.uid)
            .toList());
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: Image.asset('assets/images/white2.png',
                  height: 35, fit: BoxFit.contain),
              centerTitle: true,
              pinned: true,
              floating: true,
              forceElevated: innerBoxIsScrolled,
              backgroundColor: theme.scaffoldBackgroundColor,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_outlined),
                  tooltip: "Search",
                  onPressed: () {/* Search logic */},
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3.0,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 15),
                tabs: const [
                  Tab(text: 'For You'),
                  Tab(text: 'Following'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _PostFeed(
              stream: _getPublicPostsStream(),
              emptyStateMessage: 'No public posts found at the moment.',
            ),
            authProvider.isLoggedIn
                ? _PostFeed(
                    stream: _getFollowingPostsStream(authProvider.userProfile),
                    emptyStateMessage:
                        'Follow other hikers to see their posts here!',
                  )
                : Center(
                    child: Text(
                        "Please sign in to see posts from people you follow.",
                        style: GoogleFonts.lato())),
          ],
        ),
      ),
      floatingActionButton: authProvider.isLoggedIn
          ? FloatingActionButton(
              onPressed: () {
                showSelectVisibilityModal(context, (selectedVisibility) {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => CreatePostPage(
                          initialVisibility: selectedVisibility)));
                });
              },
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}
