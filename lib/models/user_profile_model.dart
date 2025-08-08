import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum UserRelation {
  self,
  following,
  notFollowing,
  unknown,
}

class UserProfile {
  final String uid;
  final String email;
  final String username;
  final String displayName;
  final String? photoURL;
  final String? bannerImageUrl;
  final String? bio;
  final int level;
  final int experience;
  final int postsCount;
  final List<String> followerIds;
  final List<String> followingIds;
  final HikeStats hikeStats;
  final List<Achievement> achievements;
  final List<Sticker> stickers;
  UserRelation relationToCurrentUser;

  UserProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.displayName,
    this.photoURL,
    this.bannerImageUrl,
    this.bio,
    this.level = 1,
    this.experience = 0,
    this.postsCount = 0,
    this.followerIds = const [],
    this.followingIds = const [],
    required this.hikeStats,
    this.achievements = const [],
    this.stickers = const [],
    this.relationToCurrentUser = UserRelation.unknown,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final statsData = data['hikeStats'] as Map<String, dynamic>? ?? {};

    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      photoURL: data['photoURL'],
      bannerImageUrl: data['bannerImageUrl'],
      bio: data['bio'],
      level: data['level'] ?? 1,
      experience: data['experience'] ?? 0,
      postsCount: data['postsCount'] ?? 0,
      followerIds: List<String>.from(data['followerIds'] ?? []),
      followingIds: List<String>.from(data['followingIds'] ?? []),
      hikeStats: HikeStats.fromFirestore(statsData),
      achievements: (data['achievements'] as List<dynamic>? ?? [])
          .map((a) => Achievement.fromMap(a))
          .toList(),
      stickers: (data['stickers'] as List<dynamic>? ?? [])
          .map((s) => Sticker.fromMap(s))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'username': username,
      'displayName': displayName,
      'photoURL': photoURL,
      'bannerImageUrl': bannerImageUrl,
      'bio': bio,
      'level': level,
      'experience': experience,
      'postsCount': postsCount,
      'followerIds': followerIds,
      'followingIds': followingIds,
      'hikeStats': hikeStats.toFirestore(),
      'achievements': achievements.map((a) => a.toMap()).toList(),
      'stickers': stickers.map((s) => s.toMap()).toList(),
    };
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? username,
    String? displayName,
    String? photoURL,
    String? bannerImageUrl,
    String? bio,
    int? level,
    int? experience,
    int? postsCount,
    List<String>? followerIds,
    List<String>? followingIds,
    HikeStats? hikeStats,
    List<Achievement>? achievements,
    List<Sticker>? stickers,
    UserRelation? relationToCurrentUser,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      bio: bio ?? this.bio,
      level: level ?? this.level,
      experience: experience ?? this.experience,
      postsCount: postsCount ?? this.postsCount,
      followerIds: followerIds ?? this.followerIds,
      followingIds: followingIds ?? this.followingIds,
      hikeStats: hikeStats ?? this.hikeStats,
      achievements: achievements ?? this.achievements,
      stickers: stickers ?? this.stickers,
      relationToCurrentUser:
          relationToCurrentUser ?? this.relationToCurrentUser,
    );
  }
}

class HikeStats {
  final double totalDistance;
  final int totalHikes;
  final int totalNights;
  final double highestAltitude;

  HikeStats({
    this.totalDistance = 0.0,
    this.totalHikes = 0,
    this.totalNights = 0,
    this.highestAltitude = 0.0,
  });

  factory HikeStats.fromFirestore(Map<String, dynamic> data) {
    return HikeStats(
      totalDistance: (data['totalDistance'] ?? 0.0).toDouble(),
      totalHikes: data['totalHikes'] ?? 0,
      totalNights: data['totalNights'] ?? 0,
      highestAltitude: (data['highestAltitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'totalDistance': totalDistance,
      'totalHikes': totalHikes,
      'totalNights': totalNights,
      'highestAltitude': highestAltitude,
    };
  }

  HikeStats copyWith({
    double? totalDistance,
    int? totalHikes,
    int? totalNights,
    double? highestAltitude,
  }) {
    return HikeStats(
      totalDistance: totalDistance ?? this.totalDistance,
      totalHikes: totalHikes ?? this.totalHikes,
      totalNights: totalNights ?? this.totalNights,
      highestAltitude: highestAltitude ?? this.highestAltitude,
    );
  }
}

class Achievement {
  final String title;
  final String description;
  final IconData? icon;
  final Color? iconColor;
  final DateTime? dateAchieved;

  Achievement({
    required this.title,
    required this.description,
    this.icon,
    this.iconColor,
    this.dateAchieved,
  });

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dateAchieved: map['dateAchieved'] != null
          ? (map['dateAchieved'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dateAchieved':
          dateAchieved != null ? Timestamp.fromDate(dateAchieved!) : null,
    };
  }
}

class Sticker {
  final String name;
  final String imageUrl;

  Sticker({required this.name, required this.imageUrl});

  factory Sticker.fromMap(Map<String, dynamic> map) {
    return Sticker(
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageUrl': imageUrl,
    };
  }
}
