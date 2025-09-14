import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart' as local_auth;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _markedOnce = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  String _formatTime(Timestamp? ts) {
    final dt = ts?.toDate();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  Future<void> _markNonActionableAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_markedOnce) return;
    _markedOnce = true;
    final batch = FirebaseFirestore.instance.batch();
    int toUpdate = 0;
    for (final d in docs) {
      final data = d.data();
      final type = data['type'] as String?;
      final status = data['status'] as String?;
      final read = data['read'] == true;
      final actionableInvite = type == 'hike_invite' && (status == null || status == 'pending');
      if (!read && !actionableInvite) {
        batch.update(d.reference, {'read': true});
        toUpdate++;
      }
    }
    if (toUpdate > 0) {
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body:
            const Center(child: Text('Please sign in to view notifications.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _notificationsStream(user.uid),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final hasUnread = docs.any((d) => d.data()['read'] != true);
              return TextButton.icon(
                onPressed: !hasUnread
                    ? null
                    : () async {
                        final batch = FirebaseFirestore.instance.batch();
                        for (final d in docs) {
                          if (d.data()['read'] != true) {
                            batch.update(d.reference, {'read': true});
                          }
                        }
                        await batch.commit();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('All marked as read')),
                          );
                        }
                      },
                icon: Icon(Icons.mark_email_read_outlined,
                    size: 18, color: hasUnread ? cs.primary : cs.onSurfaceVariant),
                label: Text('Mark all',
                    style: GoogleFonts.lato(
                        color: hasUnread ? cs.primary : cs.onSurfaceVariant)),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationsStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];

          // Mark non-actionable items as read once when data first loads
          if (docs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _markNonActionableAsRead(docs);
            });
          }

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_none_rounded,
                          size: 64, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    Text('No notifications yet',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 6),
                    Text('Hike invites and new followers will appear here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lato(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => Divider(
                height: 1, color: cs.outlineVariant.withOpacity(0.15)),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final type = data['type'] as String? ?? 'unknown';
              final isUnread = data['read'] != true;
              final createdAt = data['createdAt'] as Timestamp?;
              final timeString = _formatTime(createdAt);

              Widget tile;
              switch (type) {
                case 'hike_invite':
                  tile = _HikeInviteTile(
                    notifDoc: doc,
                    isUnread: isUnread,
                    timeString: timeString,
                  );
                  break;
                case 'invite_accepted':
                  tile = _DecoratedTile(
                    isUnread: isUnread,
                    leading: const Icon(Icons.task_alt_rounded),
                    title: Text(
                      '${data['fromDisplayName'] ?? 'Someone'} accepted your invite',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Plan: ${data['planName'] ?? ''}\n$timeString',
                      style: GoogleFonts.lato(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                  break;
                case 'invite_declined':
                  tile = _DecoratedTile(
                    isUnread: isUnread,
                    leading: const Icon(Icons.highlight_off_rounded),
                    title: Text(
                      '${data['fromDisplayName'] ?? 'Someone'} declined your invite',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Plan: ${data['planName'] ?? ''}\n$timeString',
                      style: GoogleFonts.lato(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                  break;
                case 'new_follower':
                  tile = _DecoratedTile(
                    isUnread: isUnread,
                    leading: const Icon(Icons.person_add_alt_1_rounded),
                    title: Text(
                      '${data['fromDisplayName'] ?? 'Someone'} started following you',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      (data['fromUsername'] != null
                              ? '@${data['fromUsername']}'
                              : '') +
                          (timeString.isNotEmpty
                              ? (data['fromUsername'] != null ? ' • ' : '') +
                                  timeString
                              : ''),
                      style: GoogleFonts.lato(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      if (data['fromUserId'] != null) {
                        Navigator.of(context)
                            .pushNamed('/profile/${data['fromUserId']}');
                      }
                    },
                  );
                  break;
                default:
                  tile = _DecoratedTile(
                    isUnread: isUnread,
                    leading: const Icon(Icons.notifications_rounded),
                    title: Text('Notification',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      timeString,
                      style: GoogleFonts.lato(),
                    ),
                  );
              }
              return tile;
            },
          );
        },
      ),
    );
  }
}

