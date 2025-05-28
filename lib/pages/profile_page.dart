import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Päivämäärien muotoiluun
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user_profile_model.dart' as user_model;
import '../widgets/profile_header.dart'; // Profiilin yläosan widget
import '../widgets/profile_stats_grid.dart'; // Tilastojen esitykseen
import '../widgets/achievement_grid.dart'
    as achievement_widget; // Alias lisätty
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore-tietokannan käyttö

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Ei enää _userProfile-statea täällä, haetaan se AuthProviderista

  // Simuloitu data (poistetaan myöhemmin, kun data tulee Firestoresta)
  user_model.UserProfile _createDummyProfile(
      String uid, String username, String email) {
    return user_model.UserProfile(
      uid: uid,
      username: username,
      displayName: 'Otto Seikkailija',
      email: email,
      photoURL: 'https://i.pravatar.cc/300?img=68', // Esimerkkiprofiilikuva
      bio:
          'Innokas luonnossa liikkuja ja valokuvauksen harrastaja. Aina valmis uusiin seikkailuihin!',
      bannerImageUrl:
          'https://picsum.photos/seed/profilebanner1/1200/400', // Esimerkkibannerikuva
      stats: {
        'Vaelluksia': 27,
        'Kilometrejä': 345.8,
        'Huippuja': 12,
        'Kuvia jaettu': 88,
      },
      achievements: [
        user_model.Achievement(
            id: 'ach1',
            title: 'Ensimmäinen 10km',
            description: 'Kävelit ensimmäisen 10km vaelluksesi!',
            icon: Icons.directions_walk_outlined,
            dateAchieved: DateTime(2023, 5, 10),
            iconColor: Colors.lightGreen),
        user_model.Achievement(
            id: 'ach2',
            title: 'Yö ulkona',
            description: 'Vietit ensimmäisen yösi teltassa.',
            icon: Icons.nights_stay_outlined,
            dateAchieved: DateTime(2023, 7, 22),
            iconColor: Colors.blueAccent),
        user_model.Achievement(
            id: 'ach3',
            title: 'Huippujen valloittaja',
            description: 'Valloitit 5 eri huippua.',
            icon: Icons.landscape_outlined,
            dateAchieved: DateTime(2024, 1, 15),
            iconColor: Colors.purpleAccent),
        user_model.Achievement(
            id: 'ach4',
            title: 'Valokuvaajamestari',
            description: 'Jaoit yli 50 kuvaa.',
            icon: Icons.camera_alt_outlined,
            dateAchieved: DateTime(2024, 3, 5),
            iconColor: Colors.orangeAccent),
        user_model.Achievement(
            id: 'ach5',
            title: 'Talvivaeltaja',
            description: 'Teit vaelluksen lumisessa maastossa.',
            icon: Icons.ac_unit_outlined,
            dateAchieved: DateTime(2024, 2, 1),
            iconColor: Colors.lightBlue),
      ],
      stickers: [
        user_model.Sticker(
            id: 'st1',
            name: 'Nuuksio NP',
            imageUrl: 'https://picsum.photos/seed/nuuksiobadge/100/100'),
        user_model.Sticker(
            id: 'st2',
            name: 'Koli NP',
            imageUrl: 'https://picsum.photos/seed/kolibadge/100/100'),
        user_model.Sticker(
            id: 'st3',
            name: 'Oulanka NP',
            imageUrl: 'https://picsum.photos/seed/oulankabadge/100/100'),
        user_model.Sticker(
            id: 'st4',
            name: 'Repovesi NP',
            imageUrl: 'https://picsum.photos/seed/repovesibadge/100/100'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    if (!authProvider.isLoggedIn || authProvider.userProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profiili')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              authProvider.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Ladataan profiilia...'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => authProvider.logout(),
                child: const Text('Kirjaudu ulos'),
              ),
            ],
          ),
        ),
      );
    }

    final user_model.UserProfile userProfile = authProvider.userProfile!;

    // Funktio profiilin muokkaukseen navigointiin
    void navigateToEditProfile() async {
      final updatedProfile = await context.push<user_model.UserProfile>(
        '/profile/edit',
        extra: userProfile,
      );

      if (updatedProfile != null && mounted) {
        await authProvider.updateLocalUserProfile(updatedProfile);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profiili päivitetty onnistuneesti!'),
              backgroundColor: Colors.green),
        );
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 320.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: IconButton(
              icon: Icon(Icons.logout, color: theme.colorScheme.onBackground),
              tooltip: 'Kirjaudu ulos',
              onPressed: () {
                authProvider.logout();
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: ProfileHeader(
                username: userProfile.username,
                displayName: userProfile.displayName,
                photoURL: userProfile.photoURL,
                bio: userProfile.bio,
                bannerImageUrl: userProfile.bannerImageUrl,
                onEditProfile: navigateToEditProfile,
                level: (userProfile.stats['Vaelluksia'] ?? 0) ~/ 5 + 1,
                experienceProgress:
                    ((userProfile.stats['Vaelluksia'] ?? 0) % 5) / 5.0,
              ),
            ),
            // Poistettu actions-lista, logout on nyt leadingissä
          ),
          _buildSectionHeader(context, 'Tilastot', Icons.bar_chart_outlined),
          SliverToBoxAdapter(
            child: ProfileStatsGrid(stats: userProfile.stats),
          ),
          _buildSectionHeader(
              context, 'Saavutukset', Icons.emoji_events_outlined),
          userProfile.achievements.isEmpty
              ? SliverToBoxAdapter(
                  child: _buildEmptySectionPlaceholder(
                      context, 'Ei vielä saavutuksia. Lähde seikkailemaan!'))
              : SliverToBoxAdapter(
                  child: achievement_widget.AchievementGrid(
                    achievements: userProfile.achievements
                        .map((a) => achievement_widget.Achievement(
                              title: a.title,
                              description: a.description,
                              icon: a.icon,
                              dateAchieved: a.dateAchieved,
                              iconColor: a.iconColor,
                              imageUrl: a is achievement_widget.Achievement
                                  ? a.imageUrl
                                  : null,
                            ))
                        .toList(),
                    isStickerGrid: false,
                  ),
                ),
          _buildSectionHeader(context, 'Kansallispuistomerkit',
              Icons.collections_bookmark_outlined),
          userProfile.stickers.isEmpty
              ? SliverToBoxAdapter(
                  child: _buildEmptySectionPlaceholder(
                      context, 'Ei vielä kerättyjä kansallispuistomerkkejä.'))
              : SliverToBoxAdapter(
                  child: achievement_widget.AchievementGrid(
                    achievements: userProfile.stickers
                        .map((s) => achievement_widget.Achievement(
                              title: s.name,
                              description: s.name,
                              imageUrl: s.imageUrl,
                              dateAchieved: DateTime.now(),
                              icon: Icons.park_outlined,
                            ))
                        .toList(),
                    isStickerGrid: true,
                  ),
                ),
          SliverToBoxAdapter(
              child: SizedBox(height: kBottomNavigationBarHeight + 16.0)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySectionPlaceholder(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
