// lib/widgets/hike_plan_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hike_plan_model.dart';

class HikePlanCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback? onTap;

  const HikePlanCard({
    super.key,
    required this.plan,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final dateFormat = DateFormat('d.M.yyyy', 'fi_FI');
    String dateText = dateFormat.format(plan.startDate);
    if (plan.endDate != null && plan.endDate != plan.startDate) {
      dateText += ' - ${dateFormat.format(plan.endDate!)}';
    }

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (plan.status) {
      case HikeStatus.planned:
        statusColor = Colors.blueGrey.shade400;
        statusIcon = Icons.pending_actions_outlined;
        statusLabel = 'Suunnitteilla';
        break;
      case HikeStatus.upcoming:
        statusColor = theme.colorScheme.secondary;
        statusIcon = Icons.access_time_outlined;
        statusLabel = 'Tulossa';
        break;
      case HikeStatus.completed:
        statusColor = Colors.green.shade600;
        statusIcon = Icons.check_circle_outline;
        statusLabel = 'Suoritettu';
        break;
      case HikeStatus.cancelled:
        statusColor = Colors.red.shade400;
        statusIcon = Icons.cancel_outlined;
        statusLabel = 'Peruttu';
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18.0),
        boxShadow: [
          // TÄSSÄ VARJOJEN HIENOSÄÄTÖ
          BoxShadow(
            color:
                Colors.black.withOpacity(0.15), // Hienovaraisempi läpinäkyvyys
            blurRadius: 10, // Pienempi sumeus
            offset: const Offset(0, 5), // Lyhyempi varjo pystysuunnassa
            spreadRadius: 0, // Ei levitä varjoa ulospäin
          ),
          // Voit lisätä toisen, hienovaraisemman varjon syvyyden lisäämiseksi
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Vielä läpinäkyvämpi
            blurRadius: 4, // Vähemmän sumeutta
            offset: const Offset(0, 2), // Lyhyempi
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.0),
          splashColor: theme.colorScheme.primary.withOpacity(0.1),
          highlightColor: theme.colorScheme.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
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
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(theme, Icons.calendar_today_outlined, dateText),
                const SizedBox(height: 8),
                _buildInfoRow(theme, Icons.location_on_outlined, plan.location),
                if (plan.lengthKm != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(theme, Icons.directions_walk_outlined,
                      '${plan.lengthKm?.toStringAsFixed(1)} km'),
                ],
                if (plan.notes != null && plan.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(color: theme.colorScheme.onSurface.withOpacity(0.1)),
                  const SizedBox(height: 12),
                  Text('Muistiinpanot:',
                      style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withOpacity(0.8))),
                  const SizedBox(height: 6),
                  Text(
                    plan.notes!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                      height: 1.5,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),
                _buildStatusBadge(theme, statusColor, statusIcon, statusLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.9),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(
      ThemeData theme, Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
