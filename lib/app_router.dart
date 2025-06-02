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
import 'pages/edit_profile_page.dart';
import 'pages/register_page.dart';
import 'widgets/main_scaffold.dart';
import 'models/user_profile_model.dart';
// CreatePostPage ei tarvitse olla tässä, jos sitä kutsutaan MaterialPageRoute:lla
// import 'pages/create_post_page.dart';

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
        GoRoute(
          path: '/register',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const RegisterPage(),
        ),
        // CreatePostPage voidaan lisätä tänne, jos halutaan GoRouter-navigaatio sille
        // Esim.
        // GoRoute(
        //   path: '/create-post',
        //   parentNavigatorKey: _rootNavigatorKey, // Avautuu koko näytölle ilman shelliä
        //   builder: (context, state) {
        //     final visibility = state.extra as PostVisibility?; // Välitä extra-parametrina
        //     if (visibility == null) return const HomePage(); // Tai jokin virhesivu
        //     return CreatePostPage(initialVisibility: visibility);
        //   },
        // ),
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
                        // parentNavigatorKey: _rootNavigatorKey, // Voi avata muokkaussivun koko näytöllä
                        builder: (BuildContext context, GoRouterState state) {
                          final userProfile = state.extra as UserProfile?;
                          if (userProfile == null) {
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
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final currentPath = state.uri.toString();
        // Poistetaan query parametrit vertailusta, jos niitä on
        final pathOnly = Uri.parse(currentPath).path;

        final isPublicPage = pathOnly == '/login' || pathOnly == '/register';

        if (!isLoggedIn && !isPublicPage) {
          return '/login';
        }
        if (isLoggedIn && isPublicPage) {
          return '/home';
        }
        return null;
      },
    );

    final themeData = ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.teal, // Tämä on enemmänkin "legacy"
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF2C2C2C),
        colorScheme: ColorScheme.dark(
          primary: Colors.teal.shade400,
          secondary: Colors.orange.shade400, // Kirkastettu hieman
          surface: const Color(
              0xFF2C2C2C), // Käytetään korttien ja dialogien taustana
          background: const Color(0xFF1A1A1A), // Sovelluksen päätausta
          error: Colors.redAccent.shade200,
          onPrimary: Colors.black, // Teksti/ikonit primary-värin päällä
          onSecondary: Colors.black, // Teksti/ikonit secondary-värin päällä
          onSurface: Colors.white
              .withOpacity(0.9), // Teksti/ikonit surface-värin päällä
          onBackground: Colors.white
              .withOpacity(0.9), // Teksti/ikonit background-värin päällä
          onError: Colors.white,
          outline: Colors.grey.shade700,
        ),
        textTheme: TextTheme(
          // Käytä GoogleFonts myöhemmin jos haluat personoidumpia fontteja
          headlineLarge: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 30,
              letterSpacing: -0.5),
          headlineMedium: const TextStyle(
              fontWeight: FontWeight.w700, color: Colors.white, fontSize: 26),
          headlineSmall: const TextStyle(
              fontWeight: FontWeight.w600, color: Colors.white, fontSize: 22),
          titleLarge: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
              fontSize: 20), // Hieman pehmeämpi
          titleMedium: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.85),
              fontSize: 17),
          titleSmall: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8),
              fontSize: 15),
          bodyLarge: TextStyle(
              color: Colors.white.withOpacity(0.85), fontSize: 16, height: 1.5),
          bodyMedium: TextStyle(
              color: Colors.white.withOpacity(0.75), fontSize: 14, height: 1.4),
          labelLarge: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5),
          bodySmall: TextStyle(
              color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.3),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05), // Hienovarainen täyttö
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          prefixIconColor: Colors.teal.shade200.withOpacity(0.7),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 18), // Hieman korkeampi
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide:
                BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.teal.shade300, width: 2),
          ),
          errorStyle: TextStyle(color: Colors.redAccent.shade100, fontSize: 12),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide:
                BorderSide(color: Colors.redAccent.shade100, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.redAccent.shade200, width: 2),
          ),
          labelStyle:
              TextStyle(color: Colors.white.withOpacity(0.6)), // Labelin väri
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity,
                52), // Hieman matalampi, mutta edelleen hyvä koko
            backgroundColor:
                Colors.teal.shade500, // Hieman tummempi ja kylläisempi
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            textStyle: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.3),
            elevation: 2, // Pieni korostus
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.orange.shade300,
            textStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color(0xFF222222), // Hieman erottuva pohjasta
          selectedItemColor: Colors.orange.shade300,
          unselectedItemColor: Colors.white.withOpacity(0.5),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          elevation: 10.0, // Selkeämpi erotus
        ),
        appBarTheme: AppBarTheme(
          backgroundColor:
              const Color(0xFF1A1A1A), // AppBarin tausta sama kuin sivun
          elevation: 0, // Modernimpi ilme ilman varjoa
          foregroundColor: Colors.white, // Ikonien ja tekstin väri AppBarissa
          centerTitle: true,
          titleTextStyle: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        // UUSI: DatePickerTeema
        datePickerTheme: DatePickerThemeData(
          backgroundColor: const Color(0xFF2C2C2C), // Dialogin tausta
          headerBackgroundColor: Colors.teal.shade700,
          headerForegroundColor: Colors.white,
          dayForegroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected))
              return Colors.white; // Valittu päivä teksti
            if (states.contains(MaterialState.disabled))
              return Colors.grey.shade700;
            return Colors.white.withOpacity(0.8); // Normaalit päivät
          }),
          dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected))
              return Colors.teal.shade500; // Valittu päivä tausta
            return Colors.transparent;
          }),
          todayForegroundColor:
              MaterialStateProperty.all(Colors.orange.shade300),
          todayBorder:
              BorderSide(color: Colors.orange.shade300.withOpacity(0.5)),
          yearForegroundColor:
              MaterialStateProperty.all(Colors.white.withOpacity(0.8)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.teal.shade400; // valitun checkboxin väri
            }
            return Colors
                .transparent; // valitsemattoman checkboxin täyttöväri (tai reunaväri jos checkColor ei asetettu)
          }),
          checkColor: MaterialStateProperty.all(Colors.black), // ruksin väri
          overlayColor: MaterialStateProperty.all(Colors.teal.withOpacity(0.1)),
          side: BorderSide(
              color: Colors.white.withOpacity(0.4),
              width: 1.5), // checkboxin reunaviiva
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF2C2C2C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titleTextStyle: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.bold),
          contentTextStyle:
              TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
        ));

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
        Locale('fi', 'FI'), // Oletus Suomi
        Locale('en', ''),
      ],
      locale: const Locale('fi', 'FI'), // Asetetaan oletuskieleksi Suomi
      routerConfig: router,
    );
  }
}
