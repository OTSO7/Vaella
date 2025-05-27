// lib/models/post_model.dart
class Post {
  final String id;
  final String username;
  final String userAvatarUrl;
  final String? postImageUrl; // Voi olla null, jos postauksessa ei ole kuvaa
  final String caption;
  final DateTime timestamp;
  final int likes;
  final int comments;
  final String location; // Esim. "Teijon kansallispuisto"

  Post({
    required this.id,
    required this.username,
    required this.userAvatarUrl,
    this.postImageUrl,
    required this.caption,
    required this.timestamp,
    required this.likes,
    required this.comments,
    required this.location,
  });
}
