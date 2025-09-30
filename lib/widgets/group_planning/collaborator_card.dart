// lib/widgets/group_planning/collaborator_card.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/hike_plan_model.dart';
import '../../models/user_profile_model.dart';
import '../../widgets/user_avatar.dart';

class CollaboratorCard extends StatelessWidget {
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final HikePlan plan;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  const CollaboratorCard({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.plan,
    this.isCurrentUser = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, userSnapshot) {
        // Get user's personal packing list and food plan from their profile
        final userData = userSnapshot.data?.data();
        final userProfile = userData != null
            ? UserProfile.fromFirestore(userSnapshot.data!)
            : null;

        return Container(
          width: 280,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCurrentUser
                  ? cs.primary.withOpacity(0.5)
                  : cs.outlineVariant.withOpacity(0.3),
              width: isCurrentUser ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User header
                    Row(
                      children: [
                        UserAvatar(
                          userId: userId,
                          radius: 20,
                          initialUrl: userAvatarUrl,
                          borderColor: isCurrentUser ? cs.primary : null,
                          borderWidth: isCurrentUser ? 2 : 0,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      userName.split(' ').first,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Host badge (takes priority over "You" badge)
                                  if (userId == plan.collabOwnerId) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade600,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Host',
                                            style: GoogleFonts.lato(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (isCurrentUser) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'You',
                                        style: GoogleFonts.lato(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                userProfile?.username != null
                                    ? '@${userProfile!.username}'
                                    : 'Hiker',
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Packing progress
                    _buildPackingSection(cs),

                    const SizedBox(height: 10), // Food planning progress
                    _buildFoodSection(cs),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPackingSection(ColorScheme cs) {
    final packedCount = plan.packingList.where((item) => item.isPacked).length;
    final totalCount = plan.packingList.length;
    final progress = totalCount > 0 ? packedCount / totalCount : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.backpack_outlined,
                size: 16,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Packing List',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (totalCount > 0) ...[
          // Progress bar
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$packedCount of $totalCount items packed',
            style: GoogleFonts.lato(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
        ] else
          Text(
            'No items added yet',
            style: GoogleFonts.lato(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildFoodSection(ColorScheme cs) {
    final foodData = _calculateFoodTotals();
    final days = plan.endDate != null
        ? plan.endDate!.difference(plan.startDate).inDays + 1
        : 1;
    final plannedDays = foodData['days']!.toInt();
    final progress = days > 0 ? (plannedDays / days) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 16,
                color: Colors.deepOrange.shade600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Food Plan',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (plannedDays > 0) ...[
          // Progress bar
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.transparent,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.deepOrange.shade600),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$plannedDays of $days days planned',
            style: GoogleFonts.lato(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
        ] else
          Text(
            'No meals planned yet',
            style: GoogleFonts.lato(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Map<String, double> _calculateFoodTotals() {
    if (plan.foodPlanJson == null || plan.foodPlanJson!.isEmpty) {
      return {'calories': 0, 'items': 0, 'days': 0};
    }

    try {
      final List<dynamic> decoded = json.decode(plan.foodPlanJson!);
      double totalCalories = 0;
      int totalItems = 0;
      int daysWithFood = 0;

      for (final dayData in decoded) {
        final sections = dayData['sections'] as List<dynamic>? ?? [];
        bool dayHasItems = false;

        for (final sectionData in sections) {
          final items = sectionData['items'] as List<dynamic>? ?? [];
          if (items.isNotEmpty) {
            dayHasItems = true;
            totalItems += items.length;

            for (final item in items) {
              totalCalories += (item['calories'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }

        if (dayHasItems) daysWithFood++;
      }

      return {
        'calories': totalCalories,
        'items': totalItems.toDouble(),
        'days': daysWithFood.toDouble(),
      };
    } catch (e) {
      return {'calories': 0, 'items': 0, 'days': 0};
    }
  }
}
