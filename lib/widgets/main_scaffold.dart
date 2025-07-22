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
            // initialLocation: index == navigationShell.currentIndex, // Poistettu, jos ei käytössä
          );
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label:
                'Explore', // Muutettu suomeksi, jos sovellus on suomenkielinen
            // tooltip: 'Koti', // Varmistetaan, ettei tooltip-attribuuttia ole tässä
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Planner', // Muutettu suomeksi
            // tooltip: 'Omat suunnitelmat', // Varmistetaan, ettei tooltip-attribuuttia ole tässä
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile', // Muutettu suomeksi
            // tooltip: 'Profiili', // Varmistetaan, ettei tooltip-attribuuttia ole tässä
          ),
        ],
        // Seuraavat ominaisuudet ovat jo määritelty AppRouterissa bottomNavigationBarThemen kautta,
        // joten niitä ei välttämättä tarvitse asettaa tässä uudelleen, ellei haluta yliajaa teemaa.
        // Jos AppRouterin teema toimii, nämä voi poistaa selkeyden vuoksi.
        // backgroundColor: theme.bottomNavigationBarTheme.backgroundColor ?? theme.colorScheme.surface,
        // selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor ?? theme.colorScheme.secondary,
        // unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor ?? theme.colorScheme.onSurface.withOpacity(0.6),
        // type: theme.bottomNavigationBarTheme.type ?? BottomNavigationBarType.fixed,
        // selectedLabelStyle: theme.bottomNavigationBarTheme.selectedLabelStyle,
        // unselectedLabelStyle: theme.bottomNavigationBarTheme.unselectedLabelStyle,
      ),
    );
  }
}
