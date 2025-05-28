// lib/widgets/achievement_grid.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Päivämäärien muotoiluun

enum BadgeType { achievement, sticker }

// Yksinkertainen Achievement-luokka malliksi:
class Achievement {
  final String title;
  final String description;
  final String? imageUrl;
  final IconData? icon;
  final Color? iconColor;
  final DateTime? dateAchieved;

  Achievement({
    required this.title,
    required this.description,
    this.imageUrl,
    this.icon,
    this.iconColor,
    this.dateAchieved,
  });
}

class AchievementGrid extends StatelessWidget {
  final List<Achievement> achievements;
  final bool isStickerGrid;

  const AchievementGrid({
    super.key,
    required this.achievements,
    this.isStickerGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    if (achievements.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isStickerGrid
                    ? Icons.collections_bookmark_outlined
                    : Icons.emoji_events_outlined,
                size: 60,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 12),
              Text(
                isStickerGrid
                    ? 'Ei kerättyjä kansallispuistomerkkejä vielä.'
                    : 'Ei vielä saavutuksia. Lähde seikkailemaan!',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isStickerGrid ? 4 : 3,
          crossAxisSpacing: 10.0,
          mainAxisSpacing: 10.0,
          childAspectRatio: 1.0,
        ),
        itemCount: achievements.length,
        itemBuilder: (context, index) {
          final item = achievements[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: theme.cardColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Column(
                    children: [
                      if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                        Image.network(
                          item.imageUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.image_not_supported_outlined,
                              size: 60,
                              color: Colors.grey[600]),
                        )
                      else if (item.icon != null)
                        Icon(item.icon,
                            size: 60,
                            color: item.iconColor ?? theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(item.title,
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(item.description,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      if (item.dateAchieved != null)
                        Text(
                          'Ansaittu: ${DateFormat('d.M.yyyy', 'fi_FI').format(item.dateAchieved!)}',
                          style: textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6)),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Sulje',
                          style: textTheme.labelLarge
                              ?.copyWith(color: theme.colorScheme.secondary)),
                    )
                  ],
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    Image.network(
                      item.imageUrl!,
                      width: isStickerGrid ? 50 : 40,
                      height: isStickerGrid ? 50 : 40,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.image_not_supported_outlined,
                          size: isStickerGrid ? 50 : 40,
                          color: Colors.grey[600]),
                    )
                  else if (item.icon != null)
                    Icon(
                      item.icon,
                      size: isStickerGrid ? 40 : 32,
                      color: item.iconColor ?? theme.colorScheme.primary,
                    )
                  else
                    Icon(
                      Icons.emoji_events_outlined,
                      size: isStickerGrid ? 40 : 32,
                      color: Colors.grey[600],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withOpacity(0.9)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
