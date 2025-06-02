import 'package:cloud_firestore/cloud_firestore.dart';

enum PostVisibility {
  public,
  friends,
  private,
}

class Post {
  final String id;
  final String userId; // Postauksen tekijän UID
  final String username;
  final String userAvatarUrl;
  final String? postImageUrl;
  final String title; // UUSI: Postauksen otsikko
  final String caption;
  final DateTime timestamp;
  final String location;
  final DateTime startDate; // UUSI: Vaelluksen aloituspäivä
  final DateTime endDate; // UUSI: Vaelluksen päättymispäivä
  final double distanceKm; // UUSI: Vaelluksen pituus
  final int nights; // UUSI: Vaelluksen yöt
  final double? weightKg; // UUSI: Repun paino, valinnainen
  final double? caloriesPerDay; // UUSI: Kalorit/päivä, valinnainen
  final String? planId; // UUSI: Viittaus alkuperäiseen suunnitelmaan
  final PostVisibility visibility; // UUSI: Näkyvyysasetus
  final List<String> likes; // UUSI: Tykkääjien UID:t
  final int commentCount; // UUSI: Kommenttien määrä (denormalisoitu)
  final List<String> sharedData; // UUSI: Mitä suunnitelman tietoja jaetaan

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
    required this.startDate,
    required this.endDate,
    required this.distanceKm,
    required this.nights,
    this.weightKg,
    this.caloriesPerDay,
    this.planId,
    this.visibility = PostVisibility.public, // Oletus julkinen
    this.likes = const [],
    this.commentCount = 0,
    this.sharedData = const [],
  });

  // Muunna Firestore-dokumentista Post-olioksi
  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      userAvatarUrl: data['userAvatarUrl'] ??
          'https://i.pravatar.cc/150?img=0', // Oletuskuva
      postImageUrl: data['postImageUrl'],
      title: data['title'] ?? 'Nimetön vaellus',
      caption: data['caption'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      location: data['location'] ?? 'Tuntematon sijainti',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
      nights: (data['nights'] as int?)?.toInt() ?? 0, // Varmista int-tyyppi
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      caloriesPerDay: (data['caloriesPerDay'] as num?)?.toDouble(),
      planId: data['planId'],
      visibility: PostVisibility.values.firstWhere(
          (e) => e.toString().split('.').last == data['visibility'],
          orElse: () => PostVisibility.public),
      likes: List<String>.from(data['likes'] ?? []),
      commentCount:
          (data['commentCount'] as int?)?.toInt() ?? 0, // Varmista int-tyyppi
      sharedData: List<String>.from(data['sharedData'] ?? []),
    );
  }

  // Muunna Post-oliosta Firestore-dokumentiksi
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
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'distanceKm': distanceKm,
      'nights': nights,
      'weightKg': weightKg,
      'caloriesPerDay': caloriesPerDay,
      'planId': planId,
      'visibility': visibility.toString().split('.').last, // Tallenna stringinä
      'likes': likes,
      'commentCount': commentCount,
      'sharedData': sharedData,
    };
  }
}
