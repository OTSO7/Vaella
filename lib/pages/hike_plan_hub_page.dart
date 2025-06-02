// lib/pages/hike_plan_hub_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; // Pidetään animaatiot
import 'dart:ui' as ui;

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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.initialPlan;
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Nopeutetaan hieman
    );
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openAndUpdatePreparationModal() async {
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Valmistautumisen tila päivitetty!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(10),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Virhe tilan päivityksessä: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(10),
          ));
          setState(() {
            _currentPlan = previousPlanState;
          });
        }
      }
    }
  }

  Widget _buildAnimatedItem({required Widget child, required int index}) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration:
          Duration(milliseconds: 400 + (index * 25)), // Hienosäädetty kesto
      child: SlideAnimation(
        verticalOffset: 30.0,
        curve: Curves.easeOutCubic,
        child: FadeInAnimation(curve: Curves.easeOutCubic, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    bool isPreparationRelevant = _currentPlan.status == HikeStatus.planned ||
        _currentPlan.status == HikeStatus.upcoming;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Varmistaa statusbarin tyylin koko sivulle
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: AnimationLimiter(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: <Widget>[
              _buildHubSliverAppBar(theme, textTheme),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed(
                      // Käytetään .fixed, koska lista on staattinen
                      _buildContentWidgetsList(
                          theme, textTheme, isPreparationRelevant)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContentWidgetsList(
      ThemeData theme, TextTheme textTheme, bool isPreparationRelevant) {
    int animationIndex = 0;
    return [
      _buildAnimatedItem(
          child: _buildOverviewSection(theme, textTheme),
          index: animationIndex++),
      SizedBox(
          height: isPreparationRelevant ||
                  (_currentPlan.status == HikeStatus.completed ||
                      _currentPlan.status == HikeStatus.cancelled)
              ? 32
              : 0),

      if (isPreparationRelevant) ...[
        _buildAnimatedItem(
            child: _buildSectionTitle(
                theme, "Valmistautuminen", Icons.fact_check_outlined),
            index: animationIndex++),
        _buildAnimatedItem(
            child: _buildPreparationSection(theme, textTheme),
            index: animationIndex++),
        const SizedBox(height: 32),
      ] else if (_currentPlan.status == HikeStatus.completed) ...[
        _buildAnimatedItem(
            child: _buildStatusHighlight(
                theme,
                "Vaellus suoritettu onnistuneesti!",
                Icons.celebration_rounded,
                Colors.green.shade600),
            index: animationIndex++),
        const SizedBox(height: 32),
      ] else if (_currentPlan.status == HikeStatus.cancelled) ...[
        _buildAnimatedItem(
            child: _buildStatusHighlight(theme, "Tämä vaellus on peruttu.",
                Icons.block_rounded, theme.colorScheme.error),
            index: animationIndex++),
        const SizedBox(height: 32),
      ],

      if (_currentPlan.notes != null && _currentPlan.notes!.isNotEmpty) ...[
        _buildAnimatedItem(
            child: _buildSectionTitle(
                theme, "Muistiinpanot", Icons.sticky_note_2_outlined),
            index: animationIndex++),
        _buildAnimatedItem(
            child: _buildNotesSection(theme, textTheme),
            index: animationIndex++),
        const SizedBox(height: 32),
      ],

      _buildAnimatedItem(
          child: _buildSectionTitle(
              theme, "Suunnittelutyökalut", Icons.category_outlined),
          index: animationIndex++),
      // Suunnittelutyökalut ruudukkona
      AnimationConfiguration.staggeredGrid(
        columnCount: 2,
        position: animationIndex,
        duration: const Duration(milliseconds: 500),
        child: ScaleAnimation(
          scale: 0.9,
          curve: Curves.easeOutExpo,
          child: FadeInAnimation(
            curve: Curves.easeOutExpo,
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3, // Säädä tätä tarpeen mukaan
              children: [
                _buildPlannerGridItem(
                  context,
                  "Sääennuste",
                  Icons.thermostat_rounded,
                  () {
                    /*TODO*/
                  },
                  Colors.orange.shade300,
                  animationIndex++,
                ),
                _buildPlannerGridItem(
                  context,
                  "Pakkauslista",
                  Icons.backpack_rounded,
                  () {
                    /*TODO*/
                  },
                  Colors.orange.shade300,
                  animationIndex++,
                ),
                _buildPlannerGridItem(
                  context,
                  "Reittisuunnitelma",
                  Icons.route_rounded,
                  () {
                    /*TODO*/
                  },
                  Colors.orange.shade300,
                  animationIndex++,
                ),
                _buildPlannerGridItem(
                  context,
                  "Ruokalista",
                  Icons.restaurant_rounded,
                  () {
                    /*TODO*/
                  },
                  Colors.orange.shade300,
                  animationIndex++,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 40),
    ];
  }

  Widget _buildHubSliverAppBar(ThemeData theme, TextTheme textTheme) {
    String locationForImage = _currentPlan.location.split(',').first.trim();
    locationForImage = locationForImage
        .replaceAllMapped(
            RegExp(r'(\w+) kansallispuisto', caseSensitive: false),
            (match) => '${match.group(1)} national park')
        .replaceAll(RegExp(r' national park', caseSensitive: false), '')
        .trim();
    if (locationForImage.isEmpty) locationForImage = "nature landscape";

    return SliverAppBar(
      expandedHeight: 300.0, // Antaa enemmän tilaa kuvalle
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0, // Ei varjoa, kun kutistunut, sulautuu paremmin
      leading: Padding(
        // Lisätään padding takaisin-nuolelle
        padding: const EdgeInsets.all(8.0),
        child: Material(
          // Material-efekti napille
          color: Colors.black.withOpacity(0.25),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Takaisin',
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true, // Keskitetään otsikko paremmin
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
            .copyWith(bottom: 20), // Lisää tilaa otsikolle
        title: Text(
          _currentPlan.hikeName,
          style: textTheme.headlineSmall?.copyWith(
              // Käytetään headlineSmall tai vastaavaa
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [
                const Shadow(
                    blurRadius: 5.0,
                    color: Colors.black87,
                    offset: Offset(1.5, 1.5))
              ]),
          textAlign: TextAlign.center,
          maxLines: 2, // Salli kahden rivin otsikko
          overflow: TextOverflow.ellipsis,
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl:
                  'https://source.unsplash.com/1200x800/?${locationForImage.isNotEmpty ? locationForImage : 'hiking,mountain,forest'}',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5)),
              errorWidget: (context, url, error) => Container(
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.surfaceContainerHighest
                ], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                child: Icon(Icons.terrain_rounded,
                    size: 120,
                    color: theme.colorScheme.onSurface.withOpacity(0.05)),
              ),
            ),
            // Sumennus vain alareunaan, jotta otsikko erottuu
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                    sigmaX: 0.5,
                    sigmaY: 0.5), // Hyvin hienovarainen sumennus koko kuvalle
                child: Container(color: Colors.black.withOpacity(0.1)),
              ),
            ),
            Container(
              // Tummentava gradientti alhaalta ylös
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 1.0], // Gradientti alkaa myöhemmin
                ),
              ),
            ),
          ],
        ),
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground
        ],
      ),
    );
  }

  Widget _buildOverviewSection(ThemeData theme, TextTheme textTheme) {
    final dateFormat =
        DateFormat('d. MMMM yyyy', 'fi_FI'); // Selkeämpi päivämäärämuoto
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(theme, "Yleiskatsaus", Icons.info_outline_rounded),
        const SizedBox(height: 8),
        _buildInfoRow(theme, Icons.fmd_good_outlined, _currentPlan.location),
        const SizedBox(height: 12),
        _buildInfoRow(
          theme,
          Icons.date_range_outlined,
          '${dateFormat.format(_currentPlan.startDate)}${_currentPlan.endDate != null && _currentPlan.endDate != _currentPlan.startDate ? " – ${dateFormat.format(_currentPlan.endDate!)}" : ""}',
        ),
        if (_currentPlan.lengthKm != null && _currentPlan.lengthKm! > 0) ...[
          const SizedBox(height: 12),
          _buildInfoRow(theme, Icons.linear_scale_rounded,
              'Pituus: ${_currentPlan.lengthKm?.toStringAsFixed(1)} km'),
        ],
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 20,
              color: theme.colorScheme.secondary), // Käytetään secondary-väriä
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      color: theme.colorScheme.onSurface.withOpacity(0.9)))),
        ],
      ),
    );
  }

  Widget _buildStatusHighlight(
      ThemeData theme, String message, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
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
          color:
              theme.cardColor.withOpacity(0.1), // Erittäin hienovarainen tausta
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: theme.colorScheme.outline.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  allDone
                      ? 'Kaikki valmista!'
                      : '$completed/$total kohdetta valmiina',
                  style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      fontSize: 16),
                ),
              ),
              TextButton(
                // Käytetään TextButtonia kevyempänä versiona
                onPressed: _openAndUpdatePreparationModal,
                style: TextButton.styleFrom(
                  foregroundColor: allDone
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        allDone ? Icons.edit_off_outlined : Icons.edit_outlined,
                        size: 18),
                    const SizedBox(width: 6),
                    Text(allDone ? 'Tarkastele' : 'Muokkaa'),
                  ],
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: (allDone
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary)
                    .withOpacity(0.25),
                valueColor: AlwaysStoppedAnimation<Color>(allDone
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondary),
                minHeight: 10, // Selkeämpi palkki
              ),
            ),
            const SizedBox(height: 8),
            Text(
              allDone
                  ? "Erinomaista, olet valmis lähtöön!"
                  : "Viimeistele valmistelut.",
              style: textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8)),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Text(
                "Valmisteltavia kohteita ei määritelty.",
                style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon,
      {Color? color, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            // Ikonille tyylitelty tausta
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (iconColor ?? theme.colorScheme.primary).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: iconColor ?? theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              // Käytetään isompaa ja selkeämpää
              color: color ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlannerGridItem(BuildContext context, String title,
      IconData icon, VoidCallback onPressed, Color itemColor, int index,
      {Color? textColor}) {
    final theme = Theme.of(context);
    return Material(
      color: itemColor.withOpacity(0.12), // Läpikuultava tausta
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        splashColor: itemColor.withOpacity(0.3),
        highlightColor: itemColor.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: textColor ?? itemColor),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textColor ?? itemColor.withOpacity(0.9)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection(ThemeData theme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
      ),
      child: Text(
        _currentPlan.notes ?? "",
        style: textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.95),
          height: 1.5,
        ),
      ),
    );
  }

  // Korvataan aiempi _buildPlannerActionItem-lista tällä ruudukolla
  Widget _buildPlannerActionsGrid(BuildContext context, ThemeData theme) {
    final actions = [
      {
        'title': "Sääennuste",
        'icon': Icons.thermostat_rounded,
        'onPressed': () {/*TODO*/},
        'color': theme.colorScheme.primary,
        'textColor': theme.colorScheme.onPrimaryContainer
      },
      {
        'title': "Pakkauslista",
        'icon': Icons.backpack_rounded,
        'onPressed': () {/*TODO*/},
        'color': theme.colorScheme.secondary,
        'textColor': theme.colorScheme.onSecondaryContainer
      },
      {
        'title': "Reittisuunnitelma",
        'icon': Icons.route_rounded,
        'onPressed': () {/*TODO*/},
        'color': theme.colorScheme.tertiary,
        'textColor': theme.colorScheme.onTertiaryContainer
      },
      {
        'title': "Ruokalista",
        'icon': Icons.restaurant_menu_rounded,
        'onPressed': () {/*TODO*/},
        'color': Colors.orange.shade300,
        'textColor': Colors.black87
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.25, // Säädä tätä, jos sisältö ei mahdu hyvin
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        // Ei käytetä enää _buildAnimatedItem tässä, koska GridView hoitaa oman rakentamisensa.
        // Animaatiot voitaisiin lisätä _buildPlannerGridItem-metodin sisälle tarvittaessa.
        return _buildPlannerGridItem(
            context,
            action['title'] as String,
            action['icon'] as IconData,
            action['onPressed'] as VoidCallback,
            action['color'] as Color,
            index, // Välitetään indeksi, jos sitä tarvitaan animaatioon grid itemin sisällä
            textColor: action['textColor'] as Color?);
      },
    );
  }
}

