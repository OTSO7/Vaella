// lib/models/post_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'daily_route_model.dart'; // Varmista, että tämä on importattu

enum PostVisibility { public, friends, private }

class Post {
  final String id;
  final String userId;
  final String username;
  final String userAvatarUrl;
  final String? postImageUrl;
  final String title;
  final String caption;
  final DateTime timestamp;
  final String location;
  final double? latitude;
  final double? longitude;
  final DateTime startDate;
  final DateTime endDate;
  final double distanceKm;
  final int nights;
  final double? weightKg;
  final PostVisibility visibility;
  final List<String> likes;
  final int commentCount;
  final List<String> sharedData;
  final Map<String, double> ratings;
  // LISÄTTY: Kentät suunnitelman linkkaamiseen ja reitin tallentamiseen
  final String? planId;
  final List<DailyRoute>? dailyRoutes;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.userAvatarUrl,
    this.postImageUrl,
    required this.title,
    required this.caption,
    required this.timestamp,
    required this.location,
    this.latitude,
    this.longitude,
    required this.startDate,
    required this.endDate,
    required this.distanceKm,
    required this.nights,
    this.weightKg,
    this.visibility = PostVisibility.public,
    this.likes = const [],
    this.commentCount = 0,
    this.sharedData = const [],
    required this.ratings,
    this.planId, // LISÄTTY
    this.dailyRoutes, // LISÄTTY
  });

  double get averageRating {
    if (ratings.isEmpty) return 0.0;
    final double total = (ratings['weather'] ?? 0) +
        (ratings['difficulty'] ?? 0) +
        (ratings['experience'] ?? 0);
    return total > 0 ? total / 3.0 : 0.0;
  }

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // LISÄTTY: Reittien lukeminen tietokannasta
    List<DailyRoute>? routesFromDb;
    if (data['dailyRoutes'] != null && data['dailyRoutes'] is List) {
      routesFromDb = (data['dailyRoutes'] as List)
          .map((routeData) =>
              DailyRoute.fromFirestore(routeData as Map<String, dynamic>))
          .toList();
    }

    final ratingsData = data['ratings'] as Map<String, dynamic>?;
    final Map<String, double> ratingsMap = ratingsData != null
        ? ratingsData
            .map((key, value) => MapEntry(key, (value as num).toDouble()))
        : {'weather': 0.0, 'difficulty': 0.0, 'experience': 0.0};

    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      userAvatarUrl: data['userAvatarUrl'] ?? '',
      postImageUrl: data['postImageUrl'],
      title: data['title'] ?? 'Nimetön vaellus',
      caption: data['caption'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      location: data['location'] ?? 'Tuntematon sijainti',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
      nights: data['nights'] as int? ?? 0,
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      visibility: PostVisibility.values.firstWhere(
          (e) => e.toString().split('.').last == data['visibility'],
          orElse: () => PostVisibility.public),
      likes: List<String>.from(data['likes'] ?? []),
      commentCount: data['commentCount'] as int? ?? 0,
      sharedData: List<String>.from(data['sharedData'] ?? []),
      ratings: ratingsMap,
      planId: data['planId'] as String?, // LISÄTTY
      dailyRoutes: routesFromDb, // LISÄTTY
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'postImageUrl': postImageUrl,
      'title': title,
      'caption': caption,
      'timestamp': Timestamp.fromDate(timestamp),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'distanceKm': distanceKm,
      'nights': nights,
      'weightKg': weightKg,
      'visibility': visibility.toString().split('.').last,
      'likes': likes,
      'commentCount': commentCount,
      'sharedData': sharedData,
      'ratings': ratings,
      // LISÄTTY: Reittien kirjoittaminen tietokantaan
      'planId': planId,
      'dailyRoutes': dailyRoutes?.map((route) => route.toFirestore()).toList(),
    };
  }
}
