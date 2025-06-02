import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hike_plan_model.dart';

class HikePlanCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(HikePlan)? onUpdatePreparation;

  const HikePlanCard({
    super.key,
    required this.plan,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onUpdatePreparation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    late DateFormat dateFormatShort;
    late DateFormat dateFormatRange;

    try {
      dateFormatShort = DateFormat('d.M.yy', 'en_US');
      dateFormatRange = DateFormat('d.M.yyyy', 'en_US');
    } catch (e) {
      dateFormatShort = DateFormat('d.M.yy');
      dateFormatRange = DateFormat('d.M.yyyy');
    }

    String dateDisplay;
    if (plan.endDate != null &&
        plan.endDate!.isAtSameMomentAs(plan.startDate) == false) {
      if (plan.endDate!.year == plan.startDate.year &&
          plan.endDate!.month == plan.startDate.month) {
        dateDisplay =
            '${DateFormat('d.', 'en_US').format(plan.startDate)} - ${DateFormat('d.M.yyyy', 'en_US').format(plan.endDate!)}';
      } else if (plan.endDate!.year == plan.startDate.year) {
        dateDisplay =
            '${DateFormat('d.M.', 'en_US').format(plan.startDate)} - ${DateFormat('d.M.yyyy', 'en_US').format(plan.endDate!)}';
      } else {
        dateDisplay =
            '${dateFormatRange.format(plan.startDate)} - ${dateFormatRange.format(plan.endDate!)}';
      }
    } else {
      dateDisplay = dateFormatRange.format(plan.startDate);
    }

    final HikeStatus displayStatus = plan.status;
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    int completedItems = plan.completedPreparationItems;
    int totalItems = plan.totalPreparationItems;
    bool allPreparationsDone = (totalItems > 0 && completedItems == totalItems);

    switch (displayStatus) {
      case HikeStatus.upcoming:
        statusColor = theme.colorScheme.secondary;
        statusIcon = Icons.directions_walk_rounded;
        statusLabel = 'Upcoming';
        break;
      case HikeStatus.completed:
        statusColor = theme.colorScheme.primary;
        statusIcon = Icons.check_circle_outline_rounded;
        statusLabel = 'Completed';
        break;
      case HikeStatus.cancelled:
        statusColor = Colors.red.shade600;
        statusIcon = Icons.cancel_outlined;
        statusLabel = 'Cancelled';
        break;
      case HikeStatus.planned:
        if (allPreparationsDone) {
          statusColor = theme.colorScheme.primary;
          statusIcon = Icons.task_alt_rounded;
          statusLabel = 'Ready to go!';
        } else {
          if (theme.brightness == Brightness.dark) {
            statusColor = theme.colorScheme.onSurface.withOpacity(0.5);
          } else {
            statusColor = Colors.blueGrey.shade300;
          }
          statusIcon = Icons.pending_actions_rounded;
          statusLabel = 'Preparation in progress';
        }
        break;
      default:
        statusColor = Colors.grey.shade500;
        statusIcon = Icons.help_outline_rounded;
        statusLabel = 'Unknown';
        break;
    }

    double progress = totalItems > 0 ? completedItems / totalItems : 0.0;
    bool isPreparationRelevant = displayStatus == HikeStatus.planned ||
        displayStatus == HikeStatus.upcoming;

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: theme.cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        splashColor: theme.colorScheme.primary.withOpacity(0.08),
        highlightColor: theme.colorScheme.primary.withOpacity(0.04),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.7)),
                        iconSize: 22,
                        tooltip: null,
                        padding: EdgeInsets.zero,
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          if (onEdit != null)
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined, size: 20),
                                SizedBox(width: 10),
                                Text('Edit')
                              ]),
                            ),
                          if (onDelete != null)
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline_rounded,
                                    color: Colors.red, size: 20),
                                SizedBox(width: 10),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red))
                              ]),
                            ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit' && onEdit != null) {
                            onEdit!();
                          } else if (value == 'delete' && onDelete != null) {
                            onDelete!();
                          }
                        },
                      ),
                    )
                  else
                    const SizedBox(width: 40, height: 40),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoRowCompact(
                  theme, Icons.location_on_outlined, plan.location,
                  color: theme.colorScheme.secondary),
              const SizedBox(height: 5),
              _buildInfoRowCompact(
                  theme, Icons.calendar_today_outlined, dateDisplay,
                  color: theme.colorScheme.secondary),
              if (plan.lengthKm != null && plan.lengthKm! > 0) ...[
                const SizedBox(height: 5),
                _buildInfoRowCompact(theme, Icons.directions_walk_outlined,
                    '${plan.lengthKm?.toStringAsFixed(1)} km',
                    color: theme.colorScheme.secondary),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                      child: _buildStatusBadge(
                          theme, statusColor, statusIcon, statusLabel)),
                  if (onUpdatePreparation != null && isPreparationRelevant)
                    TextButton.icon(
                      icon: Icon(
                        allPreparationsDone
                            ? Icons.fact_check_outlined
                            : Icons.checklist_rtl_outlined,
                        size: 18,
                        color: allPreparationsDone
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                      ),
                      label: Text(
                        allPreparationsDone
                            ? 'Check'
                            : '$completedItems/$totalItems done',
                        style: textTheme.labelMedium?.copyWith(
                            color: allPreparationsDone
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary,
                            fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => onUpdatePreparation!(plan),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        backgroundColor: (allPreparationsDone
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary)
                            .withOpacity(0.1),
                      ),
                    )
                ],
              ),
              if (isPreparationRelevant && totalItems > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: statusColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 7,
                  ),
                ),
                const SizedBox(height: 6),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRowCompact(ThemeData theme, IconData icon, String text,
      {required Color color}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.9)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontSize: 13.5,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(
      ThemeData theme, Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
