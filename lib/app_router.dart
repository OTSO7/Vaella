// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/auth_provider.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/notes_page.dart';
import 'pages/profile_page.dart';
import 'pages/edit_profile_page.dart'; // Varmista, että tämä import on olemassa, jos käytät sivua
import 'widgets/main_scaffold.dart';
import 'models/user_profile_model.dart'; // Varmista, että tämä import on olemassa

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: true);

    final router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/home',
      debugLogDiagnostics: true,
      refreshListenable: authProvider,
      routes: [
        GoRoute(
          path: '/login',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const LoginPage(),
        ),
        StatefulShellRoute.indexedStack(
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
                        // parentNavigatorKey: _rootNavigatorKey, // Voit poistaa kommentin, jos haluat tämän koko näytölle
                        builder: (BuildContext context, GoRouterState state) {
                          final userProfile = state.extra as UserProfile?;
                          if (userProfile == null) {
                            print("EditProfilePage: UserProfile data puuttuu!");
                            // Palauta placeholder tai ohjaa takaisin, jos profiilidataa ei ole.
                            // Tässä esimerkissä palautetaan yksinkertainen virhesivu.
                            return const Scaffold(
                                body: Center(
                                    child: Text(
                                        "Profiilidataa ei löytynyt muokkausta varten.")));
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
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final currentPath = state.uri.toString();
        if (!isLoggedIn && currentPath != '/login') return '/login';
        if (isLoggedIn && currentPath == '/login') return '/home';
        if (isLoggedIn && currentPath == '/') return '/home';
        return null;
      },
    );

    // --- TÄMÄ ON TÄRKEÄ TEEMA-ASETUS ---
    final themeData = ThemeData(
        brightness: Brightness.dark, // <--- TÄMÄ ASETTAA TUMMAN TEEMAN
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[900],
        cardColor:
            Colors.grey[850], // Käytetään korteille ja modaalin taustalle
        colorScheme: ColorScheme.dark(
          // Varmistetaan, että ColorScheme on myös tumma
          primary: Colors.teal,
          secondary: Colors.orangeAccent,
          surface: Colors.grey[850]!, // Pintojen väri (esim. AppBar, Card)
          background: Colors.grey[900]!, // Yleinen taustaväri
          error: Colors.redAccent,
          onPrimary: Colors.white, // Teksti/ikonit päävärin päällä
          onSecondary: Colors.black, // Teksti/ikonit toissijaisen värin päällä
          onSurface: Colors.white, // Teksti/ikonit pintojen päällä
          onBackground: Colors.white, // Teksti/ikonit taustan päällä
          onError: Colors.black, // Teksti/ikonit virhevärin päällä
          outline: Colors.grey[600], // Reunaviivojen väri
        ),
        textTheme: TextTheme(
          headlineSmall: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9)),
          titleLarge: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9)),
          titleMedium:
              TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
          bodyMedium: TextStyle(color: Colors.white.withOpacity(0.7)),
          labelLarge: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.black.withOpacity(0.3),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIconColor: Colors.teal[200],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey[600]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
          ),
          errorStyle: TextStyle(color: Colors.redAccent[100]),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.orangeAccent,
            textStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white.withOpacity(0.9),
          side: BorderSide(color: Colors.grey[600]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
        )),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.grey[870],
          selectedItemColor: Colors.orangeAccent,
          unselectedItemColor: Colors.white.withOpacity(0.7),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
        ));
    // --- TEEMA-ASETUS PÄÄTTYY ---

    return MaterialApp.router(
      title: 'TrekNote VaellusApp',
      debugShowCheckedModeBanner: false,
      theme: themeData, // <--- TÄMÄ KÄYTTÄÄ YLLÄ MÄÄRITELTYÄ TUMMAA TEEMAA

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
