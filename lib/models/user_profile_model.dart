import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Apufunktio ikonien nimien muuttamiseen IconData:ksi
IconData getIconFromName(String name) {
  switch (name) {
    case 'emoji_events_outlined':
      return Icons.emoji_events_outlined;
    case 'star':
      return Icons.star;
    case 'park':
      return Icons.park;
    case 'check_circle':
      return Icons.check_circle;
    case 'hiking':
      return Icons.hiking;
    case 'landscape':
      return Icons.landscape;
    // Lisää tarvittavat ikonit tähän
    default:
      return Icons.help_outline;
  }
}

// Achievement-malli
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final DateTime dateAchieved;
  final String? imageUrl;
  final String iconName; // Uusi kenttä Firestore-tallennukseen

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    this.icon = Icons.emoji_events_outlined,
    this.iconColor = Colors.amber,
    required this.dateAchieved,
    this.imageUrl,
    this.iconName = 'emoji_events_outlined',
  });

  factory Achievement.fromFirestore(Map<String, dynamic> data, String id) {
    final name = data['iconName'] ?? 'emoji_events_outlined';
    return Achievement(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      icon: getIconFromName(name),
      iconColor: Color(data['iconColorValue'] ?? Colors.amber.value),
      dateAchieved: (data['dateAchieved'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'],
      iconName: name,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'iconName': iconName,
      'iconColorValue': iconColor.value,
      'dateAchieved': dateAchieved,
      'imageUrl': imageUrl,
    };
  }
}

// Sticker-malli
class Sticker {
  final String id;
  final String name;
  final String imageUrl;

  Sticker({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  factory Sticker.fromFirestore(Map<String, dynamic> data, String id) {
    return Sticker(
      id: id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'imageUrl': imageUrl,
    };
  }
}

// UserProfile-malli
class UserProfile {
  final String uid;
  String username;
  String displayName;
  String email;
  String? photoURL;
  String? bio;
  String? bannerImageUrl;
  Map<String, dynamic> stats;
  List<Achievement> achievements;
  List<Sticker> stickers;
  List<String> friends; // UUSI: Lista ystävien UID:stä

  UserProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.email,
    this.photoURL,
    this.bio,
    this.bannerImageUrl,
    this.stats = const {},
    this.achievements = const [],
    this.stickers = const [],
    this.friends = const [], // Alustetaan tyhjällä listalla
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    // Varmista, että 'name' (displayName) on oikea kenttä, jos 'displayName' puuttuu
    // Firestore-skeemasi näytti aiemmin käyttävän 'name' displayNameksi,
    // joten huomioidaan se tässä.
    final String retrievedDisplayName =
        data['displayName'] ?? data['name'] ?? '';

    return UserProfile(
      uid: uid,
      username: data['username'] ?? '',
      displayName: retrievedDisplayName,
      email: data['email'] ?? '',
      photoURL: data['photoURL'],
      bio: data['bio'],
      bannerImageUrl: data['bannerImageUrl'],
      stats: Map<String, dynamic>.from(data['stats'] ?? {}),
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
      friends: List<String>.from(data['friends'] ?? []), // Hae friends-lista
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'displayName': displayName, // Varmista, että käytät 'displayName' tässä
      'email': email,
      'photoURL': photoURL,
      'bio': bio,
      'bannerImageUrl': bannerImageUrl,
      'stats': stats,
      'achievements': achievements.map((a) => a.toFirestore()).toList(),
      'stickers': stickers.map((s) => s.toFirestore()).toList(),
      'friends': friends, // Tallenna friends-lista
    };
  }

  // Lisää myös UID copyWith-metodiin varmuuden vuoksi, jos sitä tarvittaisiin
  UserProfile copyWith({
    String? uid,
    String? username,
    String? displayName,
    String? email,
    String? photoURL,
    String? bio,
    String? bannerImageUrl,
    Map<String, dynamic>? stats,
    List<Achievement>? achievements,
    List<Sticker>? stickers,
    List<String>? friends,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      bio: bio ?? this.bio,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      stats: stats ?? this.stats,
      achievements: achievements ?? this.achievements,
      stickers: stickers ?? this.stickers,
      friends: friends ?? this.friends,
    );
  }
}
