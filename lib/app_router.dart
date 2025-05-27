// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/notes_page.dart'; // UUSI IMPORT
import 'pages/profile_page.dart'; // UUSI IMPORT
import 'widgets/main_scaffold.dart'; // UUSI IMPORT

// Globaalit NavigatorKeyt
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
// Shell-reitille ei välttämättä tarvita omaa avainta, jos käytetään StatefulShellRoute.indexedStackin oletuksia
// final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    // Kuunnellaan AuthProvideria, jotta GoRouter reagoi sen muutoksiin (refreshListenable)
    final authProvider = Provider.of<AuthProvider>(context, listen: true);

    final router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation:
          '/home', // Yritetään ensin kotisivulle, redirect hoitaa jos ei kirjautunut
      debugLogDiagnostics: true, // Hyödyllinen debuggauksessa
      refreshListenable:
          authProvider, // Tärkeä autentikoinnin tilan muutoksille
      routes: [
        // Kirjautumissivu (ei osa ShellRoutea)
        GoRoute(
          path: '/login',
          parentNavigatorKey:
              _rootNavigatorKey, // Varmistaa, että tämä on päällimmäisenä
          builder: (context, state) => const LoginPage(),
        ),

        // ShellRoute pääsovelluksen sivuille, joissa on BottomNavigationBar
        StatefulShellRoute.indexedStack(
          builder: (BuildContext context, GoRouterState state,
              StatefulNavigationShell navigationShell) {
            // Tämä on widget, joka sisältää Scaffolding ja BottomNavigationBarin
            return MainScaffoldWithBottomNav(navigationShell: navigationShell);
          },
          branches: <StatefulShellBranch>[
            // Haara 1: Koti (Home)
            StatefulShellBranch(
              // Ei tarvita omaa navigatorKeytä tässä, jos ei ole sisäkkäistä navigointia haarassa
              routes: <RouteBase>[
                GoRoute(
                  path: '/home',
                  builder: (BuildContext context, GoRouterState state) =>
                      const HomePage(),
                  // Tänne voisi lisätä alireittejä, esim. /home/post/:id
                ),
              ],
            ),

            // Haara 2: Muistilista (Notes)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/notes',
                  builder: (BuildContext context, GoRouterState state) =>
                      const NotesPage(),
                ),
              ],
            ),

            // Haara 3: Profiili (Profile)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/profile',
                  builder: (BuildContext context, GoRouterState state) =>
                      const ProfilePage(),
                ),
              ],
            ),
          ],
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final currentPath = state.uri.toString();

        // Jos käyttäjä ei ole kirjautunut sisään EIKÄ ole menossa kirjautumissivulle, ohjaa kirjautumissivulle.
        if (!isLoggedIn && currentPath != '/login') {
          return '/login';
        }

        // Jos käyttäjä ON kirjautunut sisään JA on kirjautumissivulla, ohjaa kotisivulle.
        if (isLoggedIn && currentPath == '/login') {
          return '/home';
        }

        // Jos käyttäjä on kirjautunut ja sovellus avataan juureen ("/"), ohjaa kotisivulle.
        // Tämä on tärkeää, koska ShellRoute itsessään ei ole "sivu".
        if (isLoggedIn && currentPath == '/') {
          return '/home';
        }

        // Muissa tapauksissa ei uudelleenohjausta.
        return null;
      },
    );

    // Haetaan teema samalla tavalla kuin aiemmin
    final themeData = ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[900],
        colorScheme: ColorScheme.dark(
          primary: Colors.teal,
          secondary: Colors.orangeAccent,
          surface: Colors.grey[850]!,
          background: Colors.grey[900]!,
          error: Colors.redAccent,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onBackground: Colors.white,
          onError: Colors.black,
        ),
        textTheme: TextTheme(
          headlineSmall: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9)),
          titleLarge: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9)),
          titleMedium:
              TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
          bodyMedium: TextStyle(color: Colors.white.withOpacity(0.7)),
          labelLarge: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.black.withOpacity(0.25),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIconColor: Colors.white.withOpacity(0.7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide:
                BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
          ),
          errorStyle: TextStyle(color: Colors.redAccent[100]),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.orangeAccent,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        // BottomNavigationBarin teema voidaan myös määritellä tässä
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor:
              Colors.grey[850], // Esimerkki, vastaa colorScheme.surface
          selectedItemColor:
              Colors.orangeAccent, // Esimerkki, vastaa colorScheme.secondary
          unselectedItemColor: Colors.white.withOpacity(0.6),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        ));

    return MaterialApp.router(
      title: 'TrekNote VaellusApp',
      debugShowCheckedModeBanner: false,
      theme: themeData, // Käytetään määriteltyä teemaa
      routerConfig: router,
    );
  }
}
