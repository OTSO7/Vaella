// lib/models/user_profile_model.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Helper-funktio, jota käytetään `copyWith`-metodissa
ValueGetter<T?> toValueGetter<T>(T? value) => () => value;

enum UserRelation { self, following, notFollowing, unknown }

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
      case 'filter_hdr':
        return Icons.filter_hdr;
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

class HikeStats {
  final double totalDistance;
  final int totalHikes;
  final double highestAltitude;

  HikeStats(
      {this.totalDistance = 0.0,
      this.totalHikes = 0,
      this.highestAltitude = 0.0});

  factory HikeStats.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return HikeStats();
    return HikeStats(
      totalDistance: (data['totalDistance'] as num?)?.toDouble() ?? 0.0,
      totalHikes: (data['totalHikes'] as num?)?.toInt() ?? 0,
      highestAltitude: (data['highestAltitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'totalDistance': totalDistance,
        'totalHikes': totalHikes,
        'highestAltitude': highestAltitude,
      };
}

class UserProfile {
  final String uid;
  final String username;
  final String displayName;
  final String email;
  final String? photoURL;
  final String? bio;
  final String? bannerImageUrl;
  final HikeStats hikeStats;
  final List<Achievement> achievements;
  final List<Sticker> stickers;
  final List<String> followingIds;
  final List<String> followerIds;
  final List<String> featuredHikeIds;
  final int postsCount;
  final int level;
  final int experience;
  final bool isPrivate;
  UserRelation relationToCurrentUser;

  UserProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.email,
    this.photoURL,
    this.bio,
    this.bannerImageUrl,
    HikeStats? hikeStats,
    this.achievements = const [],
    this.stickers = const [],
    this.followingIds = const [],
    this.followerIds = const [],
    this.featuredHikeIds = const [],
    this.postsCount = 0,
    this.level = 1,
    this.experience = 0,
    this.isPrivate = false,
    this.relationToCurrentUser = UserRelation.unknown,
  }) : this.hikeStats = hikeStats ?? HikeStats();

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String uid) {
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
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      photoURL: data['photoURL'] as String?,
      bio: data['bio'] as String?,
      bannerImageUrl: data['bannerImageUrl'] as String?,
      hikeStats:
          HikeStats.fromFirestore(data['hikeStats'] as Map<String, dynamic>?),
      achievements: parsedAchievements,
      stickers: parsedStickers,
      followingIds: parseStringList(data['followingIds']),
      followerIds: parseStringList(data['followerIds']),
      featuredHikeIds: parseStringList(data['featuredHikeIds']),
      postsCount: (data['postsCount'] as num?)?.toInt() ?? 0,
      level: (data['level'] as num?)?.toInt() ?? 1,
      experience: (data['experience'] as num?)?.toInt() ?? 0,
      isPrivate: data['isPrivate'] as bool? ?? false,
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
      'hikeStats': hikeStats.toFirestore(),
      'achievements': achievements.map((a) => a.toFirestore()).toList(),
      'stickers': stickers.map((s) => s.toFirestore()).toList(),
      'followingIds': followingIds,
      'followerIds': followerIds,
      'featuredHikeIds': featuredHikeIds,
      'postsCount': postsCount,
      'level': level,
      'experience': experience,
      'isPrivate': isPrivate,
    };
  }

  UserProfile copyWith({
    String? uid,
    String? username,
    String? displayName,
    String? email,
    String? photoURL,
    ValueGetter<String?>? bio,
    ValueGetter<String?>? bannerImageUrl,
    HikeStats? hikeStats,
    List<Achievement>? achievements,
    List<Sticker>? stickers,
    List<String>? followingIds,
    List<String>? followerIds,
    List<String>? featuredHikeIds,
    int? postsCount,
    int? level,
    int? experience,
    bool? isPrivate,
    UserRelation? relationToCurrentUser,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      bio: bio != null ? bio() : this.bio,
      bannerImageUrl:
          bannerImageUrl != null ? bannerImageUrl() : this.bannerImageUrl,
      hikeStats: hikeStats ?? this.hikeStats,
      achievements: achievements ?? this.achievements,
      stickers: stickers ?? this.stickers,
      followingIds: followingIds ?? this.followingIds,
      followerIds: followerIds ?? this.followerIds,
      featuredHikeIds: featuredHikeIds ?? this.featuredHikeIds,
      postsCount: postsCount ?? this.postsCount,
      level: level ?? this.level,
      experience: experience ?? this.experience,
      isPrivate: isPrivate ?? this.isPrivate,
      relationToCurrentUser:
          relationToCurrentUser ?? this.relationToCurrentUser,
    );
  }
}
