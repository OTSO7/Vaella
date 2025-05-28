// lib/main.dart
import 'package:flutter/material.dart';

// Firebase-importit
import 'package:firebase_core/firebase_core.dart'; // <--- LISÄÄ TÄMÄ
import 'firebase_options.dart'; // <--- LISÄÄ TÄMÄ (FlutterFire CLI:n luoma tiedosto)

// Intl-import (jos käytät päivämäärien muotoilua)
import 'package:intl/date_symbol_data_local.dart';

// Sovelluksesi omat importit (esimerkkejä, sovella omiisi)
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart'; // Varmista oikea polku
import 'app_router.dart'; // Varmista oikea polku

void main() async {
  // Varmista, että Flutterin widget-sidokset on alustettu ennen kuin
  // mitään Flutteriin tai alustakohtaisiin toimintoihin liittyvää kutsutaan.
  WidgetsFlutterBinding.ensureInitialized();

  // Alusta Firebase käyttäen firebase_options.dart-tiedostoa.
  // Tämä on tehtävä ennen kuin mitään muita Firebase-palveluita käytetään.
  await Firebase.initializeApp(
    options:
        DefaultFirebaseOptions.currentPlatform, // <--- TÄMÄ ON KRIITTINEN RIVI
  );

  // Alusta intl-paketti suomenkieliselle päivämäärämuotoilulle (jos tarpeen)
  // Voit pitää tämän, jos käytät DateFormatia 'fi_FI'-lokaalilla.
  await initializeDateFormatting('fi_FI', null);

  // Käynnistä sovellus
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(), // Olettaen, että käytät AuthProvideria
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AppRouter hoitaa MaterialApp.routerin, teeman ja lokalisaatioasetukset
    return AppRouter();
  }
}
