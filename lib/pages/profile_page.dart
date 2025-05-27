// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Tarvitaan uloskirjautumiseen
import '../providers/auth_provider.dart'; // Tarvitaan uloskirjautumiseen

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oma Profiili'),
        backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        elevation: 1,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_pin_circle_outlined,
                size: 80, color: Theme.of(context).primaryColor),
            const SizedBox(height: 20),
            Text(
              'Käyttäjän profiilitiedot',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Kirjaudu ulos'),
              onPressed: () {
                authProvider.logout();
                // GoRouter hoitaa uudelleenohjauksen login-sivulle AuthProviderin tilanmuutoksen myötä
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
            )
          ],
        ),
      ),
    );
  }
}
