// lib/pages/notes_page.dart
import 'package:flutter/material.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // HomePage, NotesPage ja ProfilePage voivat kukin hallita omaa AppBariaan
      // tai AppBar voidaan siirtää osaksi MainScaffoldWithBottomNav-widgetiä myöhemmin.
      appBar: AppBar(
        title: const Text('Suunnittelija'),
        backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        elevation: 1,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt_outlined,
                size: 80, color: Theme.of(context).primaryColor),
            const SizedBox(height: 20),
            Text(
              'Tänne tulevat vaellussunnitelmasi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
