// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // <--- LISÄÄ TÄMÄ IMPORT
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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

  void _login() {
    // Varmistetaan, että lomake on validi ennen "kirjautumista"
    if (_formKey.currentState!.validate()) {
      Provider.of<AuthProvider>(context, listen: false).login();
      // GoRouter hoitaa uudelleenohjauksen, jos se on määritelty AppRouterissa
      // tai voit eksplisiittisesti navigoida: context.go('/');
    } else {
      // Voit näyttää virheilmoituksen, jos lomake ei ole validi
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarkista syöttämäsi tiedot.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/header2.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
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
                  key: _formKey, // Muista lisätä tämä Form-widgetille
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Image.asset(
                        'assets/images/white1.png',
                        height: screenHeight * 0.12,
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
                        'Kirjaudu sisään ja aloita seikkailusi',
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
                          hintText: 'Salasana',
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
                        // Dummy-teksti voi olla hämäävä, jos validointi on käytössä
                        child: const Text('Kirjaudu sisään'),
                      ),
                      SizedBox(height: screenHeight * 0.04),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Eikö sinulla ole tiliä? ",
                              style: theme.textTheme
                                  .bodyMedium), // Varmista, että tämä tyyli on ok teemassasi
                          TextButton(
                            onPressed: () {
                              // Navigoidaan rekisteröitymissivulle
                              context.push(
                                  '/register'); // TAI context.go('/register');
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
