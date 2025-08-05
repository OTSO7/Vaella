import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String userAvatarUrl;
  final String text;
  final DateTime timestamp;
  final List<Map<String, dynamic>> reactions; // <-- uusi kenttä

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.userAvatarUrl,
    required this.text,
    required this.timestamp,
    this.reactions = const [],
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      postId: data['postId'],
      userId: data['userId'],
      username: data['username'],
      userAvatarUrl: data['userAvatarUrl'] ?? '',
      text: data['text'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      reactions: (data['reactions'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'reactions': reactions,
    };
  }
}
