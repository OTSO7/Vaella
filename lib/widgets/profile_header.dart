// lib/widgets/profile_header.dart
import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String username; // Uusi: Käyttäjätunnus näkyvissä
  final String displayName;
  final String? photoURL;
  final String? bio;
  final String? bannerImageUrl; // UUSI: Bannerikuva
  final VoidCallback onEditProfile;
  final int level; // Esimerkkitaso
  final double experienceProgress; // Esim. 0.0 - 1.0

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
        // Bannerikuva
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: (bannerImageUrl != null && bannerImageUrl!.isNotEmpty)
                    ? NetworkImage(bannerImageUrl!)
                    : const AssetImage('assets/images/default_banner.jpg')
                        as ImageProvider, // OLETUS BANNERIKUVA
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black
                      .withOpacity(0.4), // Tummempi, jotta teksti erottuu
                  BlendMode.darken,
                ),
              ),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30)), // Pyöreämpi alareuna
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 50, right: 16), // Säädetty padding
                child: IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: Colors.white.withOpacity(0.9),
                      size: 28), // Isompi ikoni
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Colors.black.withOpacity(0.4), // Tummempi tausta
                    shape: const CircleBorder(), // Pyöreä tausta
                    padding: const EdgeInsets.all(12), // Pienempi padding
                  ),
                  tooltip: 'Muokkaa profiilia',
                  onPressed: onEditProfile,
                ),
              ),
            ),
          ),
        ),

        // Profiilikuva ja tiedot
        Positioned(
          bottom: 0, // Asetetaan pohjaan
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 4), // Kehys profiilikuvalle
                ),
                child: CircleAvatar(
                  radius: 70, // Isompi profiilikuva
                  backgroundColor: theme.colorScheme.surface,
                  backgroundImage: (photoURL != null && photoURL!.isNotEmpty)
                      ? NetworkImage(photoURL!)
                      : const AssetImage('assets/images/default_avatar.png')
                          as ImageProvider,
                  onBackgroundImageError: (_, __) {
                    // Käsittele virhe, jos kuvaa ei voida ladata
                  },
                  child: (photoURL == null || photoURL!.isEmpty)
                      ? Icon(Icons.person, size: 80, color: Colors.grey[500])
                      : null,
                ),
              ),
              const SizedBox(height: 16), // Väli profiilikuvan ja nimen välissä
              Text(
                displayName,
                style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground),
              ),
              Text(
                '@$username', // Käyttäjätunnus
                style: textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onBackground.withOpacity(0.6)),
              ),
              if (bio != null && bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    bio!,
                    style: textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onBackground.withOpacity(0.8),
                        height: 1.4),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 24), // Väli biosta tilastoihin

              // Taso- ja kokemuspalkki
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Taso $level',
                            style: textTheme.titleMedium
                                ?.copyWith(color: theme.colorScheme.secondary)),
                        Text(
                            '${(experienceProgress * 100).toInt()}% seuraavaan tasoon',
                            style: textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onBackground
                                    .withOpacity(0.7))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: experienceProgress,
                      backgroundColor: theme.colorScheme.surfaceVariant
                          .withOpacity(0.3), // Vaaleampi tausta
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.secondary),
                      minHeight: 8, // Paksumpi palkki
                      borderRadius:
                          BorderRadius.circular(4), // Pyöreämmät kulmat
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
