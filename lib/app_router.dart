import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/auth_provider.dart';
import 'models/post_model.dart';
import 'models/user_profile_model.dart';
import 'models/hike_plan_model.dart';

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
import 'pages/group_hike_hub_page.dart';
import 'pages/packing_list_page.dart';
import 'pages/route_planner_page.dart';
import 'pages/post_detail_page.dart';
import 'pages/profile_full_screen_map_page.dart';
import 'pages/find_users_page.dart';
import 'pages/followers_following_list_page.dart';
import 'pages/settings_page.dart';
import 'pages/food_planner_page.dart';
import 'pages/notifications_page.dart';

import 'widgets/main_scaffold.dart';
import 'widgets/user_hikes_map_section.dart';

// Navigator-avaimet juuri- ja shell-navigaattoreille
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/home',
      debugLogDiagnostics: true,
      refreshListenable: authProvider.authStateNotifier,
      routes: [
        // --- SHELL-REITTI ALANAVIGAATIOPALKILLE ---
        // Tämä reitti hallitsee pääsivuja, joilla on yhteinen navigaatiopalkki.
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainScaffoldWithBottomNav(navigationShell: navigationShell);
          },
          branches: <StatefulShellBranch>[
            // 1. Home-haara
            StatefulShellBranch(
              navigatorKey: _shellNavigatorKey, // Yhteinen avain haaroille
              routes: <RouteBase>[
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomePage(),
                ),
              ],
            ),
            // 2. Notes-haara
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/notes',
                  builder: (context, state) => const NotesPage(),
                ),
              ],
            ),
            // 3. Profile-haara
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/profile',
                  // Näyttää oletuksena oman profiilin
                  builder: (context, state) => const ProfilePage(),
                ),
              ],
            ),
          ],
        ),

        // --- YLÄTASON REitit (AVAUTUVAT SHELLIN PÄÄLLE) ---
        // Nämä reitit avautuvat koko näytölle, peittäen alareunan navigaatiopalkin.

        // Auth-reitit
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),

        // Profiiliin liittyvät sivut
        GoRoute(
          path: '/profile/edit',
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
        GoRoute(
          path: '/profile/map',
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
        GoRoute(
          path: '/profile/:userId', // Muiden käyttäjien profiilit
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final userId = state.pathParameters['userId'];
            if (userId == null) {
              return const Scaffold(
                  body: Center(child: Text('User ID missing.')));
            }
            bool forceBack = false;
            final extra = state.extra;
            if (extra is Map<String, dynamic>) {
              forceBack = extra['forceBack'] == true;
            } else if (extra is bool) {
              forceBack = extra;
            }
            return ProfilePage(userId: userId, forceBack: forceBack);
          },
        ),
        GoRoute(
          path: '/profile/:userId/followers',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return FollowersFollowingListPage(
              userId: userId,
              listType: UserListType.followers,
            );
          },
        ),
        GoRoute(
          path: '/profile/:userId/following',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return FollowersFollowingListPage(
              userId: userId,
              listType: UserListType.following,
            );
          },
        ),

        // Muut toiminnalliset sivut
        GoRoute(
          path: '/find-users',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const FindUsersPage(),
        ),
        GoRoute(
          path: '/create-post',
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
          path: '/post/:id',
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
          path: '/users/:userId/posts',
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
          path: '/settings',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/notifications',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const NotificationsPage(),
        ),

        // Reittisuunnitteluun liittyvät sivut
        GoRoute(
          path: '/route-planner',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const RoutePlannerPage(),
        ),
        GoRoute(
          path: '/hike-plan-hub',
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
          path: '/group-hike-hub',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final plan = state.extra as HikePlan?;
            if (plan == null) {
              return const Scaffold(
                  body: Center(child: Text('Group hike plan not found!')));
            }
            return GroupHikeHubPage(initialPlan: plan);
          },
        ),
        GoRoute(
          path: '/hike-plan/:planId/food-planner',
          name: 'foodPlannerPage',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final planId = state.pathParameters['planId']!;
            final hikePlan = state.extra as HikePlan?;
            return FoodPlannerPage(planId: planId, initialPlan: hikePlan);
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
            final userId = state.uri.queryParameters['userId'];
            if (hikePlan == null) {
              return const Scaffold(
                  body: Center(child: Text('Hike Plan data missing.')));
            }
            return PackingListPage(
              planId: planId, 
              initialPlan: hikePlan,
              userId: userId,
            );
          },
        ),
        // POISTETTU VÄLIAIKAISESTI: Uusi reitti ateriasuunnitelmalle
        /*
        GoRoute(
          path: '/hike-plan/:planId/meal-planner',
          name: 'mealPlannerPage',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            // Ateriasuunnitelma käyttää RoutePlannerProvideria, joten
            // varmistetaan, että se on alustettu.
            final provider = context.read<RoutePlannerProvider>();
            if (provider.plan.id != state.pathParameters['planId']) {
              // Jos providerissa on väärä suunnitelma, näytä virhe.
              // Oikea tapa olisi ladata suunnitelma tässä, mutta
              // nykyisellä logiikalla se ladataan Hub-sivulla.
              return const Scaffold(
                  body: Center(child: Text('Meal plan data mismatch.')));
            }
            return const MealPlannerPage();
          },
        ),
        */
      ],
      // --- UUDELLEENOHJAUSLOGIIKKA ---
      redirect: (context, state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final location = state.matchedLocation;
        final isAuthRoute = location == '/login' || location == '/register';

        if (!isLoggedIn && !isAuthRoute) return '/login';
        if (isLoggedIn && isAuthRoute) return '/home';
        return null;
      },
    );

    // --- TEEMA-ASETUKSET ---
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

    // --- MATERIALAPP.ROUTER ---
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
