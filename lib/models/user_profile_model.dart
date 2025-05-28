// lib/models/user_profile_model.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Achievement-malli
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon; // Ikonipohjainen saavutus
  final Color iconColor;
  final DateTime dateAchieved;
  final String? imageUrl; // Valinnainen kuva (esim. kansallispuisto-tarra)

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    this.icon = Icons.emoji_events_outlined, // Oletusikoni
    this.iconColor = Colors.amber, // Oletusväri
    required this.dateAchieved,
    this.imageUrl, // Ota huomioon konstruktorissa
  });

  // Luo Achievement Firestore-dokumentista (myöhempää laajennusta varten)
  factory Achievement.fromFirestore(Map<String, dynamic> data, String id) {
    return Achievement(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      icon: IconData(data['iconCodePoint'],
          fontFamily: data['iconFontFamily'] ??
              'MaterialIcons'), // Vaatii koodipisteen ja fonttifamilian
      iconColor: Color(data['iconColorValue'] ?? Colors.amber.value),
      dateAchieved: (data['dateAchieved'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'],
    );
  }

  // Muunna Achievement Mapiksi Firestoreen tallentamista varten
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconColorValue': iconColor.value,
      'dateAchieved': dateAchieved,
      'imageUrl': imageUrl,
    };
  }
}

// Sticker-malli (voit yhdistää tämän Achievement-malliin, jos ne ovat samankaltaisia)
// Pidetään erillään nyt selkeyden vuoksi, mutta harkitse yhdistämistä
class Sticker {
  final String id;
  final String name; // Kansallispuiston nimi tai tarran nimi
  final String imageUrl; // Kuva tarrasta/merkistä

  Sticker({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  // Luo Sticker Firestore-dokumentista (myöhempää laajennusta varten)
  factory Sticker.fromFirestore(Map<String, dynamic> data, String id) {
    return Sticker(
      id: id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  // Muunna Sticker Mapiksi Firestoreen tallentamista varten
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'imageUrl': imageUrl,
    };
  }
}

// PÄIVITETTY UserProfile-malli
class UserProfile {
  final String uid;
  String username; // Nyt tallennetaan myös käyttäjätunnus
  String displayName; // Esim. "Matti Meikäläinen"
  String email;
  String? photoURL; // Profiilikuvan URL
  String? bio;
  String? bannerImageUrl; // UUSI: Profiilisivun bannerikuva
  Map<String, dynamic> stats;
  List<Achievement> achievements;
  List<Sticker> stickers; // Esim. kerätyt kansallispuistotarrat

  UserProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.email,
    this.photoURL,
    this.bio,
    this.bannerImageUrl, // Ota huomioon konstruktorissa
    this.stats = const {},
    this.achievements = const [],
    this.stickers = const [],
  });

  // Luo UserProfile Firestore-dokumentista
  factory UserProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      username: data['username'] ?? '',
      displayName: data['name'] ?? '', // Oletetaan 'name' Firestoresta
      email: data['email'] ?? '',
      photoURL: data['photoURL'],
      bio: data['bio'],
      bannerImageUrl: data['bannerImageUrl'],
      stats: Map<String, dynamic>.from(data['stats'] ?? {}),
      // Huom: achievements ja stickers vaatisivat alikokoelmien haun
      // tai niiden sisällyttämisen päädokumenttiin, jos ne ovat pieniä listoja.
      // Tässä esimerkissä oletetaan ne tyhjiksi toistaiseksi, jos et hae niitä Firebasesta.
      achievements: (data['achievements'] as List<dynamic>?)
              ?.map((a) => Achievement.fromFirestore(
                  Map<String, dynamic>.from(a), a['id'] ?? ''))
              .toList() ??
          [],
      stickers: (data['stickers'] as List<dynamic>?)
              ?.map((s) => Sticker.fromFirestore(
                  Map<String, dynamic>.from(s), s['id'] ?? ''))
              .toList() ??
          [],
    );
  }

  // Muunna UserProfile Mapiksi Firestoreen tallentamista varten
  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'bio': bio,
      'bannerImageUrl': bannerImageUrl,
      'stats': stats,
      'achievements': achievements.map((a) => a.toFirestore()).toList(),
      'stickers': stickers.map((s) => s.toFirestore()).toList(),
    };
  }

  // Kopio-metodi päivitystä varten
  UserProfile copyWith({
    String? username,
    String? displayName,
    String? email,
    String? photoURL,
    String? bio,
    String? bannerImageUrl,
    Map<String, dynamic>? stats,
    List<Achievement>? achievements,
    List<Sticker>? stickers,
  }) {
    return UserProfile(
      uid: uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      bio: bio ?? this.bio,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      stats: stats ?? this.stats,
      achievements: achievements ?? this.achievements,
      stickers: stickers ?? this.stickers,
    );
  }
}
