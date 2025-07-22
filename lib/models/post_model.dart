// lib/models/post_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String? planId;
  final PostVisibility visibility;
  final List<String> likes;
  final int commentCount;
  final List<String> sharedData;
  final Map<String, double> ratings;

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
    this.planId,
    this.visibility = PostVisibility.public,
    this.likes = const [],
    this.commentCount = 0,
    this.sharedData = const [],
    required this.ratings,
  });

  // LISÄTTY: Getter, joka laskee arvostelujen keskiarvon.
  // Tämä on helppo tapa saada keskiarvo missä tahansa sovelluksessa.
  double get averageRating {
    if (ratings.isEmpty) return 0.0;
    // Varmistetaan, että kaikki avaimet ovat olemassa (fromFirestore hoitaa oletusarvot)
    final double total = (ratings['weather'] ?? 0) +
        (ratings['difficulty'] ?? 0) +
        (ratings['experience'] ?? 0);
    return total / 3.0;
  }

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

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
      nights: (data['nights'] as int?)?.toInt() ?? 0,
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      planId: data['planId'],
      visibility: PostVisibility.values.firstWhere(
          (e) => e.toString().split('.').last == data['visibility'],
          orElse: () => PostVisibility.public),
      likes: List<String>.from(data['likes'] ?? []),
      commentCount: data['commentCount'] as int? ?? 0,
      sharedData: List<String>.from(data['sharedData'] ?? []),
      ratings: ratingsMap,
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
      'planId': planId,
      'visibility': visibility.toString().split('.').last,
      'likes': likes,
      'commentCount': commentCount,
      'sharedData': sharedData,
      'ratings': ratings,
    };
  }
}
