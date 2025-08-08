import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/auth_provider.dart';
import 'models/post_model.dart';
import 'models/user_profile_model.dart';
import 'models/hike_plan_model.dart';

// Varmista, että kaikki sivut on importattu oikein
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/notes_page.dart';
import 'pages/profile_page.dart';
import 'pages/edit_profile_page.dart';
import 'pages/register_page.dart';
import 'pages/create_post_page.dart';
import 'pages/user_posts_list_page.dart';
import 'pages/weather_page.dart';
import 'pages/hike_plan_hub_page.dart';
import 'pages/packing_list_page.dart';
import 'pages/route_planner_page.dart';
import 'pages/post_detail_page.dart';
import 'pages/profile_full_screen_map_page.dart';

import 'widgets/main_scaffold.dart';
import 'widgets/user_hikes_map_section.dart';

// Päänavigaattorin avain, jota käytetään näyttämään sivuja pohjanavigaation päällä.
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
      // Kuuntelee AuthProviderin muutoksia ja suorittaa uudelleenohjauksen tarvittaessa.
      refreshListenable: authProvider,
      routes: [
        // --- Alaosan navigaatiopalkin ulkopuoliset reitit ---
        // Nämä reitit käyttävät _rootNavigatorKey-avainta, jotta ne avautuvat
        // koko näytön kokoisina päänavigaation päälle.

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
            PostVisibility visibility = PostVisibility.public;
            HikePlan? hikePlan;

            if (state.extra is Map<String, dynamic>) {
              final extraData = state.extra as Map<String, dynamic>;
              visibility = extraData['visibility'] as PostVisibility? ??
                  PostVisibility.public;
              hikePlan = extraData['plan'] as HikePlan?;
            } else if (state.extra is PostVisibility) {
              visibility = state.extra as PostVisibility;
            }

            return CreatePostPage(
              initialVisibility: visibility,
              hikePlan: hikePlan,
            );
          },
        ),
        GoRoute(
          path: '/route-planner',
          name: 'routePlannerPage',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const RoutePlannerPage(),
        ),
        GoRoute(
          path: '/users/:userId/posts',
          name: 'userPostsList',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final userId = state.pathParameters['userId'];
            final username = state.extra as String?;
            if (userId == null) {
              return const Scaffold(
                  body: Center(child: Text('User ID missing.')));
            }
            return UserPostsListPage(userId: userId, username: username);
          },
        ),
        GoRoute(
          path: '/hike-plan-hub',
          name: 'hikePlanHub',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final plan = state.extra as HikePlan?;
            if (plan == null) {
              return const Scaffold(
                  body: Center(child: Text('Hike plan not found!')));
            }
            return HikePlanHubPage(initialPlan: plan);
          },
        ),
        GoRoute(
          path: '/hike-plan/:planId/weather',
          name: 'weatherPage',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final hikePlan = state.extra as HikePlan?;
            if (hikePlan == null) {
              return const Scaffold(
                  body: Center(child: Text('Hike Plan data missing.')));
            }
            return WeatherPage(hikePlan: hikePlan);
          },
        ),
        GoRoute(
          path: '/hike-plan/:planId/packingList',
          name: 'packingListPage',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final planId = state.pathParameters['planId']!;
            final hikePlan = state.extra as HikePlan?;
            if (hikePlan == null) {
              return const Scaffold(
                  body: Center(child: Text('Hike Plan data missing.')));
            }
            return PackingListPage(planId: planId, initialPlan: hikePlan);
          },
        ),
        GoRoute(
          path: '/post/:id',
          name: 'postDetail',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final postId = state.pathParameters['id'];
            if (postId == null) {
              return const Scaffold(
                  body: Center(child: Text('Post ID missing.')));
            }
            return PostDetailPage(postId: postId);
          },
        ),
        GoRoute(
          path: '/profile/map',
          name: 'profileMapFullScreen',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            if (extra == null ||
                extra['userId'] == null ||
                extra['items'] == null) {
              return const Scaffold(
                  body: Center(child: Text("Map data missing.")));
            }
            final userId = extra['userId'] as String;
            final items = extra['items'] as List<MapDisplayItem>;
            return ProfileFullScreenMapPage(
                userId: userId, initialItems: items);
          },
        ),

        // --- Alaosan navigaatiopalkin sisältävät reitit (Shell Route) ---
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainScaffoldWithBottomNav(navigationShell: navigationShell);
          },
          branches: <StatefulShellBranch>[
            // Branch for the Home tab
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomePage(),
              ),
            ]),
            // Branch for the Notes tab
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                path: '/notes',
                name: 'notes',
                builder: (context, state) => const NotesPage(),
              ),
            ]),
            // Branch for the Profile tab
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfilePage(),
                routes: [
                  // Profiilin alireitti, joka avautuu koko näytölle
                  GoRoute(
                    path: 'edit',
                    name: 'editProfile',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final userProfile = state.extra as UserProfile?;
                      if (userProfile == null) {
                        return const Scaffold(
                            body: Center(child: Text("Profile data missing.")));
                      }
                      return EditProfilePage(initialProfile: userProfile);
                    },
                  ),
                ],
              ),
            ]),
          ],
        ),
      ],
      // Uudelleenohjauslogiikka
      redirect: (context, state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final location = state.matchedLocation;
        final isAuthRoute = location == '/login' || location == '/register';

        if (!isLoggedIn && !isAuthRoute) return '/login';
        if (isLoggedIn && isAuthRoute) return '/home';
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
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.w800, color: Colors.white, fontSize: 30),
        titleLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.9),
            fontSize: 20),
        bodyLarge: GoogleFonts.lato(
            color: Colors.white.withOpacity(0.85), fontSize: 16, height: 1.5),
        labelLarge: GoogleFonts.poppins(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: Colors.teal.shade500,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          textStyle:
              GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF222222),
        selectedItemColor: Colors.orange.shade300,
        unselectedItemColor: Colors.white.withOpacity(0.5),
        type: BottomNavigationBarType.fixed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
        titleTextStyle:
            GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
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
      locale: const Locale('fi', 'FI'),
      routerConfig: router,
    );
  }
}
