import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';

class AppRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              authProvider.isLoggedIn ? HomePage() : LoginPage(),
        ),
        GoRoute(path: '/login', builder: (context, state) => LoginPage()),
        GoRoute(path: '/home', builder: (context, state) => HomePage()),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }
}

// Placeholder-näytöt:

class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Login Page')));
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Home Page')));
  }
}
