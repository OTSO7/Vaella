// lib/pages/hike_plan_hub_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../models/hike_plan_model.dart';
import '../widgets/preparation_progress_modal.dart';
import '../services/hike_plan_service.dart';

class HikePlanHubPage extends StatefulWidget {
  final HikePlan initialPlan;

  const HikePlanHubPage({super.key, required this.initialPlan});

  @override
  State<HikePlanHubPage> createState() => _HikePlanHubPageState();
}

class _HikePlanHubPageState extends State<HikePlanHubPage>
    with TickerProviderStateMixin {
  late HikePlan _currentPlan;
  final HikePlanService _hikePlanService = HikePlanService();
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.initialPlan;

    _staggerController = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 375), // Lyhyempi kesto per elementti
    );
    // Käynnistä animaatio viiveellä
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _openAndUpdatePreparationModal() async {
    // ... (koodi ennallaan, varmista että mounted-tarkistukset ovat paikallaan)
    final updatedItems =
        await showPreparationProgressModal(context, _currentPlan);

    if (updatedItems != null && mounted) {
      final previousPlanState = _currentPlan;
      setState(() {
        _currentPlan = _currentPlan.copyWith(preparationItems: updatedItems);
      });
      try {
        await _hikePlanService.updateHikePlan(_currentPlan);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Valmistautumisen tila päivitetty!'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Virhe tilan päivityksessä: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            _currentPlan = previousPlanState;
          });
        }
      }
    }
  }

  // Apumetodi animoidulle sisällölle
  Widget _buildAnimatedContent({required Widget child, required int index}) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(
          milliseconds: 500), // Yksittäisen elementin animaation kesto
      child: SlideAnimation(
        verticalOffset: 40.0,
        curve: Curves.easeOutCubic,
        child: FadeInAnimation(
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    bool isPreparationRelevant = _currentPlan.status == HikeStatus.planned ||
        _currentPlan.status == HikeStatus.upcoming;

    // Järjestetään rakennettavat widgetit listaan animaatiota varten
    final List<Widget> contentWidgets = [
      _buildOverviewSection(theme, textTheme),
      const SizedBox(height: 24),
      if (isPreparationRelevant) ...[
        _buildSectionHeader(
            theme, "Valmistautuminen", Icons.checklist_rtl_outlined),
        const SizedBox(height: 12),
        _buildPreparationSection(theme, textTheme),
        const SizedBox(height: 24),
      ] else if (_currentPlan.status == HikeStatus.completed) ...[
        _buildSectionHeader(
            theme, "Vaellus suoritettu", Icons.celebration_rounded,
            color: Colors.green.shade600),
        const SizedBox(height: 24),
      ] else if (_currentPlan.status == HikeStatus.cancelled) ...[
        _buildSectionHeader(
            theme, "Vaellus peruttu", Icons.do_not_disturb_on_outlined,
            color: theme.colorScheme.error),
        const SizedBox(height: 24),
      ],
      if (_currentPlan.notes != null && _currentPlan.notes!.isNotEmpty) ...[
        _buildSectionHeader(
            theme, "Muistiinpanot", Icons.speaker_notes_outlined),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.5), // Hienovarainen tausta
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_currentPlan.notes!,
              style: textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: theme.colorScheme.onSurface.withOpacity(0.9))),
        ),
        const SizedBox(height: 24),
      ],
      _buildSectionHeader(
          theme, "Suunnittelutyökalut", Icons.dashboard_customize_outlined),
      const SizedBox(height: 12),
      _buildPlannerActionItem(context, "Sääennuste", Icons.wb_cloudy_outlined,
          () {/* TODO */}),
      _buildPlannerActionItem(context, "Pakkauslista", Icons.backpack_rounded,
          () {/* TODO */}),
      _buildPlannerActionItem(
          context, "Päiväsuunnitelma", Icons.edit_calendar_outlined, () {
        /* TODO */
      }),
      _buildPlannerActionItem(
          context, "Ruokasuunnitelma", Icons.restaurant_menu_rounded, () {
        /* TODO */
      }),
      const SizedBox(height: 40),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 260.0,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor:
                theme.scaffoldBackgroundColor, // Tausta kun kutistunut
            foregroundColor: theme.colorScheme
                .onPrimaryContainer, // Takaisin-nuolen ja otsikon väri kun kutistunut
            elevation: 1.0, // Hienovarainen korostus
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                  left: 56, right: 56, bottom: 14), // Säädetty padding
              title: Text(
                _currentPlan.hikeName,
                style: textTheme.titleLarge?.copyWith(
                    color: Colors.white, // Varmistetaan kontrasti kuvan päällä
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                          blurRadius: 3.0,
                          color: Colors.black.withOpacity(0.7),
                          offset: const Offset(1, 2))
                    ]),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: _buildSliverAppBarBackground(theme),
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
                StretchMode.fadeTitle
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                16.0, 20.0, 16.0, 16.0), // Yläreunan padding SliverListille
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  // Käytetään _buildAnimatedContent-apumetodia jokaiselle pääelementille
                  return _buildAnimatedContent(
                    child: contentWidgets[index],
                    index: index,
                  );
                },
                childCount: contentWidgets.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBarBackground(ThemeData theme) {
    String locationQuery = _currentPlan.location.split(',').first.trim();
    if (locationQuery.toLowerCase().contains("kansallispuisto")) {
      locationQuery = locationQuery.replaceAllMapped(
          RegExp(r'(\w+) kansallispuisto', caseSensitive: false),
          (match) => '${match.group(1)} national park');
    }
    // Yritä myös poistaa "national park" hakusanasta, jotta saadaan monipuolisempia maisemakuvia
    locationQuery = locationQuery
        .replaceAll(RegExp(r' national park', caseSensitive: false), '')
        .trim();

    Widget imageWidget;
    if (_currentPlan.latitude != null && _currentPlan.longitude != null) {
      // Jos on koordinaatit, priotisoitu kuva
      imageWidget = CachedNetworkImage(
        imageUrl:
            'https://source.unsplash.com/800x600/?nature,landscape,${locationQuery.isNotEmpty ? locationQuery : 'mountain'}',
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Container(color: theme.colorScheme.surfaceVariant),
        errorWidget: (context, url, error) => Container(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            child: Icon(Icons.terrain_rounded,
                size: 80,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2))),
      );
    } else {
      // Jos ei koordinaatteja, geneerisempi gradient
      imageWidget = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.6),
              theme.colorScheme.secondary.withOpacity(0.4),
              theme.colorScheme.surface.withOpacity(0.2)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
            child: Icon(Icons.filter_hdr_rounded,
                size: 100, color: Colors.white.withOpacity(0.15))),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        imageWidget,
        Container(
          // Tummentava gradientti
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.45),
                Colors.transparent,
                Colors.black.withOpacity(0.65)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewSection(ThemeData theme, TextTheme textTheme) {
    final dateFormat = DateFormat('EEEE d. MMMM yyyy', 'fi_FI');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      decoration: BoxDecoration(
          // Ei erillistä taustaa, sulautuu sivun pohjaan
          // border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.5), width: 0.8)), // Hienovarainen erotin
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRowWithIcon(
              theme, Icons.pin_drop_outlined, _currentPlan.location,
              textStyle: textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildDetailRowWithIcon(
            theme,
            Icons.date_range_rounded,
            '${dateFormat.format(_currentPlan.startDate)}${_currentPlan.endDate != null && _currentPlan.endDate != _currentPlan.startDate ? " – ${dateFormat.format(_currentPlan.endDate!)}" : ""}',
          ),
          if (_currentPlan.lengthKm != null && _currentPlan.lengthKm! > 0) ...[
            const SizedBox(height: 12),
            _buildDetailRowWithIcon(theme, Icons.directions_run_rounded,
                'Matka: ${_currentPlan.lengthKm} km'),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRowWithIcon(ThemeData theme, IconData icon, String text,
      {TextStyle? textStyle}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary.withOpacity(0.9)),
        const SizedBox(width: 14),
        Expanded(
            child: Text(text,
                style: textStyle ??
                    theme.textTheme.bodyLarge?.copyWith(
                        height: 1.45,
                        color: theme.colorScheme.onSurface.withOpacity(0.9)))),
      ],
    );
  }

  Widget _buildPreparationSection(ThemeData theme, TextTheme textTheme) {
    int completed = _currentPlan.completedPreparationItems;
    int total = _currentPlan.totalPreparationItems;
    double progress = total > 0 ? completed / total : 0.0;
    bool allDone = completed == total && total > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.5), // Hienovarainen tausta
        borderRadius: BorderRadius.circular(14),
        // border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                allDone ? 'Kaikki valmista!' : '$completed/$total suoritettu',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (!allDone)
                TextButton.icon(
                  icon: Icon(Icons.edit_note_rounded,
                      size: 20, color: theme.colorScheme.secondary),
                  label: Text('Päivitä',
                      style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold)),
                  onPressed: _openAndUpdatePreparationModal,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    // backgroundColor: theme.colorScheme.secondary.withOpacity(0.1) // Hienovarainen tausta
                  ),
                ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              allDone
                  ? "Upeaa! Olet valmis seikkailuun."
                  : "Jatka valmisteluja, niin olet pian valmis!",
              style: textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8)),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Valmistautumisen seurantaa ei ole vielä määritetty.",
                style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon,
      {Color? color}) {
    return Row(
      children: [
        Icon(icon,
            color: color ?? theme.colorScheme.primary,
            size: 24), // Hieman isompi ikoni
        const SizedBox(width: 12),
        Text(
          title, // Ei enää toUpperCase, jotta luonnollisempi
          style: theme.textTheme.titleLarge?.copyWith(
            // Käytetään titleLargea selkeyteen
            color: color ?? theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600, // Hieman kevyempi kuin bold
            // letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPlannerActionItem(BuildContext context, String title,
      IconData icon, VoidCallback onPressed) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ]),
      child: Material(
        // Lisätty Material InkWell-efektille
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12.0),
          splashColor: theme.colorScheme.primary.withOpacity(0.1),
          highlightColor: theme.colorScheme.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Icon(icon,
                    color: theme.colorScheme.secondary,
                    size: 26), // Käytetään secondary-väriä
                const SizedBox(width: 16),
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
