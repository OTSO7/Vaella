// lib/widgets/profile_counts_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ProfileCountsBar extends StatelessWidget {
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final VoidCallback?
      onPostsTap; // Tämä callback kutsutaan, kun "Posts" napautetaan
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const ProfileCountsBar({
    super.key,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    this.onPostsTap, // ProfilePage välittää tähän funktion, joka navigoi
    this.onFollowersTap,
    this.onFollowingTap,
  });

  Widget _buildCountItem(
      BuildContext context, String label, int count, VoidCallback? onTap) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap, // Kutsutaan annettua callbackia
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                NumberFormat.compact().format(count),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 19,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
                color: theme.dividerColor.withOpacity(0.6), width: 1.0),
          )),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildCountItem(context, 'Posts', postsCount,
              onPostsTap), // Välitetään onPostsTap eteenpäin
          _buildCountItem(context, 'Followers', followersCount, onFollowersTap),
          _buildCountItem(context, 'Following', followingCount, onFollowingTap),
        ],
      ),
    );
  }
}
