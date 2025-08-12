import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  // Muutetaan nimeksi "_identifierController" kuvaamaan, että se voi olla joko sähköposti tai käyttäjätunnus
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInCubic,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _identifierController.dispose(); // Päivitetty
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      try {
        // Käytetään uutta kirjautumismetodia
        await authProvider.loginWithUsernameOrEmail(
          _identifierController.text.trim(),
          _passwordController.text,
        );
        // Tarkista mounted-tila ennen kontekstin käyttöä
        if (!mounted) return;
        // GoRouterin redirect-logiikka AuthProviderissa hoitaa navigoinnin
      } catch (e) {
        // Tarkista mounted-tila ennen kontekstin käyttöä
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final authProvider = Provider.of<AuthProvider>(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Taustakuva
          Positioned.fill(
            child: Image.asset(
              'assets/images/header4.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Gradientti peitto
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.95),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // Sovelluksen logo tai kuvake
                          Hero(
                            tag: 'appLogo',
                            child: Image.asset(
                              'assets/images/white3.png',
                              height: screenHeight * 0.25,
                              fit: BoxFit.contain,
                            ),
                          ),

                          Text(
                            'Adventures await!',
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge?.copyWith(
                              color: Colors.white70,
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.06),

                          TextFormField(
                            controller: _identifierController, // Päivitetty
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Username or email address',
                              labelText: 'Username or email address',
                              prefixIcon:
                                  Icon(Icons.person_outline), // Yleisempi ikoni
                            ),
                            keyboardType: TextInputType
                                .emailAddress, // Voi auttaa mobiilissa
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your username or email address.';
                              }
                              // Ei tehdä tiukkaa sähköpostivalidointia tässä, koska se voi olla myös käyttäjätunnus
                              // Tarkistetaan vain, ettei ole tyhjä
                              return null;
                            },
                          ),
                          SizedBox(height: screenHeight * 0.025),
                          TextFormField(
                            controller: _passwordController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Password',
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password.';
                              }
                              if (value.length < 6) {
                                return 'The password must be at least 6 characters long.';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: screenHeight * 0.015),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                if (!mounted) return; // Tarkista mounted-tila
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Salasanan palautus -toimintoa ei ole vielä toteutettu.')),
                                );
                              },
                              child: Text(
                                'Forgot password?',
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: Colors.orange.shade300),
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.035),
                          ElevatedButton(
                            onPressed: authProvider.isLoading ? null : _login,
                            style: Theme.of(context).elevatedButtonTheme.style,
                            child: authProvider.isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Log in'),
                          ),
                          SizedBox(height: screenHeight * 0.04),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "No account yet? ",
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  context.push('/register');
                                },
                                child: Text(
                                  'create one here',
                                  style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.tealAccent.shade200),
                                ),
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
            ),
          ),
        ],
      ),
    );
  }
}
