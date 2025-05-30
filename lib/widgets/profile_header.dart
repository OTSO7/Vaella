// lib/widgets/profile_header.dart
import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String username; // Username visible
  final String displayName;
  final String? photoURL;
  final String? bio;
  final String? bannerImageUrl; // Banner image
  final VoidCallback onEditProfile;
  final int level; // Example level
  final double experienceProgress; // E.g. 0.0 - 1.0

  const ProfileHeader({
    super.key,
    required this.username,
    required this.displayName,
    this.photoURL,
    this.bio,
    this.bannerImageUrl,
    required this.onEditProfile,
    this.level = 1,
    this.experienceProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Banner image
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: (bannerImageUrl != null && bannerImageUrl!.isNotEmpty)
                    ? NetworkImage(bannerImageUrl!)
                    : const AssetImage('assets/images/default_banner.jpg')
                        as ImageProvider, // DEFAULT BANNER IMAGE
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.4), // Darker for text contrast
                  BlendMode.darken,
                ),
              ),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30)), // More rounded bottom
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 50, right: 16), // Adjusted padding
                child: IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: Colors.white.withOpacity(0.9),
                      size: 28), // Larger icon
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Colors.black.withOpacity(0.4), // Darker background
                    shape: const CircleBorder(), // Circular background
                    padding: const EdgeInsets.all(12), // Smaller padding
                  ),
                  tooltip: 'Edit profile',
                  onPressed: onEditProfile,
                ),
              ),
            ),
          ),
        ),

        // Profile picture and info
        Positioned(
          bottom: 0, // Positioned at the bottom
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 4), // Border for profile picture
                ),
                child: CircleAvatar(
                  radius: 70, // Larger profile picture
                  backgroundColor: theme.colorScheme.surface,
                  backgroundImage: (photoURL != null && photoURL!.isNotEmpty)
                      ? NetworkImage(photoURL!)
                      : const AssetImage('assets/images/default_avatar.png')
                          as ImageProvider,
                  onBackgroundImageError: (_, __) {
                    // Handle error if image can't be loaded
                  },
                  child: (photoURL == null || photoURL!.isEmpty)
                      ? Icon(Icons.person, size: 80, color: Colors.grey[500])
                      : null,
                ),
              ),
              const SizedBox(height: 16), // Space between avatar and name
              Text(
                displayName,
                style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ),
              Text(
                '@$username', // Username
                style: textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
              if (bio != null && bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    bio!,
                    style: textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        height: 1.4),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 24), // Space between bio and stats

              // Level and experience bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Level $level',
                            style: textTheme.titleMedium
                                ?.copyWith(color: theme.colorScheme.secondary)),
                        Text(
                            '${(experienceProgress * 100).toInt()}% to next level',
                            style: textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: experienceProgress,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.3), // Lighter background.
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.secondary),
                      minHeight: 8, // Thicker bar
                      borderRadius:
                          BorderRadius.circular(4), // More rounded corners
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
