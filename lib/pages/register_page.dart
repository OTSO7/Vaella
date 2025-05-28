// lib/pages/register_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController =
      TextEditingController(); // UUSI
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Simuloidaan "tietokantaa" varatuista käyttäjätunnuksista
  // Todellisessa sovelluksessa tämä tarkistettaisiin palvelimelta.
  static final Set<String> _takenUsernames = {
    'testikäyttäjä',
    'admin',
    'käyttäjä123'
  };

  @override
  void dispose() {
    _usernameController.dispose(); // UUSI
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
      // Myöhemmin tähän lisätään backend-logiikka.

      // Otetaan talteen syötetty käyttäjätunnus
      final newUsername = _usernameController.text.trim().toLowerCase();

      // Tarkistetaan uudelleen uniikkius (vaikka validoija tekeekin sen jo)
      // Tämä on lisävarmistus, jos haluat tehdä jotain ennen kuin lisäät sen _takenUsernames-listaan.
      if (_takenUsernames.contains(newUsername)) {
        // Tämä ei pitäisi tapahtua, jos validoija toimii, mutta varmuuden vuoksi.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Käyttäjätunnus "$newUsername" on jo varattu. Valitse toinen.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      print('Rekisteröidytään käyttäjällä:');
      print('Käyttäjätunnus: $newUsername');
      print('Nimi: ${_nameController.text}');
      print('Sähköposti: ${_emailController.text}');

      // Dummy-vaiheessa: Lisää uusi käyttäjätunnus "varattujen" listaan
      // Todellisessa sovelluksessa tämä tapahtuisi palvelimella.
      _takenUsernames.add(newUsername);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Tili käyttäjätunnuksella "$newUsername" luotu onnistuneesti! Voit nyt kirjautua sisään.'),
          backgroundColor: Colors.green[700],
        ),
      );

      // Vaihtoehto: Kirjaa käyttäjä sisään ja ohjaa kotisivulle
      Provider.of<AuthProvider>(context, listen: false).login();
      context.go('/');
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
              color: Colors.black.withOpacity(0.65),
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
                      Image.asset(
                        'assets/images/white1.png',
                        height: screenHeight * 0.10,
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      Text(
                        'Luo uusi TrekNote-tili',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 28,
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

                      // Käyttäjätunnus-kenttä (UUSI)
                      TextFormField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Käyttäjätunnus',
                          prefixIcon: Icon(Icons.account_circle_outlined),
                        ),
                        keyboardType: TextInputType.text,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Syötä käyttäjätunnus';
                          }
                          if (value.trim().length < 3) {
                            return 'Käyttäjätunnuksen tulee olla vähintään 3 merkkiä';
                          }
                          if (value.contains(' ')) {
                            return 'Käyttäjätunnus ei saa sisältää välilyöntejä';
                          }
                          // Tarkistetaan uniikkius simuloidusta listasta (case-insensitive)
                          if (_takenUsernames
                              .contains(value.trim().toLowerCase())) {
                            return 'Käyttäjätunnus on jo varattu';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Nimi-kenttä
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Koko nimi (esim. Matti Meikäläinen)',
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
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Syötä sähköpostiosoite';
                          }
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegex.hasMatch(value)) {
                            return 'Syötä validi sähköpostiosoite';
                          }
                          // Tähän voisi lisätä myös sähköpostin uniikkiuden tarkistuksen
                          // if (_takenEmails.contains(value.trim().toLowerCase())) {
                          //   return 'Sähköposti on jo käytössä';
                          // }
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
                        autovalidateMode: AutovalidateMode.onUserInteraction,
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

                      ElevatedButton(
                        onPressed: _register,
                        child: const Text('Luo tili'),
                      ),
                      SizedBox(height: screenHeight * 0.03),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Onko sinulla jo tili? ",
                              style: theme.textTheme.bodyMedium),
                          TextButton(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/login');
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
