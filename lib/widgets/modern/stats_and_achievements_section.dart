// lib/widgets/modern/stats_and_achievements_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_profile_model.dart';
import '../achievement_grid.dart' as achievement_widget;

class StatsAndAchievementsSection extends StatelessWidget {
  final UserProfile userProfile;

  const StatsAndAchievementsSection({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, 'Key Stats'),
          _buildStatsGrid(context, userProfile.hikeStats),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'National Park Badges'),
          _buildBadgesSection(context, userProfile.stickers),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'All Achievements'),
          _buildAchievementsSection(context, userProfile.achievements),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, HikeStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          _StatCard(
              label: 'Total Hikes',
              value: stats.totalHikes.toString(),
              icon: Icons.directions_walk),
          _StatCard(
              label: 'Distance',
              value: '${stats.totalDistance.toStringAsFixed(1)} km',
              icon: Icons.map_outlined),
          _StatCard(
              label: 'Highest Peak',
              value: '${stats.highestAltitude.toStringAsFixed(0)} m',
              icon: Icons.filter_hdr),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(BuildContext context, List<Sticker> stickers) {
    if (stickers.isEmpty) {
      return _buildEmptyPlaceholder(context, 'No badges collected yet.',
          Icons.collections_bookmark_outlined);
    }
    return achievement_widget.AchievementGrid(
      achievements: stickers
          .map((s) => achievement_widget.Achievement(
                title: s.name,
                description: '',
                imageUrl: s.imageUrl,
              ))
          .toList(),
      isStickerGrid: true,
    );
  }

  Widget _buildAchievementsSection(
      BuildContext context, List<Achievement> achievements) {
    if (achievements.isEmpty) {
      return _buildEmptyPlaceholder(
          context, 'No achievements earned yet.', Icons.emoji_events_outlined);
    }
    return achievement_widget.AchievementGrid(
      achievements: achievements
          .map((a) => achievement_widget.Achievement(
                title: a.title,
                description: a.description,
                icon: a.icon,
                iconColor: a.iconColor,
                dateAchieved: a.dateAchieved,
              ))
          .toList(),
    );
  }

  Widget _buildEmptyPlaceholder(
      BuildContext context, String text, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: theme.hintColor.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(text, style: GoogleFonts.lato(color: theme.hintColor)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.primary),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              Text(label,
                  style: GoogleFonts.lato(
                      fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
