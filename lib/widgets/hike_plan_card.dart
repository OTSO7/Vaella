// lib/widgets/hike_plan_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hike_plan_model.dart'; // Varmista, että PrepItemKeys on tässä tai HikePlanModelissa

class HikePlanCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(HikePlan)?
      onUpdatePreparation; // UUSI: Callback valmistautumisen päivitykseen

  const HikePlanCard({
    super.key,
    required this.plan,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onUpdatePreparation, // UUSI
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    late DateFormat dateFormat;
    try {
      dateFormat =
          DateFormat('d.M.yyyy', 'fi_FI'); // Käytetään suomalaista muotoilua
    } catch (e) {
      dateFormat = DateFormat('d.M.yyyy'); // Fallback
    }

    String dateText = dateFormat.format(plan.startDate);
    if (plan.endDate != null &&
        plan.endDate!.isAtSameMomentAs(plan.startDate) == false) {
      // Varmistetaan, ettei ole sama päivä
      if (plan.endDate!.year == plan.startDate.year &&
          plan.endDate!.month == plan.startDate.month) {
        dateText +=
            ' - ${DateFormat('d', 'fi_FI').format(plan.endDate!)}.${DateFormat('M.yyyy', 'fi_FI').format(plan.endDate!)}'; // Esim. 5. - 7.8.2025
      } else if (plan.endDate!.year == plan.startDate.year) {
        dateText +=
            ' - ${DateFormat('d.M', 'fi_FI').format(plan.endDate!)}.${DateFormat('.yyyy', 'fi_FI').format(plan.endDate!)}'; // Esim. 5.8. - 10.9.2025
      } else {
        dateText +=
            ' - ${dateFormat.format(plan.endDate!)}'; // Esim. 5.8.2025 - 10.1.2026
      }
    }

    // Käytetään modelin laskemaa statusta
    final HikeStatus displayStatus = plan.status;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (displayStatus) {
      case HikeStatus.upcoming:
        statusColor = theme.colorScheme.secondary;
        statusIcon = Icons.access_time_filled_rounded;
        statusLabel = 'Tulossa';
        break;
      case HikeStatus.completed:
        statusColor = Colors.green.shade600;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Tehty';
        break;
      case HikeStatus.cancelled:
        statusColor = Colors.red.shade400;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Peruttu';
        break;
      default: // planned
        statusColor = Colors.blueGrey.shade400;
        statusIcon = Icons.edit_calendar_outlined;
        statusLabel = 'Suunniteltu';
        break;
    }

    int completedItems = plan.completedPreparationItems;
    int totalItems = plan.totalPreparationItems;
    double progress = totalItems > 0 ? completedItems / totalItems : 0;

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: theme.cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        splashColor: theme.colorScheme.primary.withOpacity(0.1),
        highlightColor: theme.colorScheme.primary.withOpacity(0.05),
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
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight:
                            FontWeight.w700, // Hieman kevyempi kuin aiempi w800
                        fontSize: 20, // Hieman pienempi
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    SizedBox(
                      // SizedBox rajoittaa PopupMenuButtonin kokoa
                      width: 36,
                      height: 36,
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.7)),
                        iconSize: 22,
                        tooltip: 'Lisävalinnat',
                        padding: EdgeInsets.zero,
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          if (onEdit != null)
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('Muokkaa')
                              ]),
                            ),
                          if (onDelete != null)
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline_rounded,
                                    color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Poista',
                                    style: TextStyle(color: Colors.red))
                              ]),
                            ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit' && onEdit != null)
                            onEdit!();
                          else if (value == 'delete' && onDelete != null)
                            onDelete!();
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _buildInfoRow(theme, Icons.calendar_today_outlined, dateText,
                  iconColor: theme.colorScheme.primary),
              const SizedBox(height: 6),
              _buildInfoRow(theme, Icons.location_on_outlined, plan.location,
                  iconColor: theme.colorScheme.primary),
              if (plan.lengthKm != null && plan.lengthKm! > 0) ...[
                const SizedBox(height: 6),
                _buildInfoRow(theme, Icons.directions_walk_outlined,
                    '${plan.lengthKm?.toStringAsFixed(1)} km',
                    iconColor: theme.colorScheme.primary),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                      child: _buildStatusBadge(
                          theme, statusColor, statusIcon, statusLabel)),
                  if (onUpdatePreparation != null &&
                      displayStatus != HikeStatus.completed &&
                      displayStatus !=
                          HikeStatus
                              .cancelled) // Näytä vain jos ei valmis/peruttu
                    TextButton.icon(
                      icon: Icon(Icons.checklist_rtl_outlined,
                          size: 18, color: theme.colorScheme.secondary),
                      label: Text(
                        '$completedItems/$totalItems tehty',
                        style: textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => onUpdatePreparation!(plan),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                ],
              ),
              if (displayStatus != HikeStatus.completed &&
                  displayStatus != HikeStatus.cancelled &&
                  totalItems > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor:
                      theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      statusColor.withOpacity(0.8)),
                  minHeight: 6, // Hieman paksumpi
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 4),
                Text(
                  completedItems == totalItems
                      ? "Valmiina lähtöön!"
                      : "Valmistautuminen kesken",
                  style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7)),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String text,
      {Color? iconColor}) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start, // Tasaus ylhäältä, jos teksti rivittyy
      children: [
        Icon(icon,
            size: 18,
            color: iconColor ?? theme.colorScheme.primary.withOpacity(0.8)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.85),
              height: 1.3,
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
        color: color.withOpacity(0.15), // Hieman vahvempi tausta
        borderRadius: BorderRadius.circular(20), // Pyöreät kulmat
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
