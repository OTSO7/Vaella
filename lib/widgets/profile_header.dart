// lib/widgets/profile_header.dart
import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String? photoURL;
  final String displayName;
  final String? bio;
  final VoidCallback onEditProfile;
  final int level; // Esimerkkitaso pelaajaprofiilista
  final double experienceProgress; // Esim. 0.0 - 1.0

  const ProfileHeader({
    super.key,
    required this.photoURL,
    required this.displayName,
    this.bio,
    required this.onEditProfile,
    this.level = 1,
    this.experienceProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 180, // Tilaa taustakuvalle ja avatarille
          child: Stack(
            clipBehavior: Clip.none, // Salli avatarin mennä reunan yli
            alignment: Alignment.center,
            children: [
              // Taustakuva (banneri)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(photoURL ??
                            'https://picsum.photos/seed/profilebanner/800/200'), // Placeholder banner
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.3),
                          BlendMode.darken,
                        ),
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      )),
                ),
              ),
              // Profiilikuva
              Positioned(
                bottom:
                    -50, // Puolet avatarin koosta, jotta se on puoliksi ulkona
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor:
                      theme.colorScheme.surface, // Tausta avatarille
                  child: CircleAvatar(
                    radius: 56,
                    backgroundImage: photoURL != null && photoURL!.isNotEmpty
                        ? NetworkImage(photoURL!)
                        : const AssetImage('assets/images/default_avatar.png')
                            as ImageProvider, // LISÄÄ OLETUSAVATAR ASSETS-KANSIOON!
                    onBackgroundImageError: (_, __) {
                      // Käsittele virhe, jos kuvaa ei voida ladata
                    },
                    backgroundColor:
                        Colors.grey[800], // Fallback, jos kuva puuttuu
                    child: photoURL == null || photoURL!.isEmpty
                        ? Icon(Icons.person, size: 60, color: Colors.grey[500])
                        : null,
                  ),
                ),
              ),
              // Muokkaa-nappi
              Positioned(
                top: 50,
                right: 10,
                child: IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: Colors.white.withOpacity(0.9)),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.3)),
                  tooltip: 'Muokkaa profiilia',
                  onPressed: onEditProfile,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 60), // Tilaa avatarille
        Text(
          displayName,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        if (bio != null && bio!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              bio!,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Esimerkki tasosta ja kokemuspalkista
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Taso $level',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.secondary)),
                  Text(
                      '${(experienceProgress * 100).toInt()}% seuraavaan tasoon',
                      style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: experienceProgress,
                backgroundColor: theme.colorScheme.surfaceVariant,
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
