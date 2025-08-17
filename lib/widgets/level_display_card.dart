import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_profile_model.dart';
import '../providers/auth_provider.dart';

class LevelDisplayCard extends StatelessWidget {
  final UserProfile userProfile;
  const LevelDisplayCard({super.key, required this.userProfile});

  String _getLevelTitle(int currentLevel) {
    if (currentLevel >= 100) return "Legendary Hiker";
    if (currentLevel >= 90) return "Supreme Voyager";
    if (currentLevel >= 80) return "Master Explorer";
    if (currentLevel >= 70) return "Grand Adventurer";
    if (currentLevel >= 60) return "Elite Navigator";
    if (currentLevel >= 50) return "Mountain Virtuoso";
    if (currentLevel >= 40) return "Seasoned Trekker";
    if (currentLevel >= 30) return "Peak Seeker";
    if (currentLevel >= 20) return "Highland Strider";
    if (currentLevel >= 15) return "Pathfinder";
    if (currentLevel >= 10) return "Explorer";
    if (currentLevel >= 5) return "Novice";
    return "Newbie";
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final theme = Theme.of(context);

    int totalExperienceToReachCurrentLevel = 0;
    for (int i = 1; i < userProfile.level; i++) {
      totalExperienceToReachCurrentLevel +=
          authProvider.getExperienceRequiredForLevel(i);
    }
    final int experienceRequiredForNextLevel =
        authProvider.getExperienceRequiredForLevel(userProfile.level);
    final int currentExperienceInCurrentLevel =
        userProfile.experience - totalExperienceToReachCurrentLevel;
    final double experienceProgress = (experienceRequiredForNextLevel > 0)
        ? (currentExperienceInCurrentLevel / experienceRequiredForNextLevel)
            .clamp(0.0, 1.0)
        : 0.0;

    final levelTitle = _getLevelTitle(userProfile.level);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_outlined,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Level ${userProfile.level} - $levelTitle',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: experienceProgress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 4),
          if (userProfile.level < 100)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${experienceRequiredForNextLevel - currentExperienceInCurrentLevel} XP to next level',
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
