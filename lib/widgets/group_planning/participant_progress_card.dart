// lib/widgets/group_planning/participant_progress_card.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/hike_plan_model.dart';
import '../../models/user_profile_model.dart' as user_model;
import '../../providers/auth_provider.dart';

class ParticipantProgressCard extends StatelessWidget {
  final String participantId;
  final HikePlan plan;
  final VoidCallback? onTap;
  final bool showDetailedProgress;

  const ParticipantProgressCard({
    super.key,
    required this.participantId,
    required this.plan,
    this.onTap,
    this.showDetailedProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId = context.read<AuthProvider>().userProfile?.uid;
    final isCurrentUser = participantId == currentUserId;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(participantId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return _buildLoadingCard(cs);
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final userProfile = userData != null
            ? user_model.UserProfile.fromFirestore(userSnapshot.data!)
            : null;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(participantId)
              .collection('plans')
              .doc(plan.id)
              .snapshots(),
          builder: (context, planSnapshot) {
            if (!planSnapshot.hasData) {
              return _buildLoadingCard(cs);
            }

            final planData = planSnapshot.data?.data() as Map<String, dynamic>?;

            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.surfaceContainer,
                        cs.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrentUser
                          ? cs.primary.withOpacity(0.3)
                          : cs.outline.withOpacity(0.1),
                      width: isCurrentUser ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User header
                      _buildUserHeader(cs, userProfile, isCurrentUser),

                      if (showDetailedProgress) ...[
                        const SizedBox(height: 16),
                        _buildDetailedProgress(cs, planData),
                      ] else ...[
                        const SizedBox(height: 12),
                        _buildQuickProgress(cs, planData),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserHeader(
      ColorScheme cs, user_model.UserProfile? userProfile, bool isCurrentUser) {
    return Row(
      children: [
        // Avatar with level badge
        Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isCurrentUser ? cs.primary : cs.outline.withOpacity(0.3),
                  width: isCurrentUser ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundImage: userProfile?.photoURL != null
                    ? NetworkImage(userProfile!.photoURL!)
                    : null,
                backgroundColor: cs.surfaceContainerHighest,
                child: userProfile?.photoURL == null
                    ? Icon(
                        Icons.person_rounded,
                        size: 24,
                        color: cs.onSurfaceVariant,
                      )
                    : null,
              ),
            ),

            // Level badge
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.surface, width: 1.5),
                ),
                child: Text(
                  'L${userProfile?.level ?? 1}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 8,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(width: 12),

        // User info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      userProfile?.displayName ?? 'Hiker',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCurrentUser) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'You',
                        style: GoogleFonts.lato(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              if (userProfile?.username != null)
                Text(
                  '@${userProfile!.username}',
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickProgress(ColorScheme cs, Map<String, dynamic>? planData) {
    final preparationItems =
        planData?['preparationItems'] as Map<String, dynamic>? ?? {};
    final completedItems =
        preparationItems.values.where((v) => v == true).length;
    final progress = completedItems / 4; // 4 total preparation items

    final packingList = (planData?['packingList'] as List<dynamic>? ?? []);
    final packedItems =
        packingList.where((item) => item['isPacked'] == true).length;
    final packingProgress =
        packingList.isNotEmpty ? packedItems / packingList.length : 0.0;

    return Column(
      children: [
        // Overall progress bar
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (progress + packingProgress) / 2,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(((progress + packingProgress) / 2) * 100).round()}%',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: cs.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Quick stats
        Row(
          children: [
            _buildQuickStat(
                cs, 'Prep', '$completedItems/4', Icons.checklist_rounded),
            const SizedBox(width: 12),
            _buildQuickStat(cs, 'Pack', '$packedItems/${packingList.length}',
                Icons.backpack_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailedProgress(
      ColorScheme cs, Map<String, dynamic>? planData) {
    final preparationItems =
        planData?['preparationItems'] as Map<String, dynamic>? ?? {};
    final completedItems =
        preparationItems.values.where((v) => v == true).length;
    final prepProgress = completedItems / 4;

    final packingList = (planData?['packingList'] as List<dynamic>? ?? []);
    final packedItems =
        packingList.where((item) => item['isPacked'] == true).length;
    final packingProgress =
        packingList.isNotEmpty ? packedItems / packingList.length : 0.0;

    final foodProgress =
        _calculateFoodProgress(planData?['foodPlanJson'] as String?, planData);

    return Column(
      children: [
        // Preparation progress
        _buildProgressSection(
          cs,
          'Preparation',
          prepProgress,
          '$completedItems/4 completed',
          Icons.checklist_rounded,
          Colors.blue,
        ),

        const SizedBox(height: 12),

        // Packing progress
        _buildProgressSection(
          cs,
          'Packing',
          packingProgress,
          packingList.isNotEmpty
              ? '$packedItems/${packingList.length} packed'
              : 'No items',
          Icons.backpack_rounded,
          Colors.orange,
        ),

        const SizedBox(height: 12),

        // Food planning progress
        _buildProgressSection(
          cs,
          'Food Plan',
          foodProgress['progress'],
          '${foodProgress['days']} days planned',
          Icons.restaurant_menu_rounded,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildProgressSection(
    ColorScheme cs,
    String title,
    double progress,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: cs.surfaceContainerHighest.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.lato(
              fontSize: 10,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
      ColorScheme cs, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: GoogleFonts.lato(
              fontSize: 10,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(ColorScheme cs) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withOpacity(0.1),
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.primary,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateFoodProgress(
      String? foodPlanJson, Map<String, dynamic>? planData) {
    if (foodPlanJson == null || foodPlanJson.isEmpty) {
      return {'progress': 0.0, 'days': 0};
    }

    try {
      final startDate = (planData?['startDate'] as Timestamp?)?.toDate();
      final endDate = (planData?['endDate'] as Timestamp?)?.toDate();

      if (startDate == null) {
        return {'progress': 0.0, 'days': 0};
      }

      final totalDays =
          endDate != null ? endDate.difference(startDate).inDays + 1 : 1;

      final List<dynamic> decoded = json.decode(foodPlanJson);
      int plannedDays = 0;

      for (final dayData in decoded) {
        final sections = dayData['sections'] as List<dynamic>? ?? [];
        bool dayHasItems = false;

        for (final sectionData in sections) {
          final items = sectionData['items'] as List<dynamic>? ?? [];
          if (items.isNotEmpty) {
            dayHasItems = true;
            break;
          }
        }

        if (dayHasItems) plannedDays++;
      }

      return {
        'progress': totalDays > 0 ? (plannedDays / totalDays) : 0.0,
        'days': plannedDays,
      };
    } catch (e) {
      return {'progress': 0.0, 'days': 0};
    }
  }
}
