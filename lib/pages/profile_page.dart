import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user_profile_model.dart' as user_model;
import '../widgets/profile_header.dart'; // Profile header widget
import '../widgets/profile_stats_grid.dart'; // For displaying stats
import '../widgets/achievement_grid.dart' as achievement_widget; // Alias added

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
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              authProvider.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Loading profile...'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => authProvider.logout(),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      );
    }

    final user_model.UserProfile userProfile = authProvider.userProfile!;

    // Function to navigate to edit profile
    void navigateToEditProfile() async {
      final updatedProfile = await context.push<user_model.UserProfile>(
        '/profile/edit',
        extra: userProfile,
      );

      if (updatedProfile != null && mounted) {
        await authProvider.updateLocalUserProfile(updatedProfile);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green),
        );
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 320.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: IconButton(
              icon: Icon(Icons.logout, color: theme.colorScheme.onSurface),
              tooltip: 'Log out',
              onPressed: () {
                authProvider.logout();
              },
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
                level: (userProfile.stats['Vaelluksia'] ?? 0) ~/ 5 + 1,
                experienceProgress:
                    ((userProfile.stats['Vaelluksia'] ?? 0) % 5) / 5.0,
              ),
            ),
          ),
          _buildSectionHeader(context, 'Statistics', Icons.bar_chart_outlined),
          SliverToBoxAdapter(
            child: ProfileStatsGrid(stats: userProfile.stats),
          ),
          _buildSectionHeader(
              context, 'Achievements', Icons.emoji_events_outlined),
          userProfile.achievements.isEmpty
              ? SliverToBoxAdapter(
                  child: _buildEmptySectionPlaceholder(
                      context, 'No achievements yet. Go explore!'))
              : SliverToBoxAdapter(
                  child: achievement_widget.AchievementGrid(
                    achievements: userProfile.achievements
                        .map((a) => achievement_widget.Achievement(
                              title: a.title,
                              description: a.description,
                              icon: a.icon,
                              dateAchieved: a.dateAchieved,
                              iconColor: a.iconColor,
                              imageUrl: a is achievement_widget.Achievement
                                  ? a.imageUrl
                                  : null,
                            ))
                        .toList(),
                    isStickerGrid: false,
                  ),
                ),
          _buildSectionHeader(context, 'National Park Badges',
              Icons.collections_bookmark_outlined),
          userProfile.stickers.isEmpty
              ? SliverToBoxAdapter(
                  child: _buildEmptySectionPlaceholder(
                      context, 'No national park badges collected yet.'))
              : SliverToBoxAdapter(
                  child: achievement_widget.AchievementGrid(
                    achievements: userProfile.stickers
                        .map((s) => achievement_widget.Achievement(
                              title: s.name,
                              description: s.name,
                              imageUrl: s.imageUrl,
                              dateAchieved: DateTime.now(),
                              icon: Icons.park_outlined,
                            ))
                        .toList(),
                    isStickerGrid: true,
                  ),
                ),
          const SliverToBoxAdapter(
              child: SizedBox(height: kBottomNavigationBarHeight + 16.0)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySectionPlaceholder(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
