// lib/widgets/detailed_rating_display.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'star_rating_display.dart'; // Oletan, että tämä widget on olemassa

class DetailedRatingDisplay extends StatelessWidget {
  final IconData icon;
  final String title;
  final String label;
  final double ratingValue;

  const DetailedRatingDisplay({
    super.key,
    required this.icon,
    required this.title,
    required this.label,
    required this.ratingValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              StarRatingDisplay(
                  rating: ratingValue, size: 22, showLabel: false),
            ],
          ),
        ],
      ),
    );
  }
}
