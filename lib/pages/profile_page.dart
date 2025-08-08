import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../providers/auth_provider.dart';
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
      backgroundColor: theme.colorScheme.surface,
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

// --- UUSI BANNERI ---
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
      leading: !isOwnProfile
          ? Padding(
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
            )
          : null,
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

// --- UUSI PROFIILIN YLÄOSA ---
class _ProfileHeader extends StatelessWidget {
  final user_model.UserProfile user;
  final bool isOwnProfile;
  const _ProfileHeader({required this.user, required this.isOwnProfile});

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
          const SizedBox(height: 12),
          _LevelDisplayChip(level: user.level),
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
                onPressed: () => context.push('/profile/edit', extra: user),
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

// --- UUSI LEVEL-NÄYTTÖ (STATEFUL ANIMAATIOLLA) ---
class _LevelDisplayChip extends StatefulWidget {
  final int level;
  const _LevelDisplayChip({required this.level});

  String _getLevelTitle(int currentLevel) {
    if (currentLevel >= 100) return "Legendary Hiker";
    if (currentLevel >= 90) return "Supreme Voyager";
    if (currentLevel >= 80) return "Master Explorer";
    if (currentLevel >= 70) return "Grand Adventurer";
    if (currentLevel >= 60) return "Elite Navigator";
    if (currentLevel >= 50) return "Mountain Virtuoso";
    if (currentLevel >= 40) return "Seasoned Trekker";
    if (currentLevel >= 30) return "Peak Seeker";
    if (currentLevel >= 20) return "Highland Strider";
    if (currentLevel >= 15) return "Pathfinder";
    if (currentLevel >= 10) return "Explorer";
    if (currentLevel >= 5) return "Novice";
    return "Newbie";
  }

  @override
  State<_LevelDisplayChip> createState() => _LevelDisplayChipState();
}

class _LevelDisplayChipState extends State<_LevelDisplayChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shineAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _shineAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelTitle = widget._getLevelTitle(widget.level);
    final isLegendary = widget.level >= 100;
    final isEpic = widget.level >= 50 && !isLegendary;

    Color chipColor = theme.colorScheme.surfaceVariant;
    Color textColor = theme.colorScheme.onSurfaceVariant;
    Color iconColor = Colors.amber;

    if (isLegendary) {
      chipColor = const Color(0xFF3C2F0E);
      textColor = const Color(0xFFFFF8E1);
      iconColor = const Color(0xFFFFD700);
    } else if (isEpic) {
      chipColor = const Color(0xFF311B92);
      textColor = const Color(0xFFEDE7F6);
      iconColor = const Color(0xFFB39DDB);
    }

    Widget titleWidget;

    if (isLegendary) {
      titleWidget = AnimatedBuilder(
        animation: _shineAnimation,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                transform:
                    GradientRotation(_shineAnimation.value * 3.14159), // Pi
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  textColor,
                  Colors.white,
                  textColor,
                ],
                stops: const [0.4, 0.5, 0.6],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcIn,
            child: child,
          );
        },
        child: Text(
          levelTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: textColor,
            letterSpacing: 0.3,
            shadows: [
              Shadow(
                blurRadius: 12.0,
                color: Colors.amber.withOpacity(0.5),
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
      );
    } else {
      titleWidget = Text(
        levelTitle,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: textColor,
          letterSpacing: 0.3,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          titleWidget,
          const SizedBox(width: 8),
          Icon(Icons.stars, color: iconColor, size: 16),
          const SizedBox(width: 4),
          Text(
            'Level ${widget.level}',
            style: GoogleFonts.lato(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: textColor,
            ),
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

class _FollowButton extends StatefulWidget {
  final user_model.UserProfile user;
  const _FollowButton({required this.user});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _isLoading = false;
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing =
        widget.user.relationToCurrentUser == user_model.UserRelation.following;
  }

  @override
  void didUpdateWidget(covariant _FollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.relationToCurrentUser !=
        oldWidget.user.relationToCurrentUser) {
      setState(() {
        _isFollowing = widget.user.relationToCurrentUser ==
            user_model.UserRelation.following;
      });
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_isLoading) return;

    if (_isFollowing) {
      // Unfollow action with confirmation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Unfollow @${widget.user.username}?'),
          content: const Text(
              'Their posts will no longer appear in your feed. Are you sure?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Unfollow'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.toggleFollowStatus(widget.user.uid, _isFollowing);
      // The UI will update via didUpdateWidget when the provider notifies listeners
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buttonChild;
    if (_isLoading) {
      buttonChild = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
      );
    } else if (_isFollowing) {
      buttonChild = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 18),
          SizedBox(width: 6),
          Text("Following")
        ],
      );
    } else {
      buttonChild = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_add_alt_1_outlined, size: 18),
          SizedBox(width: 6),
          Text("Follow")
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: SizedBox(
        key: ValueKey<bool>(_isFollowing), // Change key to trigger animation
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isFollowing
                ? theme.colorScheme.surfaceVariant
                : theme.colorScheme.primary,
            foregroundColor: _isFollowing
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _handleFollowToggle,
          child: buttonChild,
        ),
      ),
    );
  }
}

class _ProfileStatsBar extends StatelessWidget {
  final user_model.UserProfile user;
  const _ProfileStatsBar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(
          label: "Posts",
          value: user.postsCount,
        ),
        _StatItem(
          label: "Followers",
          value: user.followerIds.length,
        ),
        _StatItem(
          label: "Following",
          value: user.followingIds.length,
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
