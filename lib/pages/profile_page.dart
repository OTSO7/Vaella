import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../models/user_profile_model.dart'
    as user_model; // Alias to avoid confusion with FirebaseAuth.User
import '../widgets/profile_header.dart';
import '../widgets/achievement_grid.dart' as achievement_widget;
import '../widgets/profile_counts_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    // --- Loading/Login State Handling ---
    if (!authProvider.isLoggedIn || authProvider.userProfile == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Profile',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              authProvider.isLoading
                  ? CircularProgressIndicator(color: theme.colorScheme.primary)
                  : Text(
                      'Loading profile...',
                      style: GoogleFonts.lato(fontSize: 16),
                    ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                onPressed: () => authProvider.logout(),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      );
    }

    // --- User Profile Data ---
    final user_model.UserProfile userProfile = authProvider.userProfile!;

    // --- Navigation and SnackBar Logic ---
    void navigateToEditProfile() async {
      final updatedProfile = await context.push<user_model.UserProfile>(
        '/profile/edit',
        extra: userProfile,
      );
      if (updatedProfile != null && mounted) {
        await authProvider.updateLocalUserProfile(updatedProfile);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile updated successfully!',
                  style: GoogleFonts.lato()),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0)),
              margin: const EdgeInsets.all(10.0),
            ),
          );
        }
      }
    }

    // --- Experience & Level Calculation ---
    final int currentLevel = userProfile.level;
    final int currentTotalExperience = userProfile.experience;

    int totalExperienceToReachCurrentLevel = 0;
    for (int i = 1; i < currentLevel; i++) {
      totalExperienceToReachCurrentLevel +=
          authProvider.getExperienceRequiredForLevel(i);
    }

    final int experienceRequiredForNextLevel =
        authProvider.getExperienceRequiredForLevel(currentLevel);

    final int currentExperienceInCurrentLevel =
        (currentTotalExperience >= totalExperienceToReachCurrentLevel)
            ? currentTotalExperience - totalExperienceToReachCurrentLevel
            : 0;

    final double experienceProgress = (experienceRequiredForNextLevel > 0)
        ? (currentExperienceInCurrentLevel / experienceRequiredForNextLevel)
            .clamp(0.0, 1.0)
        : 0.0;

    // --- Main Scaffold with CustomScrollView ---
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 380.0,
            floating: false,
            pinned: true,
            snap: false,
            stretch: false,
            elevation: 0.5,
            backgroundColor: theme.colorScheme.surface,
            leading: IconButton(
              icon: Icon(Icons.logout_outlined,
                  color: theme.colorScheme.onSurface),
              tooltip: 'Log out',
              onPressed: () => authProvider.logout(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: ProfileHeader(
                username: userProfile.username,
                displayName: userProfile.displayName,
                photoURL: userProfile.photoURL,
                bio: userProfile.bio,
                bannerImageUrl: userProfile.bannerImageUrl,
                onEditProfile: navigateToEditProfile,
                level: currentLevel,
                currentExperience: currentExperienceInCurrentLevel,
                experienceToNextLevel: experienceRequiredForNextLevel,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ProfileCountsBar(
              postsCount: userProfile.postsCount,
              followersCount: userProfile.followerIds.length,
              followingCount: userProfile.followingIds.length,
              onPostsTap: () {
                context.push('/users/${userProfile.uid}/posts',
                    extra: userProfile.username);
              },
              onFollowersTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Followers list coming soon!")));
              },
              onFollowingTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Following list coming soon!")));
              },
            ),
          ),
          // --- Stats section removed ---
          // _buildSectionHeader(context, 'Stats', Icons.bar_chart_rounded),
          // SliverToBoxAdapter(
          //   child: ProfileStatsGrid(stats: userProfile.stats),
          // ),
          _buildSectionHeader(
              context, 'Achievements', Icons.emoji_events_rounded),
          userProfile.achievements.isEmpty
              ? SliverToBoxAdapter(
                  child: _buildEmptySectionPlaceholder(
                      context,
                      'No achievements yet. Keep exploring!',
                      Icons.explore_outlined))
              : SliverToBoxAdapter(
                  child: achievement_widget.AchievementGrid(
                    achievements: userProfile.achievements
                        .map((a) => achievement_widget.Achievement(
                              title: a.title,
                              description: a.description,
                              icon: user_model.Achievement.getIconFromName(
                                  a.iconName),
                              dateAchieved: a.dateAchieved,
                              iconColor: a.iconColor,
                              imageUrl: a.imageUrl,
                            ))
                        .toList(),
                    isStickerGrid: false,
                  ),
                ),
          _buildSectionHeader(context, 'National Park Badges',
              Icons.collections_bookmark_rounded),
          userProfile.stickers.isEmpty
              ? SliverToBoxAdapter(
                  child: _buildEmptySectionPlaceholder(
                      context,
                      'No national park badges collected yet.',
                      Icons.park_outlined))
              : SliverToBoxAdapter(
                  child: achievement_widget.AchievementGrid(
                    achievements: userProfile.stickers
                        .map((s) => achievement_widget.Achievement(
                              title: s.name,
                              description: s.name,
                              imageUrl: s.imageUrl,
                              dateAchieved: DateTime.now(),
                              icon: Icons.shield_moon_outlined,
                            ))
                        .toList(),
                    isStickerGrid: true,
                  ),
                ),
          // --- FIX: Ensure enough padding at the bottom ---
          SliverToBoxAdapter(
              child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom +
                      kBottomNavigationBarHeight +
                      32.0)),
        ],
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 26),
            const SizedBox(width: 12),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySectionPlaceholder(
      BuildContext context, String message, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 50, color: theme.hintColor.withOpacity(0.6)),
          const SizedBox(height: 16),
          Text(message,
              style: GoogleFonts.lato(
                  fontSize: 16, color: theme.hintColor.withOpacity(0.8)),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
