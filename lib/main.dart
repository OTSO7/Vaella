// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // <--- TARKISTA TÄMÄ IMPORT
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart'; // Varmista polku
import 'app_router.dart'; // Varmista polku

void main() async {
  // <--- ONKO TÄMÄ VARMASTI 'async'?
  WidgetsFlutterBinding.ensureInitialized(); // <--- ONKO TÄMÄ RIVI OLEMASSA?
  await initializeDateFormatting(
      'fi_FI', null); // <--- ONKO TÄMÄ RIVI JA 'await' OLEMASSA?

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppRouter();
  }
}
