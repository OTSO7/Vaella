// lib/widgets/group_planning/group_planning_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../models/hike_plan_model.dart';
import '../../providers/auth_provider.dart';
import 'collaborator_card.dart';

class GroupPlanningSection extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback onInvite;

  const GroupPlanningSection({
    super.key,
    required this.plan,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = context.watch<AuthProvider>().userProfile;

    // Get all participant IDs: owner + collaborators
    final participantIds = <String>{
      if (plan.collabOwnerId != null && plan.collabOwnerId!.isNotEmpty)
        plan.collabOwnerId!,
      ...plan.collaboratorIds,
      if (me != null && me.uid.isNotEmpty) me.uid,
    }.toList();

    if (participantIds.isEmpty || participantIds.length == 1) {
      return _buildEmptyState(context, cs);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId,
              whereIn: participantIds.take(10).toList())
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingState(cs);
        }

        final participants = <Map<String, dynamic>>[];
        final docs = snapshot.data!.docs;

        for (final doc in docs) {
          final data = doc.data();
          participants.add({
            'uid': doc.id,
            'name': (data['displayName'] as String?) ?? 'Hiker',
            'username': (data['username'] as String?) ?? '',
            'avatarUrl': data['photoURL'] as String?,
            'level': data['level'] ?? 1,
          });
        }

        // Ensure current user is included and prioritized
        if (participants.every((p) => p['uid'] != me?.uid) && me != null) {
          participants.insert(0, {
            'uid': me.uid,
            'name': me.displayName,
            'username': me.username,
            'avatarUrl': me.photoURL,
            'level': me.level,
          });
        }

        // Sort so current user is first
        participants.sort((a, b) {
          if (a['uid'] == me?.uid) return -1;
          if (b['uid'] == me?.uid) return 1;
          return (a['name'] as String).compareTo(b['name'] as String);
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            _buildSectionHeader(context, cs, participants.length),

            const SizedBox(height: 20),

            // Individual collaborator cards
            _buildCollaboratorCards(context, participants, me?.uid),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, ColorScheme cs, int count) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.groups_2_rounded,
            color: cs.onPrimaryContainer,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Group Planning',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              Text(
                '$count ${count == 1 ? 'person' : 'people'} collaborating',
                style: GoogleFonts.lato(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onInvite,
          tooltip: 'Invite more people',
          icon: Icon(
            Icons.person_add_alt_1_rounded,
            color: cs.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildCollaboratorCards(
    BuildContext context,
    List<Map<String, dynamic>> participants,
    String? currentUserId,
  ) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final participant = participants[index];
          final isCurrentUser = participant['uid'] == currentUserId;

          return CollaboratorCard(
            userId: participant['uid'],
            userName: participant['name'],
            userAvatarUrl: participant['avatarUrl'],
            plan: plan,
            isCurrentUser: isCurrentUser,
            onTap: () => _showCollaboratorDetail(context, participant),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_add_rounded,
              size: 40,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start Collaborating',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite friends to plan this hike together.\nShare packing lists, food plans, and more.',
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onInvite,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Invite Friends'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme cs) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _showCollaboratorDetail(
      BuildContext context, Map<String, dynamic> participant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Collaborator detail content
              Expanded(
                child: _buildCollaboratorDetail(context, participant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollaboratorDetail(
      BuildContext context, Map<String, dynamic> participant) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          // User info header
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: participant['avatarUrl'] != null
                    ? NetworkImage(participant['avatarUrl'])
                    : null,
                child: participant['avatarUrl'] == null
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant['name'],
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      '@${participant['username']}',
                      style: GoogleFonts.lato(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Level ${participant['level']}',
                      style: GoogleFonts.lato(
                        color: cs.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Detailed stats and progress would go here
          Text(
            'Detailed progress view coming soon',
            style: GoogleFonts.lato(
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
