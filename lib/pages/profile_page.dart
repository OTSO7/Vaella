import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart'; // Suositeltu lisäys
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
    final textTheme = Theme.of(context).textTheme.apply(
          fontFamily: GoogleFonts.lato().fontFamily, // Esimerkki fontista
        );

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
                  ? CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    )
                  : Text('Loading profile...', style: textTheme.bodyLarge),
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
                borderRadius: BorderRadius.circular(10.0),
              ),
              margin: const EdgeInsets.all(10.0),
            ),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor, // Use a light grey for background
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 380.0, // Increased height
            floating: false,
            pinned: true,
            elevation: 0, // Remove shadow when not scrolled
            backgroundColor:
                theme.colorScheme.surface, // Or a slightly different shade
            leading: IconButton(
              icon: Icon(Icons.logout_outlined,
                  color: theme.colorScheme.onSurface),
              tooltip: 'Log out',
              onPressed: () {
                authProvider.logout();
              },
            ),
            // actions: [
            //   IconButton(
            //     icon: Icon(Icons.settings_outlined, color: theme.colorScheme.onSurface),
            //     tooltip: 'Settings',
            //     onPressed: () {
            //       // Implement settings menu (e.g., showModalBottomSheet with Edit Profile & Logout)
            //     },
            //   ),
            // ],
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
          _buildSectionHeader(
              context, 'Statistics', Icons.insights_rounded), // Updated icon
          SliverToBoxAdapter(
            child: ProfileStatsGrid(stats: userProfile.stats),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)), // Spacing
          _buildSectionHeader(context, 'Achievements',
              Icons.emoji_events_rounded), // Updated icon
          userProfile.achievements.isEmpty
              ? SliverToBoxAdapter(
                  child: _buildEmptySectionPlaceholder(
                      context,
                      'No achievements yet. Keep exploring to earn them!',
                      Icons.explore_outlined))
              : SliverToBoxAdapter(
                  child: achievement_widget.AchievementGrid(
                    achievements: userProfile.achievements
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
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)), // Spacing
          _buildSectionHeader(context, 'National Park Badges',
              Icons.collections_bookmark_rounded), // Updated icon
          userProfile.stickers.isEmpty
              ? SliverToBoxAdapter(
                  child: _buildEmptySectionPlaceholder(
                      context,
                      'No national park badges collected yet. Visit parks to collect them!',
                      Icons.park_outlined))
              : SliverToBoxAdapter(
                  child: achievement_widget.AchievementGrid(
                    achievements: userProfile.stickers
                        .map((s) => achievement_widget.Achievement(
                              title: s.name,
                              description: s.name, // Or a generic description
                              imageUrl: s.imageUrl,
                              dateAchieved:
                                  null, // Stickers might not have a dateAchieved
                              icon: Icons
                                  .shield_moon_outlined, // Placeholder if no image
                            ))
                        .toList(),
                    isStickerGrid: true,
                  ),
                ),
          SliverToBoxAdapter(
              child: SizedBox(
                  height: kBottomNavigationBarHeight +
                      32.0)), // More padding at the bottom
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 16), // Adjusted padding
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 26),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                // Using Poppins for headers
                fontSize: 20,
                fontWeight: FontWeight.w600, // Bolder
                color: theme.colorScheme.onSurface,
              ),
            ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 50, color: theme.hintColor.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.lato(
                // Using Lato for body
                fontSize: 16,
                color: theme.hintColor.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
