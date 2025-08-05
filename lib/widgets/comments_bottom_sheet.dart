import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';

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

  Future<void> _addOrRemoveReaction(
      String commentId, String emoji, bool alreadyReacted) async {
    final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    final userId = widget.currentUserId;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final commentSnap = await transaction.get(commentRef);
      final data = commentSnap.data() as Map<String, dynamic>? ?? {};
      final List<dynamic> reactions = List.from(data['reactions'] ?? []);

      reactions
          .removeWhere((r) => r['userId'] == userId && r['emoji'] == emoji);
      if (!alreadyReacted) {
        reactions.add({'userId': userId, 'emoji': emoji});
      }
      transaction.update(commentRef, {'reactions': reactions});
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
      // Älä poista _hiddenCommentsista, Firestore-stream hoitaa sen
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

  List<Map<String, dynamic>> _groupReactions(List reactions) {
    final Map<String, int> counts = {};
    for (final r in reactions) {
      final emoji = r['emoji'] ?? '';
      if (emoji.isEmpty) continue;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => {'emoji': e.key, 'count': e.value})
        .toList();
  }

  bool _userReacted(List reactions, String emoji) {
    return reactions
        .any((r) => r['userId'] == widget.currentUserId && r['emoji'] == emoji);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.13),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
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
                    .orderBy('timestamp', descending: true)
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
                    reverse: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final comment = Comment.fromFirestore(docs[index]);
                      final isOwn = comment.userId == widget.currentUserId;

                      // Piilota fade-outissa oleva kommentti
                      if (_hiddenComments.contains(comment.id)) {
                        return const SizedBox.shrink();
                      }

                      final reactions = comment.reactions;
                      final grouped = _groupReactions(reactions);

                      return AnimatedOpacity(
                        opacity: _fadingCommentId == comment.id ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 350),
                        child: IgnorePointer(
                          ignoring: _fadingCommentId == comment.id,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPressStart: (details) async {
                              final RenderBox overlay = Overlay.of(context)
                                  .context
                                  .findRenderObject() as RenderBox;
                              final Offset tapPosition = details.globalPosition;

                              if (isOwn) {
                                final selected = await showMenu<String>(
                                  context: context,
                                  position: RelativeRect.fromRect(
                                    tapPosition & const Size(40, 40),
                                    Offset.zero & overlay.size,
                                  ),
                                  items: [
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete,
                                              color: theme.colorScheme.error),
                                          const SizedBox(width: 8),
                                          const Text('Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                                if (selected == 'delete') {
                                  await _deleteCommentWithFade(comment.id);
                                }
                              } else {
                                final selected = await showMenu<String>(
                                  context: context,
                                  position: RelativeRect.fromRect(
                                    tapPosition & const Size(40, 40),
                                    Offset.zero & overlay.size,
                                  ),
                                  items: [
                                    PopupMenuItem<String>(
                                      enabled: false,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          for (final emoji in [
                                            '❤️',
                                            '👍',
                                            '🙏',
                                            '😎',
                                          ])
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.pop(context, emoji);
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 3),
                                                child: Text(emoji,
                                                    style: const TextStyle(
                                                        fontSize: 22)),
                                              ),
                                            ),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(
                                                Icons
                                                    .report_gmailerrorred_rounded,
                                                color: Colors.red),
                                            tooltip: "Report",
                                            onPressed: () {
                                              Navigator.pop(context, 'report');
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                                if (selected != null && selected != 'report') {
                                  await _addOrRemoveReaction(
                                    comment.id,
                                    selected,
                                    _userReacted(reactions, selected),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text("Reacted with $selected")),
                                  );
                                } else if (selected == 'report') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Report feature coming soon!")),
                                  );
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundImage:
                                            comment.userAvatarUrl.isNotEmpty
                                                ? NetworkImage(
                                                    comment.userAvatarUrl)
                                                : null,
                                        child: comment.userAvatarUrl.isEmpty
                                            ? Icon(Icons.person,
                                                color:
                                                    theme.colorScheme.primary)
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment.username,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              comment.text,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        TimeOfDay.fromDateTime(
                                                comment.timestamp)
                                            .format(context),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (grouped.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 8,
                                          left: 44,
                                          right: 8,
                                          bottom: 2),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          for (final entry in grouped)
                                            _ReactionChip(
                                              emoji: entry['emoji'],
                                              count: entry['count'],
                                              highlighted: _userReacted(
                                                  reactions, entry['emoji']),
                                              onTap: () async {
                                                final alreadyReacted =
                                                    _userReacted(reactions,
                                                        entry['emoji']);
                                                await _addOrRemoveReaction(
                                                    comment.id,
                                                    entry['emoji'],
                                                    alreadyReacted);
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.dividerColor.withOpacity(0.18),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : Icon(Icons.send, color: theme.colorScheme.primary),
                    onPressed: _isSending ? null : _sendComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool highlighted;
  final VoidCallback? onTap;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        margin: const EdgeInsets.only(right: 3),
        decoration: BoxDecoration(
          color: highlighted
              ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
              : Theme.of(context).colorScheme.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(11),
          border: highlighted
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 2),
            Text('$count', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
