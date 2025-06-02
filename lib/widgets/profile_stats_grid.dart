import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileStatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;

  const ProfileStatsGrid({super.key, required this.stats});

  IconData _getStatIcon(String label) {
    switch (label.toLowerCase()) {
      case 'vaelluksia':
        return Icons.hiking_rounded;
      case 'kilometrejä':
        return Icons.route_outlined; // More thematic icon
      case 'huippuja':
        return Icons.flag_circle_outlined; // More thematic icon
      case 'kuvia jaettu':
        return Icons.photo_library_rounded;
      default:
        return Icons.star_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter out stats that might not be numbers or are zero, if desired
    final filteredStats = Map.fromEntries(stats.entries.where((entry) =>
        entry.value is num && entry.value > 0 ||
        entry.key.toLowerCase() == 'vaelluksia'));

    // If no significant stats, display a placeholder or fewer items.
    // For now, we display all provided stats.
    final statEntries = stats.entries.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Display 2 stats per row for more prominence
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 2.2, // Adjust aspect ratio for a wider card
        ),
        itemCount: statEntries.length,
        itemBuilder: (context, index) {
          final entry = statEntries[index];
          return Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.cardColor, // Use card color from theme
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.05), // Softer shadow
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(_getStatIcon(entry.key),
                    size: 32, // Slightly smaller icon as text is more prominent
                    color: theme.colorScheme.primary),
                const SizedBox(height: 10),
                Text(
                  entry.value.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 22, // Larger value
                    fontWeight: FontWeight.w700, // Bolder
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.key,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 13, // Clear label
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
