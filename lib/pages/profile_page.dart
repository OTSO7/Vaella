import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../models/user_profile_model.dart' as user_model;
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

    if (!authProvider.isLoggedIn || authProvider.userProfile == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Profile',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              authProvider.isLoading
                  ? CircularProgressIndicator(color: theme.colorScheme.primary)
                  : Text('Loading profile...',
                      style: GoogleFonts.lato(fontSize: 16)),
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

    final user_model.UserProfile userProfile = authProvider.userProfile!;

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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Use SliverList for dynamic height and flexibility
          SliverList(
            delegate: SliverChildListDelegate(
              [
                // Header section (no more fixed height)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ProfileHeader(
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

                const SizedBox(height: 12),

                // Profile Counts
                ProfileCountsBar(
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

                const SizedBox(height: 24),

                // Achievements
                _buildSectionHeader(
                    context, 'Achievements', Icons.emoji_events_rounded),
                userProfile.achievements.isEmpty
                    ? _buildEmptySectionPlaceholder(
                        context,
                        'No achievements yet. Keep exploring!',
                        Icons.explore_outlined)
                    : achievement_widget.AchievementGrid(
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

                const SizedBox(height: 24),

                // National Park Badges
                _buildSectionHeader(context, 'National Park Badges',
                    Icons.collections_bookmark_rounded),
                userProfile.stickers.isEmpty
                    ? _buildEmptySectionPlaceholder(
                        context,
                        'No national park badges collected yet.',
                        Icons.park_outlined)
                    : achievement_widget.AchievementGrid(
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

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 26),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySectionPlaceholder(
      BuildContext context, String message, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 50, color: theme.hintColor.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.lato(
                  fontSize: 16, color: theme.hintColor.withOpacity(0.8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
