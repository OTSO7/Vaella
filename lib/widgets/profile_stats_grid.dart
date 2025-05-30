// lib/widgets/profile_stats_grid.dart
import 'package:flutter/material.dart';

class ProfileStatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;

  const ProfileStatsGrid({super.key, required this.stats});

  IconData _getStatIcon(String label) {
    switch (label.toLowerCase()) {
      case 'vaelluksia':
        return Icons.hiking;
      case 'kilometrejä':
        return Icons.timeline;
      case 'huippuja':
        return Icons.flag_outlined;
      case 'kuvia jaettu':
        return Icons.photo_library_outlined;
      default:
        return Icons.star_border_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        color: theme.cardColor,
        elevation: 0, // No Card shadow, use Container's BoxShadow if needed
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)), // More rounded corners
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16.0, vertical: 20.0), // Inner padding
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Wrap(
            spacing: 16.0, // Horizontal spacing
            runSpacing: 20.0, // Vertical spacing
            alignment: WrapAlignment.spaceAround, // Even distribution
            children: stats.entries.map((entry) {
              return SizedBox(
                // Limit StatItem width
                width: MediaQuery.of(context).size.width / 4 -
                    32, // About a quarter of width minus padding
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatIcon(entry.key),
                        size: 36,
                        color: theme.colorScheme.primary), // Larger icon
                    const SizedBox(height: 8),
                    Text(
                      entry.value.toString(),
                      style: textTheme.headlineSmall?.copyWith(
                          // Larger and bolder value
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.key,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                          // Smaller label
                          color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
