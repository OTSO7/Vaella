// lib/pages/register_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart'; // Oletetaan, että käytät tätä myöhemmin

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() {
    if (_formKey.currentState!.validate()) {
      // Tässä vaiheessa ei tehdä oikeaa rekisteröintiä,
      // vaan simuloidaan onnistumista ja siirrytään eteenpäin.
      // Voit myöhemmin lisätä tähän Firebase-kutsut tai muun backend-logiikan.

      // Esimerkki: Tulostetaan tiedot konsoliin
      print('Rekisteröidytään käyttäjällä:');
      print('Nimi: ${_nameController.text}');
      print('Sähköposti: ${_emailController.text}');

      // Näytetään onnistumisviesti
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tili luotu onnistuneesti! Voit nyt kirjautua sisään.'),
          backgroundColor: Colors.green[700],
        ),
      );

      // Vaihtoehto 1: Palaa kirjautumissivulle
      // context.pop(); // Jos tulit .push() metodilla

      // Vaihtoehto 2: Kirjaa käyttäjä sisään ja ohjaa kotisivulle (dummy-toiminto)
      Provider.of<AuthProvider>(context, listen: false).login();
      context.go('/'); // Ohjaa juureen, josta AppRouter ohjaa HomePageen
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      // Lisätään AppBar, jotta käyttäjä voi palata helposti takaisin, jos saapui .push()-kutsulla
      // Jos käytät .go() ja haluat "takaisin"-nuolen, GoRouterin pitää tietää, mistä tultiin.
      // Yksinkertaisempi on antaa selkeä linkki takaisin LoginPageen.
      // Tässä tapauksessa jätetään AppBar pois, jotta ulkoasu on identtinen LoginPagen kanssa.
      // appBar: AppBar(
      //   title: const Text('Luo uusi tili'),
      //   elevation: 0,
      //   backgroundColor: Colors.transparent, // Läpinäkyvä, jotta taustakuva näkyy
      // ),
      body: Stack(
        children: [
          // Taustakuva (sama kuin LoginPage)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/header2.jpg'), // Varmista, että tämä kuva on olemassa
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Tummennuskerros (sama kuin LoginPage)
          Container(
            decoration: BoxDecoration(
              color: Colors.black
                  .withOpacity(0.65), // Hieman tummempi kuin login? Tai sama.
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
                      // Logo (sama kuin LoginPage)
                      Image.asset(
                        'assets/images/white1.png', // Varmista, että tämä kuva on olemassa
                        height: screenHeight * 0.10,
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      Text(
                        'Luo uusi TrekNote-tili',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 28, // Hieman pienempi kuin login
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        'Liity mukaan seikkailijoiden yhteisöön!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                      SizedBox(height: screenHeight * 0.04),

                      // Nimi-kenttä
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Nimi (esim. Matti Meikäläinen)',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        keyboardType: TextInputType.name,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Syötä nimesi';
                          }
                          if (value.trim().length < 2) {
                            return 'Nimen tulee olla vähintään 2 merkkiä';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Sähköpostikenttä
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Sähköposti',
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
                      SizedBox(height: screenHeight * 0.02),

                      // Salasanakenttä
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
                      SizedBox(height: screenHeight * 0.02),

                      // Vahvista salasana -kenttä
                      TextFormField(
                        controller: _confirmPasswordController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Vahvista salasana',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vahvista salasana';
                          }
                          if (value != _passwordController.text) {
                            return 'Salasanat eivät täsmää';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: screenHeight * 0.04),

                      // Luo tili -painike
                      ElevatedButton(
                        onPressed: _register,
                        child: const Text('Luo tili'),
                      ),
                      SizedBox(height: screenHeight * 0.03),

                      // Linkki takaisin kirjautumissivulle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Onko sinulla jo tili? ",
                              style: theme.textTheme.bodyMedium),
                          TextButton(
                            onPressed: () {
                              // Ohjaa takaisin LoginPageen. Jos käytit .push() tullessa, .pop() toimii.
                              // Jos haluat varmemmin, käytä GoRouteria:
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(
                                    '/login'); // Varmuuden vuoksi, jos ei voi popata
                              }
                            },
                            child: const Text('Kirjaudu sisään'),
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
