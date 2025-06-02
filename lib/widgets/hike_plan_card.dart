// lib/widgets/hike_plan_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hike_plan_model.dart'; // Varmista, että PrepItemKeys on tässä tai HikePlanModelissa

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
    late DateFormat dateFormatShort; // Esim. 5.8. tai 5.8.25
    late DateFormat dateFormatRange; // Esim. 5.-7.8.2025

    try {
      dateFormatShort = DateFormat('d.M.yy', 'fi_FI');
      dateFormatRange = DateFormat('d.M.yyyy', 'fi_FI');
    } catch (e) {
      dateFormatShort = DateFormat('d.M.yy');
      dateFormatRange = DateFormat('d.M.yyyy');
    }

    String dateDisplay;
    if (plan.endDate != null &&
        plan.endDate!.isAtSameMomentAs(plan.startDate) == false) {
      // Jos päättymispäivä on eri kuin alkamispäivä
      if (plan.endDate!.year == plan.startDate.year &&
          plan.endDate!.month == plan.startDate.month) {
        dateDisplay =
            '${DateFormat('d.', 'fi_FI').format(plan.startDate)} - ${DateFormat('d.M.yyyy', 'fi_FI').format(plan.endDate!)}'; // Esim. 5. - 7.elokuuta 2025
      } else if (plan.endDate!.year == plan.startDate.year) {
        dateDisplay =
            '${DateFormat('d.M.', 'fi_FI').format(plan.startDate)} - ${DateFormat('d.M.yyyy', 'fi_FI').format(plan.endDate!)}'; // Esim. 5.elokuuta - 10.syyskuuta 2025
      } else {
        dateDisplay =
            '${dateFormatRange.format(plan.startDate)} - ${dateFormatRange.format(plan.endDate!)}';
      }
    } else {
      // Yhden päivän vaellus tai vain alkupäivä tiedossa
      dateDisplay = dateFormatRange.format(plan.startDate);
    }

    final HikeStatus displayStatus = plan.status;
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (displayStatus) {
      case HikeStatus.upcoming:
        statusColor = theme.colorScheme.secondary; // Kirkas oranssi/keltainen
        statusIcon = Icons.directions_walk_rounded; // Selkeämpi ikoni tulevalle
        statusLabel = 'Tulossa pian';
        break;
      case HikeStatus.completed:
        statusColor = Colors.green.shade700; // Tummempi vihreä
        statusIcon = Icons.check_circle_outline_rounded;
        statusLabel = 'Suoritettu';
        break;
      case HikeStatus.cancelled:
        statusColor = Colors.red.shade600;
        statusIcon = Icons.cancel_outlined;
        statusLabel = 'Peruttu';
        break;
      case HikeStatus.planned: // MUUTETTU TILA
        statusColor = theme.colorScheme
            .tertiaryContainer; // Käytä teeman väriä, esim. sinertävä
        statusIcon =
            Icons.pending_actions_rounded; // Tai Icons.rule_folder_outlined
        statusLabel = 'Valmistautuminen kesken'; // UUSI TEKSTI
        break;
      default:
        statusColor = Colors.grey.shade500;
        statusIcon = Icons.help_outline_rounded;
        statusLabel = 'Tuntematon';
        break;
    }

    int completedItems = plan.completedPreparationItems;
    int totalItems = plan.totalPreparationItems;
    double progress = totalItems > 0 ? completedItems / totalItems : 0.0;
    bool isPreparationRelevant = displayStatus == HikeStatus.planned ||
        displayStatus == HikeStatus.upcoming;

    return Card(
      elevation: 2.5,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
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
              // Yläosa: Nimi ja Toiminnot-valikko
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      plan.hikeName,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 19, // Selkeä, mutta ei liian suuri
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    SizedBox(
                      width: 40, height: 40, // Riittävä kosketusalue
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.6)),
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
                                SizedBox(width: 10),
                                Text('Muokkaa')
                              ]),
                            ),
                          if (onDelete != null)
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline_rounded,
                                    color: theme.colorScheme.error, size: 20),
                                SizedBox(width: 10),
                                Text('Poista',
                                    style: TextStyle(
                                        color: theme.colorScheme.error))
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
                    )
                  else
                    const SizedBox(
                        width: 40,
                        height: 40), // Placeholder, jotta layout pysyy samana
                ],
              ),
              const SizedBox(height: 8),

              // Info-rivit: Sijainti, Päivämäärä, Pituus
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

              // Status ja Valmistautuminen
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment:
                    CrossAxisAlignment.center, // Tasaa keskelle pystysuunnassa
                children: [
                  _buildStatusBadge(
                      theme, statusColor, statusIcon, statusLabel),
                  if (onUpdatePreparation != null && isPreparationRelevant)
                    TextButton(
                      onPressed: () => onUpdatePreparation!(plan),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        backgroundColor:
                            theme.colorScheme.primary.withOpacity(0.1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$completedItems/$totalItems',
                            style: textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.checklist_rtl_outlined,
                              size: 16, color: theme.colorScheme.primary),
                        ],
                      ),
                    ),
                ],
              ),
              if (isPreparationRelevant && totalItems > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  // Pyöristetyt kulmat progress barille
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: statusColor
                        .withOpacity(0.2), // Käytä statusvärin vaaleampaa sävyä
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
    if (text.isEmpty)
      return const SizedBox.shrink(); // Älä näytä, jos teksti on tyhjä
    return Row(
      children: [
        Icon(icon,
            size: 16, color: color.withOpacity(0.9)), // Hieman himmeämpi ikoni
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontSize: 13.5, // Hieman pienempi selkeyden vuoksi
            ),
            overflow: TextOverflow.ellipsis, // Estää ylivuodon
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(
      ThemeData theme, Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6), // Hieman enemmän paddingia
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8), // Vähemmän pyöreä, modernimpi
        // border: Border.all(color: color.withOpacity(0.5), width: 0.5), // Valinnainen reunaviiva
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color), // Hieman suurempi ikoni
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              // Käytä labelSmall tai bodySmall
              color: color,
              fontWeight: FontWeight.bold, // Selkeä status
              letterSpacing: 0.3, // Hieman välistystä
            ),
          ),
        ],
      ),
    );
  }
}
