// lib/main.dart
import 'package:flutter/material.dart';

// Firebase-importit
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // FlutterFire CLI:n luoma tiedosto

// Intl-import
import 'package:intl/date_symbol_data_local.dart';

// Sovelluksesi omat importit
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('fi_FI', null);

  runApp(
    ChangeNotifierProvider(
      create: (_) =>
          AuthProvider(), // Tarjoaa AuthProviderin koko widget-puulle
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AppRouter-widget hoitaa GoRouterin ja MaterialApp.routerin luomisen
    return const AppRouter();
  }
}
