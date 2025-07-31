// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../models/user_profile_model.dart' as user_model;
import '../widgets/profile_counts_bar.dart';
import '../widgets/user_posts_section.dart';
import '../widgets/profile_header_content.dart';
import '../widgets/profile_tab_bar.dart';
import '../widgets/user_hikes_map_section.dart';
import '../widgets/achievement_grid.dart' as achievement_widget;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _profileFuture = _fetchProfile();
  }

  Future<user_model.UserProfile> _fetchProfile() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final idToFetch = widget.userId ?? authProvider.user?.uid;

    if (idToFetch == null) {
      return Future.error("User not found or not logged in.");
    }

    return authProvider.fetchUserProfileById(idToFetch);
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      setState(() {
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: FutureBuilder<user_model.UserProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error.toString()}"));
          }
          if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Please log in to see your profile.",
                      style: GoogleFonts.lato()),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text("Go to Login"),
                  )
                ],
              ),
            );
          }

          final user_model.UserProfile user = isOwnProfile &&
                  authProvider.userProfile != null
              ? authProvider.userProfile!
                  .copyWith(relationToCurrentUser: user_model.UserRelation.self)
              : snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _profileFuture = _fetchProfile();
              });
            },
            child: NestedScrollView(
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  // YKSINKERTAISTETTU SLIVERAPPBAR
                  SliverAppBar(
                    expandedHeight: 50.0,
                    floating: false,
                    pinned: true,
                    stretch: true,
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: Colors.white,
                    // Näyttää nimen automaattisesti, kun palkki on pienennetty
                    title: innerBoxIsScrolled
                        ? Text(user.displayName,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600))
                        : null,
                    flexibleSpace: FlexibleSpaceBar(
                      background: (user.bannerImageUrl != null &&
                              user.bannerImageUrl!.isNotEmpty)
                          ? Image.network(
                              user.bannerImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                      color: theme.scaffoldBackgroundColor),
                            )
                          : Container(color: theme.scaffoldBackgroundColor),
                    ),
                    actions: [_buildAppBarActions(context, user, authProvider)],
                  ),

                  // UUSI, SIISTI HEADER-OSA
                  SliverToBoxAdapter(
                      child: ProfileHeaderContent(userProfile: user)),

                  // ALAOSA, JOKA PYSTYI ENNALLAAN
                  SliverToBoxAdapter(
                    child: ProfileCountsBar(
                      postsCount: user.postsCount,
                      followersCount: user.followerIds.length,
                      followingCount: user.followingIds.length,
                      onPostsTap: () => _tabController.animateTo(0),
                      onFollowersTap: () {/* Navigoi seuraajalistaan */},
                      onFollowingTap: () {/* Navigoi seurattujen listaan */},
                    ),
                  ),
                  ProfileTabBar(controller: _tabController),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  UserPostsSection(userId: user.uid, onPostsLoaded: (count) {}),
                  UserHikesMapSection(userId: user.uid),
                  _buildAchievementsTab(context, user)
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBarActions(BuildContext context, user_model.UserProfile user,
      AuthProvider authProvider) {
    if (user.relationToCurrentUser == user_model.UserRelation.self) {
      return PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'settings') {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Settings page coming soon!")));
          } else if (value == 'logout') {
            authProvider.logout();
            context.go('/login');
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'settings',
            child: ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text('Settings')),
          ),
          const PopupMenuItem<String>(
            value: 'logout',
            child:
                ListTile(leading: Icon(Icons.logout), title: Text('Log Out')),
          ),
        ],
      );
    } else {
      return PopupMenuButton<String>(
        onSelected: (value) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("$value action coming soon!")));
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
              value: 'report',
              child: ListTile(
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Report User'))),
          const PopupMenuItem<String>(
              value: 'block',
              child: ListTile(
                  leading: Icon(Icons.block), title: Text('Block User'))),
        ],
      );
    }
  }

  Widget _buildAchievementsTab(
      BuildContext context, user_model.UserProfile user) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Achievements",
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          user.achievements.isEmpty
              ? Text("No achievements yet.",
                  style: GoogleFonts.lato(color: theme.hintColor))
              : achievement_widget.AchievementGrid(
                  achievements: user.achievements
                      .map((a) => achievement_widget.Achievement(
                            title: a.title,
                            description: a.description,
                            icon: a.icon,
                            dateAchieved: a.dateAchieved,
                            iconColor: a.iconColor,
                            imageUrl: a.imageUrl,
                          ))
                      .toList(),
                  isStickerGrid: false,
                ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("National Park Badges",
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          user.stickers.isEmpty
              ? Text("No badges collected yet.",
                  style: GoogleFonts.lato(color: theme.hintColor))
              : achievement_widget.AchievementGrid(
                  achievements: user.stickers
                      .map((s) => achievement_widget.Achievement(
                            title: s.name,
                            description: '',
                            imageUrl: s.imageUrl,
                            dateAchieved: DateTime.now(),
                            icon: Icons.shield,
                          ))
                      .toList(),
                  isStickerGrid: true,
                ),
        ],
      ),
    );
  }
}
