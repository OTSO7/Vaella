// lib/widgets/star_rating_display.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final int starCount;
  final double size;
  final Color color;
  final bool showLabel;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.starCount = 5,
    this.size = 20.0,
    this.color = Colors.amber,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.poppins(
              fontSize: size * 0.8,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        if (showLabel) SizedBox(width: size * 0.3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(starCount, (index) {
            IconData iconData = Icons.star_border_rounded;
            if (index < rating) {
              iconData = index + 0.5 < rating
                  ? Icons.star_rounded
                  : Icons.star_half_rounded;
            }
            return Icon(iconData, size: size, color: color);
          }),
        ),
      ],
    );
  }
}
