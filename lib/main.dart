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
import 'providers/route_planner_provider.dart'; // LISÄYS: Tuo uusi provider
import 'app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('fi_FI', null);

  // KORJAUS: Vaihdetaan ChangeNotifierProvider MultiProvideriksi,
  // jotta voimme tarjota useita providereita.
  runApp(
    MultiProvider(
      providers: [
        // 1. Olemassa oleva AuthProvider
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // 2. LISÄYS: Uusi RoutePlannerProvider
        ChangeNotifierProvider(create: (_) => RoutePlannerProvider()),

        // Voit lisätä tulevaisuudessa lisää providereita tähän listaan...
      ],
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
