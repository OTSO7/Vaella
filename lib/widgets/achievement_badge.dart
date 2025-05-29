// lib/widgets/achievement_badge.dart
import 'package:flutter/material.dart';

enum BadgeType { achievement, sticker }

class AchievementBadge extends StatelessWidget {
  final String title;
  final IconData? icon; // Saavutuksille
  final String? imageUrl; // Tarroille
  final Color? iconColor;
  final BadgeType type;
  final VoidCallback? onTap;

  const AchievementBadge({
    super.key,
    required this.title,
    this.icon,
    this.imageUrl,
    this.iconColor,
    required this.type,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: title,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                )
              ]),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (type == BadgeType.achievement && icon != null)
                Icon(icon,
                    size: 32, color: iconColor ?? theme.colorScheme.primary)
              else if (type == BadgeType.sticker && imageUrl != null)
                Image.network(
                  imageUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.image_not_supported_outlined,
                      size: 32,
                      color: Colors.grey[600]),
                )
              else
                Icon(Icons.emoji_events_outlined,
                    size: 32, color: Colors.grey[600]), // Fallback
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
