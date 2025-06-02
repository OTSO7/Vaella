import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// This local Achievement class is used by the widget.
// The ProfilePage maps data to this.
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

    // Empty state is now handled in ProfilePage, so this check might be redundant
    // if ProfilePage doesn't render this widget when achievements are empty.
    // However, keeping it provides a fallback.
    if (achievements.isEmpty) {
      // This part can be removed if ProfilePage's _buildEmptySectionPlaceholder is always used.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isStickerGrid
                    ? Icons.collections_bookmark_outlined
                    : Icons.emoji_events_outlined,
                size: 50,
                color: theme.hintColor.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                isStickerGrid
                    ? 'No badges collected yet.'
                    : 'No achievements earned yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 16,
                  color: theme.hintColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 20.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isStickerGrid ? 4 : 3,
          crossAxisSpacing: isStickerGrid ? 10.0 : 12.0,
          mainAxisSpacing: isStickerGrid ? 10.0 : 12.0,
          childAspectRatio:
              isStickerGrid ? 1.0 : 0.9, // Adjust for better text fit
        ),
        itemCount: achievements.length,
        itemBuilder: (context, index) {
          final item = achievements[index];
          return InkWell(
            borderRadius: BorderRadius.circular(16), // Consistent rounding
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor:
                      theme.dialogBackgroundColor, // Use dialog theme color
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(20)), // More rounded dialog
                  titlePadding: const EdgeInsets.only(top: 24, bottom: 0),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
                  title: Column(
                    children: [
                      if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item.imageUrl!,
                            width: 70,
                            height: 70,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.broken_image_outlined,
                                size: 60,
                                color: theme.hintColor),
                          ),
                        )
                      else if (item.icon != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (item.iconColor ?? theme.colorScheme.primary)
                                .withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon,
                              size: 40,
                              color:
                                  item.iconColor ?? theme.colorScheme.primary),
                        ),
                      const SizedBox(height: 16),
                      Text(item.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(item.description,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(
                              fontSize: 15,
                              color: theme.colorScheme.onSurfaceVariant)),
                      if (item.dateAchieved != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Achieved: ${DateFormat('d MMM yyyy', Localizations.localeOf(context).languageCode).format(item.dateAchieved!)}',
                          style: GoogleFonts.lato(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.7)),
                        ),
                      ]
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Close',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.primary)),
                    )
                  ],
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16), // Increased rounding
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.08), // Softer shadow
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10), // Adjusted padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(
                          4.0), // Padding around icon/image
                      child: (item.imageUrl != null &&
                              item.imageUrl!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(8), // Rounded images
                              child: Image.network(
                                item.imageUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.broken_image_outlined,
                                        size: isStickerGrid ? 40 : 32,
                                        color:
                                            theme.hintColor.withOpacity(0.6)),
                              ),
                            )
                          : Icon(
                              item.icon ?? Icons.emoji_events_outlined,
                              size: isStickerGrid ? 36 : 30,
                              color: item.iconColor ??
                                  theme.colorScheme.secondary.withOpacity(0.8),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    flex: 2,
                    child: Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                          fontSize: isStickerGrid ? 10 : 11.5,
                          fontWeight: FontWeight.w500, // Slightly bolder title
                          color: theme.colorScheme.onSurface.withOpacity(0.85),
                          height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