class _DecoratedTile extends StatelessWidget {
  final bool isUnread;
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback? onTap;
  const _DecoratedTile({
    required this.isUnread,
    required this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: isUnread ? cs.surfaceContainerLowest.withOpacity(0.6) : null,
      child: ListTile(
        onTap: onTap,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: cs.surfaceContainerHighest,
              child: IconTheme(
                data: IconThemeData(color: cs.primary),
                child: leading,
              ),
            ),
            if (isUnread)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orangeAccent.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
              ),
          ],
        ),
        title: title,
        subtitle: subtitle,
      ),
    );
  }
}

class _HikeInviteTile extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> notifDoc;
  final bool isUnread;
  final String timeString;
  const _HikeInviteTile({
    required this.notifDoc,
    required this.isUnread,
    required this.timeString,
  });

  @override
  State<_HikeInviteTile> createState() => _HikeInviteTileState();
}

class _HikeInviteTileState extends State<_HikeInviteTile> {
  bool _working = false;

  Future<void> _acceptInvite(BuildContext context) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final currentProfile =
          context.read<local_auth.AuthProvider>().userProfile;
      final data = widget.notifDoc.data();
      final fromUserId = data['fromUserId'] as String?;
      final planId = data['planId'] as String?;
      final planName = data['planName'] as String?;
      if (fromUserId == null || planId == null) {
        throw Exception('Missing invite data');
      }

      final planSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(fromUserId)
          .collection('plans')
          .doc(planId)
          .get();

      if (!planSnap.exists || planSnap.data() == null) {
        throw Exception('Plan not found');
      }

      final planData = Map<String, dynamic>.from(planSnap.data()!);
      // ensure collaborative flags
      planData['isCollaborative'] = true;
      planData['collabOwnerId'] = fromUserId;
      final List<dynamic> collabs =
          List<dynamic>.from(planData['collaboratorIds'] ?? []);
      if (!collabs.contains(currentUser.uid)) {
        collabs.add(currentUser.uid);
      }
      planData['collaboratorIds'] = collabs.map((e) => e.toString()).toList();

      // copy to current user's plans
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('plans')
          .doc(planId)
          .set(planData, SetOptions(merge: true));

      // mark invite as accepted and read
      await widget.notifDoc.reference
          .update({'status': 'accepted', 'read': true});

      // notify inviter
      await FirebaseFirestore.instance
          .collection('users')
          .doc(fromUserId)
          .collection('notifications')
          .add({
        'type': 'invite_accepted',
        'planId': planId,
        'planName': planName,
        'fromUserId': currentUser.uid,
        'fromDisplayName': currentProfile?.displayName ?? 'A hiker',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Joined "$planName"'),
            backgroundColor: Colors.green.shade700),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept invite: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _declineInvite(BuildContext context) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final data = widget.notifDoc.data();
      final fromUserId = data['fromUserId'] as String?;
      final planId = data['planId'] as String?;
      final planName = data['planName'] as String?;

      await widget.notifDoc.reference
          .update({'status': 'declined', 'read': true});

      // Optionally notify inviter
      if (fromUserId != null) {
        final me = FirebaseAuth.instance.currentUser;
        final profile = context.read<local_auth.AuthProvider>().userProfile;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(fromUserId)
            .collection('notifications')
            .add({
          'type': 'invite_declined',
          'planId': planId,
          'planName': planName,
          'fromUserId': me?.uid,
          'fromDisplayName': profile?.displayName ?? 'A hiker',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite declined')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decline invite: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = widget.notifDoc.data();
    final status = (data['status'] as String?) ?? 'pending';

    return Container(
      color: widget.isUnread ? cs.surfaceContainerLowest.withOpacity(0.6) : null,
      child: ListTile(
        isThreeLine: true,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
                backgroundColor: cs.surfaceContainerHighest,
                child: const Icon(Icons.landscape_rounded)),
            if (widget.isUnread)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orangeAccent.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
              ),
          ],
        ),
        title: Text(
            '${data['fromDisplayName'] ?? 'Someone'} invited you to a hike',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${data['planName'] ?? ''}\n${widget.timeString}',
          style: GoogleFonts.lato(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: status == 'pending'
            ? IntrinsicWidth(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _working ? null : () => _declineInvite(context),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _working ? null : () => _acceptInvite(context),
                      child: _working
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Accept'),
                    ),
                  ],
                ),
              )
            : Text(status.toUpperCase(),
                style: GoogleFonts.lato(
                    fontWeight: FontWeight.w700,
                    color: status == 'accepted'
                        ? Colors.greenAccent
                        : cs.onSurfaceVariant)),
      ),
    );
  }
}
