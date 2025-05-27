// lib/models/user_profile_model.dart
import 'package:flutter/material.dart'; // Tarvitaan IconDataa varten achievementissa

// Esimerkki Achievement-mallista, voidaan eriyttää omaan tiedostoon jos kasvaa
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final DateTime dateAchieved;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.iconColor = Colors.amber, // Oletusväri
    required this.dateAchieved,
  });
}

// Esimerkki Sticker-mallista
class Sticker {
  final String id;
  final String name;
  final String imageUrl; // Käytetään placeholder-kuvia aluksi

  Sticker({
    required this.id,
    required this.name,
    required this.imageUrl,
  });
}

class UserProfile {
  final String uid;
  String displayName;
  String email; // Oletetaan, että tämä tulee AuthProviderista
  String? photoURL;
  String? bio;
  Map<String, dynamic>
      stats; // Esim. {'hikesCompleted': 10, 'kilometersWalked': 150.5}
  List<Achievement> achievements;
  List<Sticker> stickers;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoURL,
    this.bio,
    this.stats = const {},
    this.achievements = const [],
    this.stickers = const [],
  });
}
