// lib/widgets/review_hike_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hike_plan_model.dart';
import 'package:intl/intl.dart';

class ReviewHikeCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback onComplete;

  const ReviewHikeCard(
      {super.key, required this.plan, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.secondary, width: 2),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Awaiting Review',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              plan.hikeName,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              // Varmistetaan, että endDate ei ole null
              plan.endDate != null
                  ? 'Ended on ${DateFormat.yMMMd().format(plan.endDate!)}'
                  : 'End date not set',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Review & Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
