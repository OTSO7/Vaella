import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String displayName;
  final String? photoURL;
  final String? bio;
  final String? bannerImageUrl;
  final VoidCallback onEditProfile;
  final int level;
  final double experienceProgress;

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
    final textTheme = Theme.of(context).textTheme;

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
                        as ImageProvider,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  const Color.fromARGB(255, 0, 0, 0)
                      .withOpacity(0.45), // Slightly adjusted opacity
                  BlendMode.darken,
                ),
              ),
              // Keep the rounded bottom, it's a nice touch
              // borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),
        ),

        // Edit Profile Button (Top Right on Banner)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8, // Respect status bar
          right: 12,
          child: IconButton(
            icon: Icon(Icons.edit_outlined,
                color: Colors.white.withOpacity(0.9), size: 26),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.35),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)), // Softer circle
              padding: const EdgeInsets.all(10),
            ),
            tooltip: 'Edit profile',
            onPressed: onEditProfile,
          ),
        ),

        // Profile content, positioned towards the bottom of the header area
        Positioned(
          bottom: 20, // Give some space from the absolute bottom
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.scaffoldBackgroundColor
                            .withOpacity(0.8), // Softer border
                        width: 4.5), // Slightly thicker border
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]),
                child: CircleAvatar(
                  radius:
                      65, // Slightly smaller to give more space for border/shadow
                  backgroundColor: theme.colorScheme.surface,
                  backgroundImage: (photoURL != null && photoURL!.isNotEmpty)
                      ? NetworkImage(photoURL!)
                      : const AssetImage('assets/images/default_avatar.png')
                          as ImageProvider,
                  onBackgroundImageError: (_, __) {/* Handle error */},
                  child: (photoURL == null || photoURL!.isEmpty)
                      ? Icon(Icons.person_outline,
                          size: 70, color: Colors.grey[400])
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // Text color on dark banner
                    shadows: [
                      Shadow(
                          blurRadius: 1.0,
                          color: Colors.black.withOpacity(0.5),
                          offset: Offset(0.5, 0.5))
                    ]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '@$username',
                style: GoogleFonts.lato(
                    fontSize: 15,
                    color: theme.colorScheme.secondary,
                    shadows: [
                      Shadow(
                          blurRadius: 1.0,
                          color: Colors.black.withOpacity(0.5),
                          offset: Offset(0.5, 0.5))
                    ]),
                textAlign: TextAlign.center,
              ),
              if (bio != null && bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    bio!,
                    style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.45,
                        shadows: [
                          Shadow(
                              blurRadius: 1.0,
                              color: Colors.black.withOpacity(0.3),
                              offset: Offset(0.5, 0.5))
                        ]),
                    textAlign: TextAlign.center,
                    maxLines: 2, // Keep bio concise in header
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Level and experience bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Level $level',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.95))),
                        Text(
                            '${(experienceProgress * 100).toInt()}% to Lvl ${level + 1}',
                            style: GoogleFonts.lato(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: experienceProgress,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      valueColor: AlwaysStoppedAnimation<Color>(theme
                          .colorScheme
                          .secondary), // Use a vibrant secondary color
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
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
