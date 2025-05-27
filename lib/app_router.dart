import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart'; // Varmista, että tämä polku on oikein

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

// --- SIVUT (Pages) ---

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Tehdään tästä dummy-kirjautuminen
  void _login() {
    // Ei validointia, ei viivettä, ei latausikonia dummy-versiossa.
    // Kutsutaan suoraan AuthProviderin login-metodia siirtymiseksi.
    Provider.of<AuthProvider>(context, listen: false).login();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Taustakuva
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/login_background.jpg'), // Varmista, että kuva on tässä polussa
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Tummennuskerros
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(
                        Icons.terrain_rounded,
                        size: screenHeight * 0.12,
                        color: theme.colorScheme.secondary,
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      Text(
                        'TrekNote',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 32,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        'Kirjaudu sisään ja tallenna seikkailusi',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Sähköposti (esim. user@example.com)',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Syötä sähköpostiosoite';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Syötä validi sähköpostiosoite';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: screenHeight * 0.025),
                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Salasana (esim. password)',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Syötä salasana';
                          }
                          if (value.length < 6) {
                            return 'Salasanan tulee olla vähintään 6 merkkiä pitkä';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Salasanan palautus -toimintoa ei ole vielä toteutettu.')),
                            );
                          },
                          child: const Text('Unohtuiko salasana?'),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      ElevatedButton(
                        onPressed: _login,
                        child: const Text('Kirjaudu sisään (Dummy)'),
                      ),
                      SizedBox(height: screenHeight * 0.04),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Eikö sinulla ole tiliä? ",
                              style: theme.textTheme.bodyMedium),
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Rekisteröitymissivua ei ole vielä toteutettu.')),
                              );
                            },
                            child: const Text('Luo tili'),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.02),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Omat Muistiinpanot'),
        backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Kirjaudu ulos',
            onPressed: () {
              authProvider.logout();
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_filled,
                size: 80, color: Theme.of(context).primaryColor),
            const SizedBox(height: 20),
            Text(
              'Tervetuloa kotisivulle!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            const Text('Täältä löydät pian vaellusmuistiinpanosi.'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Uuden muistiinpanon lisäystä ei ole vielä toteutettu.')),
          );
        },
        tooltip: 'Lisää muistiinpano',
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: const Icon(Icons.add_location_alt_outlined),
      ),
    );
  }
}
