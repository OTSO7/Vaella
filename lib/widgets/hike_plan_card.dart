// lib/widgets/hike_plan_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hike_plan_model.dart';

class HikePlanCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback? onTap; // Myöhempää käyttöä varten (esim. tietosivulle)
  final VoidCallback? onEdit; // Myöhempää muokkausta varten
  final VoidCallback? onDelete; // Myöhempää poistoa varten

  const HikePlanCard({
    super.key,
    required this.plan,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d.M.yyyy', 'fi_FI');
    String dateText = dateFormat.format(plan.startDate);
    if (plan.endDate != null && plan.endDate != plan.startDate) {
      dateText += ' - ${dateFormat.format(plan.endDate!)}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      plan.hikeName,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Voit lisätä muokkaus/poisto-ikonit tänne myöhemmin PopupMenuButtonilla
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoRow(theme, Icons.calendar_today_outlined, dateText),
              const SizedBox(height: 4),
              _buildInfoRow(theme, Icons.location_on_outlined, plan.location),
              if (plan.lengthKm != null) ...[
                const SizedBox(height: 4),
                _buildInfoRow(theme, Icons.directions_walk_outlined,
                    '${plan.lengthKm} km'),
              ],
              if (plan.notes != null && plan.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Muistiinpanot:',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(plan.notes!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
