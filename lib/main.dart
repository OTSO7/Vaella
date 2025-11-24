import 'package:flutter/material.dart';

// Firebase-importit
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Intl-import
import 'package:intl/date_symbol_data_local.dart';

// Sovelluksesi omat importit
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/follow_provider.dart';
import 'providers/route_planner_provider.dart';
import 'app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ),
    initializeDateFormatting('fi_FI', null),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FollowProvider()),
        ChangeNotifierProvider(create: (_) => RoutePlannerProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Synkronoi FollowProvider kun AuthProviderin userProfile muuttuu
    final authProvider = Provider.of<AuthProvider>(context);
    final followProvider = Provider.of<FollowProvider>(context, listen: false);

    // Synkronoi heti kun userProfile on saatavilla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authProvider.userProfile != null) {
        followProvider.setFollowingList(authProvider.userProfile!.followingIds);
      } else {
        followProvider.setFollowingList([]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AppRouter();
  }
}
