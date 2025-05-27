// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart'; // Huomaa polun muutos

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Omat Muistiinpanot'),
        backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Kirjaudu ulos',
            onPressed: () {
              authProvider.logout();
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_filled,
                size: 80, color: Theme.of(context).primaryColor),
            const SizedBox(height: 20),
            Text(
              'Tervetuloa kotisivulle!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            const Text('Täältä löydät pian vaellusmuistiinpanosi.'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Uuden muistiinpanon lisäystä ei ole vielä toteutettu.')),
          );
        },
        tooltip: 'Lisää muistiinpano',
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: const Icon(Icons.add_location_alt_outlined),
      ),
    );
  }
}
