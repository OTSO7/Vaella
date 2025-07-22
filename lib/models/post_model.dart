import 'package:cloud_firestore/cloud_firestore.dart';

enum PostVisibility {
  public,
  friends,
  private,
}

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
  // UUTTA: Tarkat koordinaatit karttaa varten
  final double? latitude;
  final double? longitude;
  final DateTime startDate;
  final DateTime endDate;
  final double distanceKm;
  final int nights;
  final double? weightKg;
  final double? caloriesPerDay;
  final String? planId;
  final PostVisibility visibility;
  final List<String> likes;
  final int commentCount;
  final List<String> sharedData;

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
    this.latitude, // UUSI
    this.longitude, // UUSI
    required this.startDate,
    required this.endDate,
    required this.distanceKm,
    required this.nights,
    this.weightKg,
    this.caloriesPerDay,
    this.planId,
    this.visibility = PostVisibility.public,
    this.likes = const [],
    this.commentCount = 0,
    this.sharedData = const [],
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      userAvatarUrl: data['userAvatarUrl'] ?? 'https://i.pravatar.cc/150?img=0',
      postImageUrl: data['postImageUrl'],
      title: data['title'] ?? 'Nimetön vaellus',
      caption: data['caption'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      location: data['location'] ?? 'Tuntematon sijainti',
      // UUTTA: Lue koordinaatit Firebasesta
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
      nights: (data['nights'] as int?)?.toInt() ?? 0,
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      caloriesPerDay: (data['caloriesPerDay'] as num?)?.toDouble(),
      planId: data['planId'],
      visibility: PostVisibility.values.firstWhere(
          (e) => e.toString().split('.').last == data['visibility'],
          orElse: () => PostVisibility.public),
      likes: List<String>.from(data['likes'] ?? []),
      commentCount: (data['commentCount'] as int?)?.toInt() ?? 0,
      sharedData: List<String>.from(data['sharedData'] ?? []),
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
      // UUTTA: Tallenna koordinaatit Firebaseen
      'latitude': latitude,
      'longitude': longitude,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'distanceKm': distanceKm,
      'nights': nights,
      'weightKg': weightKg,
      'caloriesPerDay': caloriesPerDay,
      'planId': planId,
      'visibility': visibility.toString().split('.').last,
      'likes': likes,
      'commentCount': commentCount,
      'sharedData': sharedData,
    };
  }
}
