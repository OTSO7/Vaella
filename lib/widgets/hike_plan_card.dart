import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; // Lisätty Google Fonts
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
  Widget build(BuildContext context) {    final theme = Theme.of(context);
    final titleTextStyle = GoogleFonts.poppins(
      fontWeight: FontWeight.w700,
      fontSize: 19,
      color: theme.colorScheme.onSurface,
    );
    final infoRowTextStyle = GoogleFonts.lato(
      color: theme.colorScheme.onSurface.withOpacity(0.85),
      fontSize: 14, // Hieman isompi fontti luettavuuden parantamiseksi
    );
    final statusLabelStyle = GoogleFonts.lato(
      // Käytetään Latóa myös status-labelille
      fontWeight: FontWeight.bold,
      letterSpacing: 0.3,
    );

    late DateFormat dateFormatShort;
    late DateFormat dateFormatRange;
    String locale = 'en_US'; // Oletuslokaali

    try {
      // Yritä käyttää laitteen oletuslokaalia, jos intl on alustettu oikein
      // tai käytä määritettyä oletuslokaalia kuten 'fi_FI' tai 'en_US'
      locale = Localizations.localeOf(context).toLanguageTag();
    } catch (e) {
      // Jos localea ei saada, käytetään oletus 'en_US'
      // print('Could not get locale, defaulting to en_US: $e');
    }

    // Alusta DateFormat lokaalin kanssa
    // Varmistetaan, että lokaali on tuettu tai käytetään fallbackia
    try {
      dateFormatShort = DateFormat('d.M.yy', locale);
      dateFormatRange = DateFormat('d.M.yyyy', locale);
    } catch (e) {
      // Fallback, jos lokaalia ei tueta DateFormatissa
      // print('Locale $locale not supported by DateFormat, falling back to default: $e');
      dateFormatShort =
          DateFormat('d.M.yy'); // Ilman lokaalia, käyttää järjestelmän oletusta
      dateFormatRange = DateFormat('d.M.yyyy');
    }

    String dateDisplay;
    if (plan.endDate != null &&
        plan.endDate!.isAtSameMomentAs(plan.startDate) == false) {
      if (plan.endDate!.year == plan.startDate.year &&
          plan.endDate!.month == plan.startDate.month) {
        // Sama kuukausi ja vuosi: "5. - 10. Kesäkuuta 2024" -> "5. - 10.6.2024"
        dateDisplay =
            '${DateFormat('d.', locale).format(plan.startDate)} - ${DateFormat('d.M.yyyy', locale).format(plan.endDate!)}';
      } else if (plan.endDate!.year == plan.startDate.year) {
        // Sama vuosi, eri kuukausi: "5. Tammikuuta - 10. Helmikuuta 2024" -> "5.1. - 10.2.2024"
        dateDisplay =
            '${DateFormat('d.M.', locale).format(plan.startDate)} - ${DateFormat('d.M.yyyy', locale).format(plan.endDate!)}';
      } else {
        // Eri vuodet: "5.12.2023 - 10.1.2024"
        dateDisplay =
            '${dateFormatRange.format(plan.startDate)} - ${dateFormatRange.format(plan.endDate!)}';
      }
    } else {
      // Yhden päivän tapahtuma
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
        statusColor = theme.colorScheme.secondary; // Oranssi/Turkoosi
        statusIcon = Icons.directions_walk_rounded;
        statusLabel = 'Upcoming';
        break;
      case HikeStatus.completed:
        statusColor = theme.colorScheme.primary; // Sininen
        statusIcon = Icons.check_circle_outline_rounded;
        statusLabel = 'Completed';
        break;
      case HikeStatus.cancelled:
        statusColor = theme.colorScheme.error; // Punainen teemasta
        statusIcon = Icons.cancel_outlined;
        statusLabel = 'Cancelled';
        break;
      case HikeStatus.planned:
        if (allPreparationsDone) {
          statusColor = theme.colorScheme.primary
              .withOpacity(0.8); // Hieman vaaleampi sininen
          statusIcon = Icons.task_alt_rounded;
          statusLabel = 'Ready to go!';
        } else {
          statusColor = Colors.blueGrey.shade400; // Neutraali harmaa-sininen
          statusIcon = Icons.pending_actions_rounded;
          statusLabel = 'In Preparation';
        }
        break;
      default:
        statusColor = Colors.grey.shade500;
        statusIcon = Icons.help_outline_rounded;
        statusLabel = 'Unknown';
        break;
    }

    double progress =
        totalItems > 0 ? (completedItems / totalItems).clamp(0.0, 1.0) : 0.0;
    bool isPreparationRelevant = displayStatus == HikeStatus.planned ||
        displayStatus == HikeStatus.upcoming;

    return Card(
      elevation: 2.0, // Hienovarainen varjo
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
                      style: titleTextStyle,
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
                            color: theme.colorScheme.onSurfaceVariant),
                        iconSize: 24,
                        tooltip: "Options", // Lisätty tooltip
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                12)), // Pyöristetty PopupMenu
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          if (onEdit != null)
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined,
                                    size: 20,
                                    color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 10),
                                Text('Edit',
                                    style: GoogleFonts.lato(
                                        color:
                                            theme.colorScheme.onSurfaceVariant))
                              ]),
                            ),
                          if (onDelete != null)
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline_rounded,
                                    color: theme.colorScheme.error, size: 20),
                                const SizedBox(width: 10),
                                Text('Delete',
                                    style: GoogleFonts.lato(
                                        color: theme.colorScheme.error))
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
                    const SizedBox(
                        width: 40, height: 40), // Placeholder for alignment
                ],
              ),
              const SizedBox(height: 10),
              _buildInfoRowCompact(
                theme, Icons.location_on_outlined, plan.location,
                // MUUTETTU VÄRI TÄSSÄ:
                color: theme.colorScheme.primary,
                textStyle: infoRowTextStyle,
              ),
              const SizedBox(height: 6),
              _buildInfoRowCompact(
                theme, Icons.calendar_today_outlined, dateDisplay,
                // MUUTETTU VÄRI TÄSSÄ:
                color: theme.colorScheme.primary,
                textStyle: infoRowTextStyle,
              ),
              if (plan.lengthKm != null && plan.lengthKm! > 0) ...[
                const SizedBox(height: 6),
                _buildInfoRowCompact(
                  theme, Icons.directions_walk_outlined,
                  '${plan.lengthKm?.toStringAsFixed(1)} km',
                  // MUUTETTU VÄRI TÄSSÄ:
                  color: theme.colorScheme.primary,
                  textStyle: infoRowTextStyle,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                      // Status badge voi kasvaa tarvittaessa
                      child: _buildStatusBadge(theme, statusColor, statusIcon,
                          statusLabel, statusLabelStyle)),
                  if (onUpdatePreparation != null && isPreparationRelevant)
                    TextButton.icon(
                      icon: Icon(
                        allPreparationsDone
                            ? Icons.fact_check_outlined
                            : Icons.checklist_rtl_outlined,
                        size: 19,
                        color: allPreparationsDone
                            ? theme.colorScheme
                                .primary // Käytä samaa väriä kuin completed
                            : theme.colorScheme
                                .secondary, // Tai oranssi/turkoosi jos kesken
                      ),
                      label: Text(
                        allPreparationsDone
                            ? 'Checklist' // Lyhyempi ja ytimekkäämpi
                            : '$completedItems/$totalItems done',
                        style: GoogleFonts.lato(
                            color: allPreparationsDone
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      onPressed: () => onUpdatePreparation!(plan),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8), // Hieman isompi padding
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                10)), // Pyöristetymmät kulmat
                        backgroundColor: (allPreparationsDone
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary)
                            .withOpacity(0.12), // Hieman voimakkaampi tausta
                      ),
                    )
                ],
              ),
              if (isPreparationRelevant && totalItems > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(6), // Pyöristetympi palkki
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: statusColor.withOpacity(0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 8, // Hieman paksumpi
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRowCompact(ThemeData theme, IconData icon, String text,
      {required Color color, required TextStyle textStyle}) {
    // Lisätty textStyle parametri
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center, // Keskitä vertikaalisesti
      children: [
        Icon(icon,
            size: 17, color: color.withOpacity(0.95)), // Hieman isompi ikoni
        const SizedBox(width: 10), // Hieman isompi väli
        Expanded(
          child: Text(
            text,
            style: textStyle, // Käytetään annettua tekstityyliä
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ThemeData theme, Color color, IconData icon,
      String label, TextStyle labelStyle) {
    // Lisätty labelStyle
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 7), // Hieman isompi padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.18), // Hieman voimakkaampi tausta
        borderRadius: BorderRadius.circular(10), // Pyöristetymmät kulmat
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color), // Hieman isompi ikoni
          const SizedBox(width: 8),
          Text(
            label,
            style: labelStyle.copyWith(
                color: color,
                fontSize: 12.5), // Käytetään annettua tyyliä ja kokoa
          ),
        ],
      ),
    );
  }
}
