import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'followers_following_list_page.dart';

import '../providers/auth_provider.dart';
import '../providers/follow_provider.dart';
import '../models/user_profile_model.dart' as user_model;
import '../widgets/user_posts_section.dart';
import '../widgets/user_hikes_map_section.dart';
import '../widgets/modern/stats_and_achievements_section.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late String _profileOwnerId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _profileOwnerId = widget.userId ?? authProvider.user?.uid ?? '';
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      setState(() {
        _profileOwnerId = widget.userId ?? authProvider.user?.uid ?? '';
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
      backgroundColor: theme.colorScheme.surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_profileOwnerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data == null ||
              snapshot.data!.data() == null) {
            return _buildErrorOrLoginView(context, snapshot.error);
          }

          final user = user_model.UserProfile.fromFirestore(snapshot.data!);

          return RefreshIndicator(
            onRefresh: () async {},
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _ProfileBanner(user: user, isOwnProfile: isOwnProfile),
                  SliverToBoxAdapter(
                    child:
                        _ProfileHeader(user: user, isOwnProfile: isOwnProfile),
                  ),
                  SliverPersistentHeader(
                    delegate: _ModernTabBarDelegate(_tabController),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  UserPostsSection(userId: user.uid),
                  UserPostsMapSection(
                    userId: user.uid,
                    userProfile: user,
                  ),
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
}

// --- BANNERI ---
class _ProfileBanner extends StatelessWidget {
  final user_model.UserProfile user;
  final bool isOwnProfile;
  const _ProfileBanner({required this.user, required this.isOwnProfile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 160.0,
      floating: false,
      pinned: true,
      leading: isOwnProfile
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: Material(
                color: Colors.black.withOpacity(0.3),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: 'Log out',
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Log out"),
                        content:
                            const Text("Are you sure you want to log out?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text("Log out"),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await Provider.of<AuthProvider>(context, listen: false)
                          .logout();
                      if (context.mounted) context.go('/login');
                    }
                  },
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Material(
                color: Colors.black.withOpacity(0.3),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
      automaticallyImplyLeading: false,
      backgroundColor: theme.colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            image:
                user.bannerImageUrl != null && user.bannerImageUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(user.bannerImageUrl!),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.25),
                          BlendMode.darken,
                        ),
                      )
                    : null,
          ),
        ),
      ),
      actions: [
        isOwnProfile ? _SettingsButton() : _ProfilePopupMenu(),
        const SizedBox(width: 8),
      ],
    );
  }
}

// --- PROFIILIN YLÄOSA ---
class _ProfileHeader extends StatelessWidget {
  final user_model.UserProfile user;
  final bool isOwnProfile;
  const _ProfileHeader({required this.user, required this.isOwnProfile});

  String getLevelTitle(int level) {
    if (level >= 50) return "Legendary Hiker";
    if (level >= 40) return "Trail Master";
    if (level >= 30) return "Summit Seeker";
    if (level >= 20) return "Pathfinder";
    if (level >= 10) return "Explorer";
    return "Rookie";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: theme.dividerColor,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  backgroundImage:
                      (user.photoURL != null && user.photoURL!.isNotEmpty)
                          ? NetworkImage(user.photoURL!)
                          : const AssetImage('assets/images/default_avatar.png')
                              as ImageProvider,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ProfileStatsBar(user: user),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            '@${user.username}',
            style: GoogleFonts.lato(
              fontSize: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          // --- VANHAN TYYLIN LEVEL DISPLAY ---
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 2, bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Level ${user.level}',
                  style: GoogleFonts.poppins(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    getLevelTitle(user.level),
                    style: GoogleFonts.lato(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              user.bio!,
              style: GoogleFonts.lato(
                fontSize: 14.5,
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (isOwnProfile)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Profile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.dividerColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => context.push(
                  '/profile/edit',
                  extra: user,
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: _FollowButton(user: user),
            ),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.3),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: const Icon(Icons.settings_outlined, color: Colors.white),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Settings page coming soon!")));
        },
      ),
    );
  }
}

class _ProfilePopupMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.3),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: (value) {/* report/block */},
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
      ),
    );
  }
}

// --- FollowButton, FollowProviderilla ---
class _FollowButton extends StatelessWidget {
  final user_model.UserProfile user;
  const _FollowButton({required this.user});

  @override
  Widget build(BuildContext context) {
    return Consumer<FollowProvider>(
      builder: (context, followProvider, child) {
        final isFollowing = followProvider.isFollowing(user.uid);
        final theme = Theme.of(context);

        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing
                ? theme.colorScheme.surfaceVariant
                : theme.colorScheme.primary,
            foregroundColor: isFollowing
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () async {
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            await authProvider.toggleFollowStatus(user.uid, isFollowing);
            followProvider.setFollowing(user.uid, !isFollowing);
          },
          child: isFollowing
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 18),
                    SizedBox(width: 6),
                    Text("Following")
                  ],
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_alt_1_outlined, size: 18),
                    SizedBox(width: 6),
                    Text("Follow")
                  ],
                ),
        );
      },
    );
  }
}

// --- RESPONSIIIVINEN, ISOMPI KLIKKIALUE ---
class _ProfileStatsBar extends StatelessWidget {
  final user_model.UserProfile user;
  const _ProfileStatsBar({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // Posts (ei klikattava)
        Expanded(
          child: _StatItem(
            label: "Posts",
            value: user.postsCount,
            onTap: null,
          ),
        ),
        // Followers (laaja klikattava alue)
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                context.push('/profile/${user.uid}/followers');
              },
              child: _StatItem(
                label: "Followers",
                value: user.followerIds.length,
                onTap: () {
                  context.push('/profile/${user.uid}/followers');
                },
              ),
            ),
          ),
        ),
        // Following (laaja klikattava alue)
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                context.push('/profile/${user.uid}/following');
              },
              child: _StatItem(
                label: "Following",
                value: user.followingIds.length,
                onTap: () {
                  context.push('/profile/${user.uid}/following');
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- StatItem, jossa koko alue klikattava jos onTap annettu ---
class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;
  const _StatItem({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: content,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: content,
    );
  }
}

// --- Moderni TabBar ---
class _ModernTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;
  _ModernTabBarDelegate(this.controller);

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 1.0),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: 2.5, color: theme.colorScheme.primary),
          insets: const EdgeInsets.symmetric(horizontal: 16.0),
        ),
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        tabs: const [
          Tab(icon: Icon(Icons.grid_on_rounded)),
          Tab(icon: Icon(Icons.map_outlined)),
          Tab(icon: Icon(Icons.query_stats_rounded)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_ModernTabBarDelegate oldDelegate) => false;
}
