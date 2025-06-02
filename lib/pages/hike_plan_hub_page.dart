// lib/pages/hike_plan_hub_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hike_plan_model.dart';
import '../widgets/preparation_progress_modal.dart'; // Tuodaan modaali
import '../services/hike_plan_service.dart'; // Tuodaan palvelu päivitystä varten

class HikePlanHubPage extends StatefulWidget {
  final HikePlan initialPlan;

  const HikePlanHubPage({super.key, required this.initialPlan});

  @override
  State<HikePlanHubPage> createState() => _HikePlanHubPageState();
}

class _HikePlanHubPageState extends State<HikePlanHubPage> {
  late HikePlan _currentPlan;
  final HikePlanService _hikePlanService = HikePlanService();

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.initialPlan;
  }

  Future<void> _openAndUpdatePreparationModal() async {
    final updatedItems =
        await showPreparationProgressModal(context, _currentPlan);

    if (updatedItems != null && mounted) {
      setState(() {
        _currentPlan = _currentPlan.copyWith(preparationItems: updatedItems);
      });
      try {
        await _hikePlanService.updateHikePlan(_currentPlan);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Valmistautumisen tila päivitetty!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Virhe tilan päivityksessä: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
          // Palauta vanha tila, jos päivitys epäonnistui (valinnainen)
          setState(() {
            _currentPlan = widget.initialPlan; // Tai hae uudelleen Firebasesta
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final dateFormat = DateFormat('EEEE d. MMMM yyyy', 'fi_FI');

    int completedItems = _currentPlan.completedPreparationItems;
    int totalItems = _currentPlan.totalPreparationItems;
    double progress = totalItems > 0 ? completedItems / totalItems : 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 220.0, // Korkeus, kun laajennettu
            floating: false, // Pysyy ylhäällä, kun scrollataan ylös
            pinned: true, // Pysyy näkyvissä pienenä, kun scrollataan alas
            snap: false, // Ei "napsahda" paikoilleen
            backgroundColor:
                theme.colorScheme.surface, // Teeman mukainen tausta
            elevation: 2.0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(
                _currentPlan.hikeName,
                style: textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: _currentPlan.latitude != null &&
                      _currentPlan.longitude != null
                  ? _buildMapBackground(
                      theme) // TODO: Toteuta karttanäkymä tai kuva
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.7),
                            theme.colorScheme.secondary.withOpacity(0.5)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                          child: Icon(Icons.landscape_rounded,
                              size: 80, color: Colors.white.withOpacity(0.3))),
                    ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentPlan.location,
                        style: textTheme.titleMedium?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dateFormat.format(_currentPlan.startDate)}${_currentPlan.endDate != null ? " - ${dateFormat.format(_currentPlan.endDate!)}" : ""}',
                        style: textTheme.bodyMedium?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.7)),
                      ),
                      if (_currentPlan.lengthKm != null &&
                          _currentPlan.lengthKm! > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Pituus: ${_currentPlan.lengthKm} km',
                            style: textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7)),
                          ),
                        ),

                      const SizedBox(height: 20),
                      _buildSectionTitle(theme, "Valmistautuminen"),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$completedItems/$totalItems suoritettu',
                            style: textTheme.titleMedium,
                          ),
                          if (_currentPlan.status != HikeStatus.completed &&
                              _currentPlan.status != HikeStatus.cancelled)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_note_outlined,
                                  size: 18),
                              label: const Text('Merkitse'),
                              onPressed: _openAndUpdatePreparationModal,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.colorScheme.secondary,
                                  side: BorderSide(
                                      color: theme.colorScheme.secondary
                                          .withOpacity(0.5)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6)),
                            )
                        ],
                      ),
                      if (_currentPlan.status != HikeStatus.completed &&
                          _currentPlan.status != HikeStatus.cancelled) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor:
                              theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          completedItems == totalItems
                              ? "Kaikki valmista lähtöön!"
                              : "Vielä tehtävää...",
                          style: textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ],
                      if (_currentPlan.notes != null &&
                          _currentPlan.notes!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildSectionTitle(theme, "Muistiinpanot"),
                        const SizedBox(height: 8),
                        Text(_currentPlan.notes!,
                            style: textTheme.bodyLarge?.copyWith(height: 1.5)),
                      ],

                      const SizedBox(height: 24),
                      _buildPlannerSectionButton(
                          context, "Sääennuste", Icons.wb_sunny_outlined, () {
                        /* TODO: Navigoi Sää-osioon */
                      }),
                      _buildPlannerSectionButton(
                          context, "Pakkauslista", Icons.backpack_outlined, () {
                        /* TODO: Navigoi Pakkauslista-osioon */
                      }),
                      _buildPlannerSectionButton(context, "Päiväsuunnitelma",
                          Icons.event_note_outlined, () {
                        /* TODO: Navigoi Päiväsuunnitelma-osioon */
                      }),
                      _buildPlannerSectionButton(context, "Ruokasuunnitelma",
                          Icons.restaurant_outlined, () {
                        /* TODO: Navigoi Ruokasuunnitelma-osioon */
                      }),

                      const SizedBox(height: 40), // Tilaa alareunaan
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBackground(ThemeData theme) {
    // TODO: Toteuta todellinen kartta-widget (esim. flutter_map) tai staattinen karttakuva (esim. Mapbox Static Images API)
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          // Placeholder-kuva
          image: NetworkImage(
              'https://source.unsplash.com/random/800x600/?hiking,landscape,${_currentPlan.location.split(',').first.trim()}'),
          fit: BoxFit.cover,
          colorFilter:
              ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.secondary,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildPlannerSectionButton(BuildContext context, String title,
      IconData icon, VoidCallback onPressed) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 28),
        title: Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
        onTap: onPressed,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    );
  }
}
