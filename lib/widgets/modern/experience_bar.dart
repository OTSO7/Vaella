// lib/widgets/modern/experience_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_profile_model.dart';
import '../../providers/auth_provider.dart';

class ExperienceBar extends StatelessWidget {
  final UserProfile userProfile;

  const ExperienceBar({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Luodaan väliaikainen instanssi providerista vain laskentaa varten.
    // Tämä on OK, koska käytämme vain sen puhtaita funktioita.
    final authProvider = AuthProvider();

    final currentLevel = userProfile.level;
    final xpForCurrentLevel =
        authProvider.getExperienceRequiredForLevel(currentLevel);

    final totalXpForCurrentLevelStart =
        _getTotalExperienceToReachLevel(authProvider, currentLevel);
    final currentLevelProgressXp =
        userProfile.experience - totalXpForCurrentLevelStart;
    final xpNeededForThisLevel = xpForCurrentLevel;

    final progress =
        (currentLevelProgressXp / xpNeededForThisLevel).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Level ${userProfile.level}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            Text('$currentLevelProgressXp / $xpNeededForThisLevel XP',
                style: GoogleFonts.lato(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

int _getTotalExperienceToReachLevel(AuthProvider provider, int targetLevel) {
  int totalXp = 0;
  for (int i = 1; i < targetLevel; i++) {
    totalXp += provider.getExperienceRequiredForLevel(i);
  }
  return totalXp;
}
