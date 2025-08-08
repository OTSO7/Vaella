import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_profile_model.dart';
import 'modern/interactive_follow_button.dart';

class UserSearchListTile extends StatelessWidget {
  final UserProfile userProfile;
  final VoidCallback onTap;

  const UserSearchListTile({
    super.key,
    required this.userProfile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Turvalliset arvot tekstikentille
    final safeDisplayName = (userProfile.displayName.isNotEmpty)
        ? userProfile.displayName
        : 'Unknown';
    final safeUsername =
        (userProfile.username.isNotEmpty) ? userProfile.username : 'unknown';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Profiilikuva
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: (userProfile.photoURL != null &&
                      userProfile.photoURL!.isNotEmpty)
                  ? CachedNetworkImageProvider(userProfile.photoURL!)
                  : null,
              child: (userProfile.photoURL == null ||
                      userProfile.photoURL!.isEmpty)
                  ? Text(
                      safeDisplayName[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Tekstit ja seuraa-painike
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Käyttäjätiedot
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          safeDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@$safeUsername',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.lato(
                            color: theme.hintColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Seuraa-nappi rajoitetulla leveydellä
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 80,
                      maxWidth: 120,
                    ),
                    child: InteractiveFollowButton(
                      targetUserId: userProfile.uid,
                      initialRelation: userProfile.relationToCurrentUser,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
