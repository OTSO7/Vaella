// lib/models/user_profile_model.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Achievement-malli (oletetaan, että tämä on jo määritelty ja toimii)
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final DateTime dateAchieved;
  final String? imageUrl;
  final String iconName;

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

  static IconData getIconFromName(String name) {
    switch (name) {
      case 'emoji_events_outlined':
        return Icons.emoji_events_outlined;
      case 'star':
        return Icons.star;
      // ... muut ikonit ...
      default:
        return Icons.help_outline;
    }
  }

  factory Achievement.fromFirestore(Map<String, dynamic> data, String id) {
    final name = data['iconName'] as String? ?? 'emoji_events_outlined';
    return Achievement(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      icon: getIconFromName(name),
      iconColor: Color(data['iconColorValue'] as int? ?? Colors.amber.value),
      dateAchieved:
          (data['dateAchieved'] as Timestamp? ?? Timestamp.now()).toDate(),
      imageUrl: data['imageUrl'] as String?,
      iconName: name,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'iconName': iconName,
      'iconColorValue': iconColor.value,
      'dateAchieved': Timestamp.fromDate(dateAchieved),
      'imageUrl': imageUrl,
    };
  }
}

// Sticker-malli (oletetaan, että tämä on jo määritelty ja toimii)
class Sticker {
  final String id;
  final String name;
  final String imageUrl;

  Sticker({required this.id, required this.name, required this.imageUrl});

  factory Sticker.fromFirestore(Map<String, dynamic> data, String id) {
    return Sticker(
      id: id,
      name: data['name'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
    );
  }
  Map<String, dynamic> toFirestore() => {'name': name, 'imageUrl': imageUrl};
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
  List<String> followingIds;
  List<String> followerIds;
  int postsCount; // UUSI: Denormalisoitu julkaisujen määrä

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
    this.followingIds = const [],
    this.followerIds = const [],
    this.postsCount = 0, // UUSI: Oletusarvo 0
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    final String retrievedDisplayName =
        data['displayName'] as String? ?? data['name'] as String? ?? '';

    List<Achievement> parsedAchievements = [];
    if (data['achievements'] is List) {
      parsedAchievements = (data['achievements'] as List<dynamic>).map((a) {
        final achievementData = Map<String, dynamic>.from(a);
        final String achievementId = achievementData['id']?.toString() ??
            FirebaseFirestore.instance.collection('temp').doc().id;
        return Achievement.fromFirestore(achievementData, achievementId);
      }).toList();
    }

    List<Sticker> parsedStickers = [];
    if (data['stickers'] is List) {
      parsedStickers = (data['stickers'] as List<dynamic>).map((s) {
        final stickerData = Map<String, dynamic>.from(s);
        final String stickerId = stickerData['id']?.toString() ??
            FirebaseFirestore.instance.collection('temp').doc().id;
        return Sticker.fromFirestore(stickerData, stickerId);
      }).toList();
    }

    List<String> parseStringList(dynamic listData) {
      if (listData is List) {
        return listData
            .map((item) => item?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList()
            .cast<String>();
      }
      return [];
    }

    return UserProfile(
      uid: uid,
      username: data['username'] as String? ?? '',
      displayName: retrievedDisplayName,
      email: data['email'] as String? ?? '',
      photoURL: data['photoURL'] as String?,
      bio: data['bio'] as String?,
      bannerImageUrl: data['bannerImageUrl'] as String?,
      stats: Map<String, dynamic>.from(data['stats'] as Map? ?? {}),
      achievements: parsedAchievements,
      stickers: parsedStickers,
      followingIds: parseStringList(data['followingIds'] ?? data['friends']),
      followerIds: parseStringList(data['followerIds']),
      postsCount: (data['postsCount'] as num?)?.toInt() ?? 0, // UUSI
    );
  }

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
      'followingIds': followingIds,
      'followerIds': followerIds,
      'postsCount': postsCount, // UUSI
    };
  }

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
    List<String>? followingIds,
    List<String>? followerIds,
    int? postsCount, // UUSI
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
      followingIds: followingIds ?? this.followingIds,
      followerIds: followerIds ?? this.followerIds,
      postsCount: postsCount ?? this.postsCount, // UUSI
    );
  }
}
