import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../models/user_profile_model.dart' as user_model;
import '../widgets/modern/profile_header.dart';
import '../widgets/modern/stats_and_achievements_section.dart';
import '../widgets/user_posts_section.dart';
import '../widgets/user_hikes_map_section.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Future<user_model.UserProfile> _profileFuture;
  late String _profileOwnerId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _profileOwnerId = widget.userId ?? authProvider.user?.uid ?? '';
    _profileFuture = _fetchProfile();
  }

  Future<user_model.UserProfile> _fetchProfile() {
    if (_profileOwnerId.isEmpty) {
      return Future.error("User not found.");
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.fetchUserProfileById(_profileOwnerId);
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      setState(() {
        _profileOwnerId = widget.userId ?? authProvider.user?.uid ?? '';
        _profileFuture = _fetchProfile();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isOwnProfile =
        widget.userId == null || widget.userId == authProvider.user?.uid;

    final loggedInUserProfile = context.watch<AuthProvider>().userProfile;

    return Scaffold(
      body: FutureBuilder<user_model.UserProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorOrLoginView(context, snapshot.error);
          }

          user_model.UserProfile user = snapshot.data!;

          if (!isOwnProfile && loggedInUserProfile != null) {
            final isFollowing =
                loggedInUserProfile.followingIds.contains(user.uid);
            user.relationToCurrentUser = isFollowing
                ? user_model.UserRelation.following
                : user_model.UserRelation.notFollowing;
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _profileFuture = _fetchProfile();
              });
            },
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildSliverAppBar(context, user, innerBoxIsScrolled),
                  SliverToBoxAdapter(child: ProfileHeader(userProfile: user)),
                  _buildSliverTabBar(context, theme),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  UserPostsSection(userId: user.uid),
                  UserHikesMapSection(userId: user.uid),
                  StatsAndAchievementsSection(userProfile: user),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorOrLoginView(BuildContext context, Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            error != null
                ? "Error: ${error.toString()}"
                : "Please log in to see your profile.",
            style: GoogleFonts.lato(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text("Go to Login"),
          )
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
      BuildContext context, user_model.UserProfile user, bool isScrolled) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: theme.colorScheme.surface,
      title: isScrolled
          ? Text(user.displayName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600))
          : null,
      actions: [_buildAppBarActions(context, user)],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background:
            user.bannerImageUrl != null && user.bannerImageUrl!.isNotEmpty
                ? Image.network(
                    user.bannerImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: theme.colorScheme.surfaceVariant),
                  )
                : Container(color: theme.colorScheme.surfaceVariant),
      ),
    );
  }

  SliverPersistentHeader _buildSliverTabBar(
      BuildContext context, ThemeData theme) {
    return SliverPersistentHeader(
      delegate: _SliverTabBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(icon: Icon(Icons.grid_on_rounded), text: "Posts"),
            Tab(icon: Icon(Icons.map_outlined), text: "Map"),
            Tab(icon: Icon(Icons.query_stats_rounded), text: "Stats"),
          ],
        ),
      ),
      pinned: true,
    );
  }

  Widget _buildAppBarActions(
      BuildContext context, user_model.UserProfile user) {
    if (user.relationToCurrentUser == user_model.UserRelation.self) {
      return IconButton(
        icon: const Icon(Icons.settings_outlined),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Settings page coming soon!")));
        },
      );
    } else {
      return PopupMenuButton<String>(
        onSelected: (value) {/* Toteuta report/block */},
        itemBuilder: (context) => [
          const PopupMenuItem(
              value: 'report',
              child: ListTile(
                  leading: Icon(Icons.flag_outlined), title: Text('Report'))),
          const PopupMenuItem(
              value: 'block',
              child:
                  ListTile(leading: Icon(Icons.block), title: Text('Block'))),
        ],
      );
    }
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
