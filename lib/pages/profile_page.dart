// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user_profile_model.dart';
import '../widgets/profile_header.dart';
import '../widgets/stat_item.dart';
import '../widgets/achievement_badge.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late UserProfile _userProfile;

  @override
  void initState() {
    super.initState();
    // final auth = Provider.of<AuthProvider>(context, listen: false); // Poistettu, koska ei käytetty alla olevassa dummy-datassa
    _userProfile = UserProfile(
      uid: 'dummy_uid_123',
      displayName: 'Otto Saarimaa',
      email: 'valtteri@example.com',
      photoURL: 'assets/images/header2.jpg',
      bio: 'Innokas luonnossa liikkuja ja valokuvauksen harrastaja.',
      stats: {
        'Vaelluksia': 27,
        'Kilometrejä': 345.8,
        'Huippuja': 12,
        'Kuvia jaettu': 88,
      },
      achievements: [
        Achievement(
            id: 'ach1',
            title: 'Ensimmäinen 10km',
            description: 'Kävelit ensimmäisen 10km vaelluksesi!',
            icon: Icons.directions_walk,
            dateAchieved: DateTime(2023, 5, 10),
            iconColor: Colors.green),
        Achievement(
            id: 'ach2',
            title: 'Yö ulkona',
            description: 'Vietit ensimmäisen yösi teltassa.',
            icon: Icons.nights_stay_outlined,
            dateAchieved: DateTime(2023, 7, 22),
            iconColor: Colors.blue),
        Achievement(
            id: 'ach3',
            title: 'Huippujen valloittaja',
            description: 'Valloitit 5 eri huippua.',
            icon: Icons.landscape_outlined,
            dateAchieved: DateTime(2024, 1, 15),
            iconColor: Colors.purpleAccent),
        Achievement(
            id: 'ach4',
            title: 'Valokuvaajamestari',
            description: 'Jaoit yli 50 kuvaa.',
            icon: Icons.camera_alt_outlined,
            dateAchieved: DateTime(2024, 3, 5),
            iconColor: Colors.orange),
      ],
      stickers: [
        Sticker(
            id: 'st1',
            name: 'Nuuksio',
            imageUrl:
                'https://via.placeholder.com/100/8BC34A/FFFFFF?Text=Nuuksio'),
        Sticker(
            id: 'st2',
            name: 'Koli',
            imageUrl:
                'https://via.placeholder.com/100/2196F3/FFFFFF?Text=Koli'),
      ],
    );
  }

  void _navigateToEditProfile() async {
    // Varmista, että widget on yhä puussa ennen navigointia
    if (!mounted) return;
    final updatedProfile = await context.push<UserProfile>(
      '/profile/edit',
      extra: _userProfile,
    );

    if (updatedProfile != null && mounted) {
      setState(() {
        _userProfile = updatedProfile;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profiili päivitetty!'),
            backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 380.0,
            floating: false,
            pinned: true, // AppBar pysyy näkyvissä skrollatessa
            elevation: 1,
            backgroundColor: theme.colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: ProfileHeader(
                photoURL: _userProfile.photoURL,
                displayName: _userProfile.displayName,
                bio: _userProfile.bio,
                onEditProfile: _navigateToEditProfile,
                level: (_userProfile.stats['Vaelluksia'] ?? 0) ~/ 5 + 1,
                experienceProgress:
                    ((_userProfile.stats['Vaelluksia'] ?? 0) % 5) / 5.0,
              ),
            ),
          ),

          _buildSectionHeader(context, 'Tilastot', Icons.bar_chart_outlined),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 16.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 16.0,
                    alignment: WrapAlignment.spaceAround,
                    children: _userProfile.stats.entries.map((entry) {
                      IconData iconData = Icons.star_border_outlined;
                      if (entry.key.toLowerCase().contains('vaelluksia'))
                        iconData = Icons.hiking;
                      if (entry.key.toLowerCase().contains('kilometr'))
                        iconData = Icons.timeline;
                      if (entry.key.toLowerCase().contains('huippu'))
                        iconData = Icons.flag_outlined;
                      if (entry.key.toLowerCase().contains('kuvia'))
                        iconData = Icons.photo_library_outlined;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0), // Pieni lisäys Wrapin sisällä
                        child: StatItem(
                            icon: iconData,
                            label: entry.key,
                            value: entry.value.toString()),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          _buildSectionHeader(
              context, 'Saavutukset', Icons.emoji_events_outlined),
          _userProfile.achievements.isEmpty
              ? SliverToBoxAdapter(
                  child: _buildEmptySectionPlaceholder(
                      context, 'Ei vielä saavutuksia.'))
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      16.0, 8.0, 16.0, 12.0), // Pienennetty bottom
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12.0,
                      mainAxisSpacing: 12.0,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final achievement = _userProfile.achievements[index];
                        return AchievementBadge(
                          title: achievement.title,
                          icon: achievement.icon,
                          iconColor: achievement.iconColor,
                          type: BadgeType.achievement,
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                      title: Row(children: [
                                        Icon(achievement.icon,
                                            color: achievement.iconColor),
                                        const SizedBox(width: 8),
                                        Text(achievement.title)
                                      ]),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(achievement.description),
                                          const SizedBox(height: 8),
                                          Text(
                                              'Ansaittu: ${DateFormat('d.M.yyyy', 'fi_FI').format(achievement.dateAchieved)}',
                                              style: theme.textTheme.bodySmall),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: const Text('Sulje'))
                                      ],
                                    ));
                          },
                        );
                      },
                      childCount: _userProfile.achievements.length,
                    ),
                  ),
                ),

          _buildSectionHeader(
              context, 'Kerätyt Tarrat', Icons.collections_bookmark_outlined),
          _userProfile.stickers.isEmpty
              ? SliverToBoxAdapter(
                  child: _buildEmptySectionPlaceholder(
                      context, 'Ei vielä kerättyjä tarroja.'))
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      16.0, 8.0, 16.0, 12.0), // Pienennetty bottom
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10.0,
                      mainAxisSpacing: 10.0,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final sticker = _userProfile.stickers[index];
                        return AchievementBadge(
                          title: sticker.name,
                          imageUrl: sticker.imageUrl,
                          type: BadgeType.sticker,
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                      title: Text(sticker.name),
                                      content: Image.network(sticker.imageUrl,
                                          fit: BoxFit.contain, height: 100),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: const Text('Sulje'))
                                      ],
                                    ));
                          },
                        );
                      },
                      childCount: _userProfile.stickers.length,
                    ),
                  ),
                ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  24.0, 20.0, 24.0, 16.0), // Pienennetty ylätäytettä
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Kirjaudu ulos'),
                onPressed: () {
                  authProvider.logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
              child: SizedBox(
                  height: kBottomNavigationBarHeight +
                      8.0)), // Pieni vähennys täälläkin
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
            left: 20.0,
            right: 16.0,
            top: 24.0, // <<<--- MUUTETTU (oli aiemmin 22.0 tai 28.0)
            bottom: 10.0), // <<<--- MUUTETTU (oli aiemmin 10.0 tai 8.0)
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySectionPlaceholder(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_off_outlined,
                size: 48,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
