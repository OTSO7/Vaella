// lib/widgets/user_hikes_map_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserHikesMapSection extends StatelessWidget {
  final String userId;
  const UserHikesMapSection({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_rounded, size: 60, color: theme.hintColor),
            const SizedBox(height: 16),
            Text(
              'Hike Map',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'A map showing all completed hikes will appear here soon. Keep exploring!',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(fontSize: 15, color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }
}
