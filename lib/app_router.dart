// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/auth_provider.dart';
import 'models/post_model.dart'; // Lisätty PostVisibility-enumia varten
import 'models/user_profile_model.dart'; // UserProfile-mallia varten EditProfilePagessa

// Sivut
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/notes_page.dart'; // Oletetaan, että sinulla on NotesPage
import 'pages/profile_page.dart';
import 'pages/edit_profile_page.dart';
import 'pages/register_page.dart';
import 'pages/create_post_page.dart'; // Lisätty CreatePostPage
import 'pages/user_posts_list_page.dart'; // UUSI: Käyttäjän julkaisulistaussivu

// Widgetit
import 'widgets/main_scaffold.dart'; // Oletetaan, että MainScaffoldWithBottomNav on tässä

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
// GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell'); // Voit lisätä shellNavigatorKeyn tarvittaessa

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: true);

    final router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/home', // Tai '/login' jos halutaan aloittaa sieltä
      debugLogDiagnostics: true, // Hyödyllinen debuggaukseen
      refreshListenable: authProvider,
      routes: [
        GoRoute(
          path: '/login',
          name: 'login', // Nimeä reitit selkeyden vuoksi
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/create-post',
          name: 'createPost',
          parentNavigatorKey:
              _rootNavigatorKey, // Avautuu koko näytölle ilman shelliä
          builder: (context, state) {
            // Oletetaan, että initialVisibility välitetään extrana
            final initialVisibility = state.extra as PostVisibility?;
            return CreatePostPage(
                initialVisibility: initialVisibility ??
                    PostVisibility.public); // Oletusarvo, jos extra on null
          },
        ),
        // UUSI REITTI: Käyttäjän julkaisulistaussivu
        GoRoute(
          path: '/users/:userId/posts', // Polku sisältää käyttäjän ID:n
          name: 'userPostsList',
          parentNavigatorKey: _rootNavigatorKey, // Avautuu koko näytölle
          builder: (context, state) {
            final userId = state.pathParameters['userId'];
            final username =
                state.extra as String?; // Välitetään username extrana

            if (userId == null) {
              // Virhetilanne, jos userId puuttuu polusta
              return Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: const Center(child: Text('User ID is missing.')),
              );
            }
            return UserPostsListPage(userId: userId, username: username);
          },
        ),
        // StatefulShellRoute päänavigaatiota varten (alapalkki)
        StatefulShellRoute.indexedStack(
          builder: (BuildContext context, GoRouterState state,
              StatefulNavigationShell navigationShell) {
            // MainScaffoldWithBottomNav hoitaa alapalkin ja sisällön vaihdon
            return MainScaffoldWithBottomNav(navigationShell: navigationShell);
          },
          branches: <StatefulShellBranch>[
            // Home-välilehti
            StatefulShellBranch(
              // navigatorKey: _shellNavigatorKey, // Voit käyttää erillistä avainta shellin navigaatiolle
              routes: <RouteBase>[
                GoRoute(
                  path: '/home',
                  name: 'home',
                  builder: (BuildContext context, GoRouterState state) =>
                      const HomePage(),
                  // Tähän voi lisätä alireittejä, jotka avautuvat Home-shellin sisällä
                  // Esim. /home/details/:id
                ),
              ],
            ),
            // Notes-välilehti (tai mikä tahansa toinen välilehti)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/notes', // Muuta polku sopivaksi
                  name: 'notes',
                  builder: (BuildContext context, GoRouterState state) =>
                      const NotesPage(), // Varmista, että NotesPage on olemassa
                ),
              ],
            ),
            // Profile-välilehti
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                    path: '/profile',
                    name: 'profile',
                    builder: (BuildContext context, GoRouterState state) =>
                        const ProfilePage(),
                    routes: [
                      GoRoute(
                        path: 'edit', // Alireitti: /profile/edit
                        name: 'editProfile',
                        // Jos haluat tämän avautuvan koko näytölle shellin ulkopuolelle:
                        // parentNavigatorKey: _rootNavigatorKey,
                        builder: (BuildContext context, GoRouterState state) {
                          final userProfile = state.extra as UserProfile?;
                          if (userProfile == null) {
                            // Näytä virhesivu tai ohjaa takaisin, jos profiilidata puuttuu
                            return Scaffold(
                              appBar: AppBar(title: const Text('Error')),
                              body: const Center(
                                child:
                                    Text("Profile data not found for editing."),
                              ),
                            );
                          }
                          return EditProfilePage(initialProfile: userProfile);
                        },
                      ),
                      // Huom: '/profile/:userId/posts' reitti on nyt ylätason reitti,
                      // koska se voi näyttää kenen tahansa käyttäjän postaukset.
                      // Jos haluaisit reitin VAIN nykyisen käyttäjän postauksille alapalkin sisällä,
                      // se voisi olla '/profile/myposts' ilman :userId parametria.
                    ]),
              ],
            ),
          ],
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = authProvider.isLoggedIn;
        // state.matchedLocation antaa reitin ilman query parametreja
        final String location = state.matchedLocation;

        final isLoggingIn = location == '/login';
        final isRegistering = location == '/register';

        // Jos käyttäjä ei ole kirjautunut EIKÄ ole kirjautumis- tai rekisteröitymissivulla -> ohjaa login-sivulle
        if (!isLoggedIn && !isLoggingIn && !isRegistering) {
          return '/login';
        }
        // Jos käyttäjä ON kirjautunut JA on kirjautumis- tai rekisteröitymissivulla -> ohjaa home-sivulle
        if (isLoggedIn && (isLoggingIn || isRegistering)) {
          return '/home';
        }
        // Ei uudelleenohjausta muissa tapauksissa
        return null;
      },
    );

    // ThemeData pysyy samana kuin annoit, lisäsin vain kommentteja
    final themeData = ThemeData(
        brightness: Brightness.dark,
        // primaryColor: Colors.teal, // Vanhempi tapa, käytä colorScheme.primary
        scaffoldBackgroundColor:
            const Color(0xFF1A1A1A), // Sovelluksen päätausta
        cardColor: const Color(0xFF2C2C2C), // Korttien taustaväri
        colorScheme: ColorScheme.dark(
          primary: Colors.teal.shade400, // Pääväri (esim. sinivihreä)
          onPrimary: Colors.black, // Teksti/ikonit päävärin päällä
          secondary:
              Colors.orange.shade400, // Toissijainen väri (esim. oranssi)
          onSecondary: Colors.black, // Teksti/ikonit toissijaisen värin päällä
          surface: const Color(
              0xFF222222), // Pintojen väri (hieman eri kuin scaffoldBg)
          onSurface: Colors.white.withOpacity(0.9), // Teksti pintojen päällä
          surfaceContainerLowest:
              const Color(0xFF1F1F1F), // Lisätty uusi väri shimmerille
          surfaceContainerHighest: const Color(0xFF3A3A3A), // Lisätty uusi väri
          error: Colors.redAccent.shade200, // Virheväri
          onError: Colors.black, // Teksti virhevärin päällä
          outline: Colors.grey.shade700, // Reunaviivojen väri
        ),
        textTheme: TextTheme(
          // Voit käyttää GoogleFonts suoraan widgeteissä tai määritellä ne teemassa
          headlineLarge: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 30,
              letterSpacing: -0.5),
          headlineMedium: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, color: Colors.white, fontSize: 26),
          headlineSmall: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: Colors.white, fontSize: 22),
          titleLarge: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
              fontSize: 20),
          titleMedium: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.85),
              fontSize: 17),
          titleSmall: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8),
              fontSize: 15),
          bodyLarge: GoogleFonts.lato(
              color: Colors.white.withOpacity(0.85), fontSize: 16, height: 1.5),
          bodyMedium: GoogleFonts.lato(
              color: Colors.white.withOpacity(0.75), fontSize: 14, height: 1.4),
          bodySmall: GoogleFonts.lato(
              color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.3),
          labelLarge: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          hintStyle: GoogleFonts.lato(color: Colors.white.withOpacity(0.4)),
          prefixIconColor: Colors.teal.shade200.withOpacity(0.7),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Colors.teal.shade300, width: 2)),
          errorStyle:
              GoogleFonts.lato(color: Colors.redAccent.shade100, fontSize: 12),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide:
                  BorderSide(color: Colors.redAccent.shade100, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide:
                  BorderSide(color: Colors.redAccent.shade200, width: 2)),
          labelStyle: GoogleFonts.lato(color: Colors.white.withOpacity(0.6)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: Colors.teal.shade500,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            textStyle: GoogleFonts.poppins(
                fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.3),
            elevation: 2,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.orange.shade300,
            textStyle:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white.withOpacity(0.9),
            side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            padding:
                const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
            textStyle:
                GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color(0xFF222222),
          selectedItemColor: Colors.orange.shade300,
          unselectedItemColor: Colors.white.withOpacity(0.5),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
          elevation: 10.0,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        datePickerTheme: DatePickerThemeData(
          // Esimerkki DatePicker-teemasta
          backgroundColor: const Color(0xFF2C2C2C),
          headerBackgroundColor: Colors.teal.shade700,
          headerForegroundColor: Colors.white,
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            if (states.contains(WidgetState.disabled))
              return Colors.grey.shade700;
            return Colors.white.withOpacity(0.8);
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected))
              return Colors.teal.shade500;
            return Colors.transparent;
          }),
          todayForegroundColor: WidgetStateProperty.all(Colors.orange.shade300),
          todayBorder:
              BorderSide(color: Colors.orange.shade300.withOpacity(0.5)),
          yearForegroundColor:
              WidgetStateProperty.all(Colors.white.withOpacity(0.8)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected))
              return Colors.teal.shade400;
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(Colors.black),
          overlayColor: WidgetStateProperty.all(Colors.teal.withOpacity(0.1)),
          side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF2C2C2C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titleTextStyle: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.bold),
          contentTextStyle: GoogleFonts.lato(
              color: Colors.white.withOpacity(0.8), fontSize: 16),
        ));

    return MaterialApp.router(
      title: 'Vaella', // Sovelluksen nimi
      debugShowCheckedModeBanner: false,
      theme: themeData, // Käytä määriteltyä teemaa
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fi', 'FI'), // Suomi
        Locale('en', ''), // Englanti (oletus)
      ],
      locale: const Locale('fi', 'FI'), // Aseta oletuskieli sovellukselle
      routerConfig: router,
    );
  }
}
