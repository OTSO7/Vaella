// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'pages/login_page.dart'; // <-- UUSI IMPORT
import 'pages/home_page.dart'; // <-- UUSI IMPORT

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              authProvider.isLoggedIn ? const HomePage() : const LoginPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomePage(),
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final loggingIn = state.matchedLocation == '/login';

        if (!isLoggedIn && !loggingIn) {
          return '/login';
        }
        if (isLoggedIn && loggingIn) {
          return '/';
        }
        return null;
      },
    );

    return MaterialApp.router(
      title: 'TrekNote VaellusApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Teema pysyy samana kuin aiemmin
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
      ),
      routerConfig: router,
    );
  }
}
