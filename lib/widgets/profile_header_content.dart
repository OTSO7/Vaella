// lib/widgets/profile_header_content.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/user_profile_model.dart';
import '../providers/auth_provider.dart';
import 'level_display_card.dart'; // Varmista, että tämä widget on olemassa

class ProfileHeaderContent extends StatelessWidget {
  final UserProfile userProfile;

  const ProfileHeaderContent({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ylärivi: Profiilikuva ja toimintopainikkeet
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: theme.colorScheme.surfaceVariant,
                backgroundImage: (userProfile.photoURL != null &&
                        userProfile.photoURL!.isNotEmpty)
                    ? NetworkImage(userProfile.photoURL!)
                    : const AssetImage('assets/images/default_avatar.png')
                        as ImageProvider,
              ),
              const SizedBox(width: 16),
              // Toimintopainikkeet (Muokkaa / Seuraa)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _buildActionButtons(context, userProfile),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Nimi, käyttäjänimi ja bio
          Text(
            userProfile.displayName,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '@${userProfile.username}',
            style: GoogleFonts.lato(
              fontSize: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (userProfile.bio != null && userProfile.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              userProfile.bio!,
              style: GoogleFonts.lato(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Level- ja XP-palkki
          LevelDisplayCard(userProfile: userProfile),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, UserProfile user) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    switch (user.relationToCurrentUser) {
      case UserRelation.self:
        return OutlinedButton(
          onPressed: () => context.push('/profile/edit', extra: user),
          child: const Text('Edit Profile'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
        );
      case UserRelation.following:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Messaging coming soon!"))),
              child: const Text('Message'),
              style: ElevatedButton.styleFrom(elevation: 0),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => authProvider.unfollowUser(user.uid),
              child: const Text('Following'),
            ),
          ],
        );
      case UserRelation.notFollowing:
        return ElevatedButton(
          onPressed: () => authProvider.followUser(user.uid),
          style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
          child: const Text('Follow'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
