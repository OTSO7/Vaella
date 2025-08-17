import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/comment_model.dart';
import 'user_avatar.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String currentUserId;
  final String currentUsername;
  final String currentUserAvatarUrl;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentUserAvatarUrl,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;
  String? _fadingCommentId;
  final Set<String> _hiddenComments = {};

  Future<void> _toggleLike(String commentId) async {
    final userId = widget.currentUserId;
    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(commentRef);
      final data = snap.data() ?? {};
      final List likes = List.from(data['likes'] ?? []);
      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }
      transaction.update(commentRef, {
        'likes': likes,
        'likesCount': likes.length,
      });
    });
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);

    final comment = Comment(
      id: '',
      postId: widget.postId,
      userId: widget.currentUserId,
      username: widget.currentUsername,
      userAvatarUrl: widget.currentUserAvatarUrl,
      text: text,
      timestamp: DateTime.now(),
      likes: const [],
      likesCount: 0,
    );

    final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.postId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      final commentCount = (postSnap['commentCount'] ?? 0) as int;
      final commentsRef = postRef.collection('comments').doc();
      transaction.set(commentsRef, comment.toMap());
      transaction.update(postRef, {'commentCount': commentCount + 1});
    });

    _controller.clear();
    setState(() => _isSending = false);
  }

  Future<void> _deleteCommentWithFade(String commentId) async {
    setState(() {
      _fadingCommentId = commentId;
      _hiddenComments.add(commentId);
    });
    await Future.delayed(const Duration(milliseconds: 350));
    await _deleteComment(commentId);
    setState(() {
      _fadingCommentId = null;
    });
  }

  Future<void> _deleteComment(String commentId) async {
    final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      final commentCount = (postSnap['commentCount'] ?? 1) as int;

      transaction.delete(commentRef);
      transaction.update(
          postRef, {'commentCount': (commentCount - 1).clamp(0, 999999)});
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return DateFormat('d MMM').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.dividerColor.withOpacity(0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('timestamp', descending: true) // KORJATTU
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No comments yet. Be the first to comment!",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final comment = Comment.fromFirestore(docs[index]);
                      final isOwn = comment.userId == widget.currentUserId;

                      if (_hiddenComments.contains(comment.id)) {
                        return const SizedBox.shrink();
                      }

                      return AnimatedOpacity(
                        opacity: _fadingCommentId == comment.id ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 350),
                        child: IgnorePointer(
                          ignoring: _fadingCommentId == comment.id,
                          child: _buildCommentItem(comment, isOwn, theme),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _buildCommentInputField(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, bool isOwn, ThemeData theme) {
    final isLiked = comment.likes.contains(widget.currentUserId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            userId: comment.userId,
            radius: 18,
            initialUrl: comment.userAvatarUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.username,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(comment.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      if (isOwn)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 16),
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteCommentWithFade(comment.id);
                              }
                            },
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline,
                                        size: 20, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.9),
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _toggleLike(comment.id),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_outline_rounded,
                          color: isLiked
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        if (comment.likesCount > 0)
                          Text(
                            '${comment.likesCount}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputField(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              maxLines: null, // Allows multiline input
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: "Add a comment...",
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isSending
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(Icons.send_rounded, color: theme.colorScheme.primary),
            onPressed: _isSending ? null : _sendComment,
          ),
        ],
      ),
    );
  }
}
