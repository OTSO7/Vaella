// lib/widgets/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffoldWithBottomNav extends StatelessWidget {
  const MainScaffoldWithBottomNav({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body:
          navigationShell, // Tämä näyttää aktiivisen sivun (Home, Notes, Profile)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            // Jos halutaan, että sivu palautuu alkuun vaihdettaessa takaisin tabille:
            // initialLocation: index == navigationShell.currentIndex,
          );
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Koti',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Omat vaellukset',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profiili',
          ),
        ],
        backgroundColor:
            theme.colorScheme.surface, // Voit muokata teeman mukaan
        selectedItemColor: theme.colorScheme.secondary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        type: BottomNavigationBarType.fixed, // Tai .shifting
        // showSelectedLabels: true,
        // showUnselectedLabels: false,
      ),
    );
  }
}