// ---- _CustomSliverAppBarDelegate pysyy samana kuin edellisessä vastauksessa ----
// Sen rakenne on jo melko moderni ja dynaaminen. Varmista, että se on kopioitu oikein.
class _CustomSliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double expandedHeight;
  final double minHeight;
  final String planName;
  final String imageUrl;
  final ThemeData theme;
  final TextTheme textTheme;
  final HikePlan currentPlan;

  _CustomSliverAppBarDelegate({
    required this.expandedHeight,
    required this.minHeight,
    required this.planName,
    required this.imageUrl,
    required this.theme,
    required this.textTheme,
    required this.currentPlan,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final appBarSize = expandedHeight - shrinkOffset;
    final proportion = appBarSize <= minExtent
        ? 1.0
        : (expandedHeight - appBarSize) / (expandedHeight - minExtent);
    final titleOpacity =
        Curves.easeOut.transform(1.0 - proportion.clamp(0.0, 1.0));

    final double normalizedShrink =
        (shrinkOffset / (expandedHeight - minHeight)).clamp(0.0, 1.0);
    final double currentBlur = ui.lerpDouble(2.5, 0.0, normalizedShrink)!;
    final double currentOverlayOpacity =
        ui.lerpDouble(0.35, 0.0, normalizedShrink)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(color: theme.colorScheme.primaryContainer),
            errorWidget: (context, url, error) => Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerHighest
              ], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              child: Icon(Icons.terrain_rounded,
                  size: 100,
                  color: theme.colorScheme.onSurface.withOpacity(0.1)),
            ),
          ),
          if (currentBlur > 0.05)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                    sigmaX: currentBlur, sigmaY: currentBlur),
                child: Container(
                    color:
                        Colors.black.withOpacity(currentOverlayOpacity * 0.4)),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.40),
                  Colors.transparent,
                  Colors.black.withOpacity(0.60)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 8,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                iconSize: 22,
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Takaisin',
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Opacity(
              opacity: titleOpacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    planName,
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(
                            blurRadius: 2.0,
                            color: Colors.black87,
                            offset: Offset(1, 1))
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => expandedHeight;
  @override
  double get minExtent => minHeight;
  @override
  bool shouldRebuild(_CustomSliverAppBarDelegate oldDelegate) {
    return expandedHeight != oldDelegate.expandedHeight ||
        minHeight != oldDelegate.minHeight ||
        planName != oldDelegate.planName ||
        imageUrl != oldDelegate.imageUrl ||
        theme != oldDelegate.theme ||
        currentPlan != oldDelegate.currentPlan;
  }
}
