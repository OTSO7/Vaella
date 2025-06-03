import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/auth_provider.dart';
import 'models/post_model.dart'; // For PostVisibility enum
import 'models/user_profile_model.dart'; // For UserProfile in EditProfilePage

// Pages
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/notes_page.dart';
import 'pages/profile_page.dart';
import 'pages/edit_profile_page.dart';
import 'pages/register_page.dart';
import 'pages/create_post_page.dart';
import 'pages/user_posts_list_page.dart';
import 'pages/weather_page.dart'; // UUSI: Importtaa WeatherPage
import 'models/hike_plan_model.dart'; // UUSI: Tarvitaan HikePlanin välittämiseen

// Widgets
import 'widgets/main_scaffold.dart';

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
          name: 'login',
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
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final initialVisibility = state.extra as PostVisibility?;
            return CreatePostPage(
                initialVisibility: initialVisibility ?? PostVisibility.public);
          },
        ),
        GoRoute(
          path: '/users/:userId/posts',
          name: 'userPostsList',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final userId = state.pathParameters['userId'];
            final username = state.extra as String?;
            if (userId == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: const Center(child: Text('User ID is missing.')),
              );
            }
            return UserPostsListPage(userId: userId, username: username);
          },
        ),
        GoRoute(
          path: '/hike-plan/:planId/weather', // UUSI REITTI
          name: 'weatherPage',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final hikePlan = state.extra as HikePlan?;
            if (hikePlan == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: const Center(child: Text('Hike Plan data is missing.')),
              );
            }
            return WeatherPage(hikePlan: hikePlan);
          },
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
                  name: 'home',
                  builder: (BuildContext context, GoRouterState state) =>
                      const HomePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/notes',
                  name: 'notes',
                  builder: (BuildContext context, GoRouterState state) =>
                      const NotesPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                    path: '/profile',
                    name: 'profile',
                    builder: (BuildContext context, GoRouterState state) =>
                        const ProfilePage(),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: 'editProfile',
                        builder: (BuildContext context, GoRouterState state) {
                          final userProfile = state.extra as UserProfile?;
                          if (userProfile == null) {
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
                    ]),
              ],
            ),
          ],
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final String location = state.matchedLocation;

        final isLoggingIn = location == '/login';
        final isRegistering = location == '/register';
        final isWeatherPage =
            location.startsWith('/hike-plan/') && location.endsWith('/weather');

        if (!isLoggedIn && !isLoggingIn && !isRegistering) {
          return '/login';
        }
        if (isLoggedIn && (isLoggingIn || isRegistering)) {
          return '/home';
        }
        if (!isLoggedIn && isWeatherPage) {
          return '/login';
        }
        return null;
      },
    );

    final themeData = ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF2C2C2C),
        colorScheme: ColorScheme.dark(
          primary: Colors.teal.shade400,
          onPrimary: Colors.black,
          secondary: Colors.orange.shade400,
          onSecondary: Colors.black,
          surface: const Color(0xFF222222),
          onSurface: Colors.white.withOpacity(0.9),
          surfaceContainerLowest: const Color(0xFF1F1F1F),
          surfaceContainerHighest: const Color(0xFF3A3A3A),
          error: Colors.redAccent.shade200,
          onError: Colors.black,
          outline: Colors.grey.shade700,
          // Accent colors
          tertiary: Colors.deepPurpleAccent.shade200, // Accent color 1
          onTertiary: Colors.black,
          secondaryContainer: Colors.amberAccent.shade200, // Accent color 2
          onSecondaryContainer: Colors.black,
        ),
        textTheme: TextTheme(
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
      locale: const Locale('fi', 'FI'),
      routerConfig: router,
    );
  }
}
