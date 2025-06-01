// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/auth_provider.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/notes_page.dart'; // Olettaen, että nämä ovat olemassa
import 'pages/profile_page.dart'; // Olettaen, että nämä ovat olemassa
import 'pages/edit_profile_page.dart'; // Olettaen, että nämä ovat olemassa
import 'pages/register_page.dart';
import 'widgets/main_scaffold.dart'; // Olettaen, että tämä on olemassa
import 'models/user_profile_model.dart'; // Olettaen, että tämä on olemassa

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
// final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell'); // <--- POISTETTU: Tätä ei käytetty

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    // Kuuntele AuthProviderin muutoksia uudelleenohjauksia varten
    final authProvider = Provider.of<AuthProvider>(context, listen: true);

    final router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/home', // Aloitussivu, jos käyttäjä on kirjautunut
      debugLogDiagnostics: true,
      // `refreshListenable` kuuntelee AuthProviderin muutoksia ja käynnistää uudelleenohjauksen
      refreshListenable: authProvider,
      routes: [
        // Julkiset reitit (ei vaadi kirjautumista)
        GoRoute(
          path: '/login',
          parentNavigatorKey: _rootNavigatorKey, // Näytetään koko näytöllä
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          parentNavigatorKey: _rootNavigatorKey, // Näytetään koko näytöllä
          builder: (context, state) => const RegisterPage(),
        ),

        // Suojatut reitit (vaatii kirjautumisen)
        StatefulShellRoute.indexedStack(
          // navigatorKey: _shellNavigatorKey, // Valinnainen, jos haluat erillisen navigaatiopinon shellille. POISTETTU kommentista, koska ei käytetty.
          builder: (BuildContext context, GoRouterState state,
              StatefulNavigationShell navigationShell) {
            return MainScaffoldWithBottomNav(navigationShell: navigationShell);
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/home',
                  builder: (BuildContext context, GoRouterState state) =>
                      const HomePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/notes',
                  builder: (BuildContext context, GoRouterState state) =>
                      const NotesPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                    path: '/profile',
                    builder: (BuildContext context, GoRouterState state) =>
                        const ProfilePage(),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (BuildContext context, GoRouterState state) {
                          // Olettaen, että UserProfileModel on ja sitä käytetään GoRouterin extrana
                          final userProfile = state.extra as UserProfile?;
                          if (userProfile == null) {
                            // Käsittele tapaus, jos profiilidata puuttuu
                            return Scaffold(
                              appBar: AppBar(title: const Text('Virhe')),
                              body: const Center(
                                child: Text(
                                    "Profiilidataa ei löytynyt muokkausta varten."),
                              ),
                            );
                          }
                          return EditProfilePage(initialProfile: userProfile);
                        },
                      ),
                    ]),
              ],
            ),
          ],
        ),
      ],

      // Uudelleenohjauslogiikka
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final currentPath = state.uri.toString();
        final isPublicPage =
            currentPath == '/login' || currentPath == '/register';

        // Jos käyttäjä ei ole kirjautunut ja yrittää mennä suojatulle sivulle, ohjaa kirjautumissivulle.
        if (!isLoggedIn && !isPublicPage) {
          return '/login';
        }
        // Jos käyttäjä on kirjautunut ja yrittää mennä julkiselle sivulle (login/register), ohjaa kotisivulle.
        if (isLoggedIn && isPublicPage) {
          return '/home';
        }
        // Muissa tapauksissa ei uudelleenohjausta.
        return null;
      },
    );

    // Teeman määrittely - päivitetty modernimpaan ja syvempään ilmeeseen
    final themeData = ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.teal,
      scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Syvempi tumma tausta
      cardColor: const Color(0xFF2C2C2C), // Sopii tummaan teemaan
      colorScheme: ColorScheme.dark(
        primary: Colors.teal.shade400, // Kirkkaampi turkoosi
        secondary: Colors.orange.shade300, // Pehmeämpi oranssi korostus
        surface: const Color(0xFF2C2C2C),
        error: Colors.redAccent,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Colors.white.withOpacity(0.9),
        onError: Colors.black,
        outline: Colors.grey.shade700, // Kenttien reunaviivat
      ),
      // Tekstiteemat
      textTheme: TextTheme(
        headlineLarge: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 48,
            letterSpacing: -1.0),
        headlineMedium: const TextStyle(
            fontWeight: FontWeight.w700, color: Colors.white, fontSize: 32),
        headlineSmall: const TextStyle(
            fontWeight: FontWeight.w600, color: Colors.white, fontSize: 24),
        titleLarge: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.9),
            fontSize: 20),
        titleMedium: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.8),
            fontSize: 16),
        bodyLarge:
            TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16),
        bodyMedium:
            TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
        labelLarge: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
      ),
      // Syötekenttien teema
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.08), // Hienovarainen täyttö
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        prefixIconColor: Colors.teal.shade200,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 16), // Isompi padding
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0), // Pyöreämmät kulmat
          borderSide: BorderSide.none, // Ei oletusreunoja
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
              color: Colors.white.withOpacity(0.15),
              width: 1), // Hienovaraiset reunat
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(
              color: Colors.tealAccent, width: 2), // Korostettu aktiivisena
        ),
        errorStyle: TextStyle(color: Colors.redAccent.shade100, fontSize: 12),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      // Painikkeiden teemat
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 54), // Korkeammat painikkeet
          backgroundColor: Colors.teal.shade600, // Syvempi turkoosi
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), // Pyöreämmät kulmat
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.orange.shade300,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white.withOpacity(0.9),
          side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
        ),
      ),
      // Alapalkin teema
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF2C2C2C), // Sama kuin cardColor
        selectedItemColor: Colors.orange.shade300,
        unselectedItemColor: Colors.white.withOpacity(0.6),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 8.0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, // Läpinäkyvä app bar
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return MaterialApp.router(
      title: 'Vaella',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fi', 'FI'),
        Locale('en', ''),
      ],
      routerConfig: router,
    );
  }
}
