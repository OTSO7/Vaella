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
        elevation:
            0, // Ei Cardin omaa varjoa, käytetään Containerin BoxShadowia
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)), // Pyöreämmät kulmat
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16.0, vertical: 20.0), // Sisäpadding
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Wrap(
            spacing: 16.0, // Horisontaalinen väli
            runSpacing: 20.0, // Vertikaalinen väli
            alignment: WrapAlignment.spaceAround, // Tasainen jakautuminen
            children: stats.entries.map((entry) {
              return SizedBox(
                // Rajoitetaan StatItemin leveyttä
                width: MediaQuery.of(context).size.width / 4 -
                    32, // Noin neljäsosa leveydestä miinus padding
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatIcon(entry.key),
                        size: 36,
                        color: theme.colorScheme.primary), // Isompi ikoni
                    const SizedBox(height: 8),
                    Text(
                      entry.value.toString(),
                      style: textTheme.headlineSmall?.copyWith(
                          // Isompi ja lihavampi arvo
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.key,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                          // Pienempi label
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
