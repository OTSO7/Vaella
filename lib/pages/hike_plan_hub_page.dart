// lib/pages/hike_plan_hub_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/hike_plan_model.dart';
import '../widgets/preparation_progress_modal.dart';
import '../services/hike_plan_service.dart';
import '../utils/app_colors.dart';

// UUTTA: Käytetään samaa delegaattia kuin PackingListPage-sivulla
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

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
  final ScrollController _scrollController = ScrollController();
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.initialPlan;
    // MUUTETTU: TabController kahdelle välilehdelle: "Hub" ja "Details"
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  // Aputoiminnot ja logiikka pysyvät pääosin ennallaan.
  TextTheme _getAppTextTheme(BuildContext context) {
    final currentTheme = Theme.of(context);
    return GoogleFonts.latoTextTheme(currentTheme.textTheme).copyWith(
      headlineLarge: currentTheme.textTheme.headlineLarge
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      headlineMedium: currentTheme.textTheme.headlineMedium
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      headlineSmall: currentTheme.textTheme.headlineSmall
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      titleLarge: currentTheme.textTheme.titleLarge
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      titleMedium: currentTheme.textTheme.titleMedium
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      titleSmall: currentTheme.textTheme.titleSmall
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      labelLarge: currentTheme.textTheme.labelLarge
          ?.copyWith(fontFamily: GoogleFonts.poppins().fontFamily),
      bodyLarge: currentTheme.textTheme.bodyLarge
          ?.copyWith(fontFamily: GoogleFonts.lato().fontFamily),
      bodyMedium: currentTheme.textTheme.bodyMedium
          ?.copyWith(fontFamily: GoogleFonts.lato().fontFamily),
      bodySmall: currentTheme.textTheme.bodySmall
          ?.copyWith(fontFamily: GoogleFonts.lato().fontFamily),
    );
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
            content: const Text('Preparation status updated!'),
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
            content: Text('Error updating status: $e'),
            backgroundColor: AppColors.errorColor(context),
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

  @override
  Widget build(BuildContext context) {
    final appTextTheme = _getAppTextTheme(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // MUUTETTU: Koko runko on nyt Tab-pohjainen
      body: DefaultTabController(
        length: 2,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            _buildHubSliverAppBar(context, appTextTheme),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.orange.shade300,
                  indicatorWeight: 3.0,
                  labelColor: Colors.orange.shade300,
                  unselectedLabelColor: theme.hintColor,
                  labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  unselectedLabelStyle:
                      GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: 'Hub'),
                    Tab(text: 'Details'),
                  ],
                ),
              ),
              pinned: true,
            ),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHubTab(context, appTextTheme),
                  _buildDetailsTab(context, appTextTheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UUTTA: Päänäkymä, joka sisältää tärkeimmät toiminnot
  Widget _buildHubTab(BuildContext context, TextTheme appTextTheme) {
    bool isPreparationRelevant = _currentPlan.status == HikeStatus.planned ||
        _currentPlan.status == HikeStatus.upcoming ||
        _currentPlan.status == HikeStatus.ongoing;

    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        const SizedBox(height: 24),
        if (isPreparationRelevant) ...[
          _buildSectionTitle(
              context, "Preparation", Icons.fact_check_outlined, appTextTheme),
          const SizedBox(height: 4),
          _buildPreparationSection(context, appTextTheme),
          const SizedBox(height: 24),
        ],
        _buildSectionTitle(
            context, "Planning Tools", Icons.category_outlined, appTextTheme),
        const SizedBox(height: 4),
        _buildPlannerActionsGrid(context),
        const SizedBox(height: 40),
      ],
    );
  }

  // UUTTA: Yksityiskohtien sivu
  Widget _buildDetailsTab(BuildContext context, TextTheme appTextTheme) {
    final content = <Widget>[
      const SizedBox(height: 24),
      _buildSectionTitle(
          context, "Overview", Icons.info_outline_rounded, appTextTheme),
      const SizedBox(height: 4),
      _buildOverviewSection(context, appTextTheme),
      const SizedBox(height: 24),
    ];

    if (_currentPlan.status == HikeStatus.completed) {
      content.addAll([
        _buildStatusHighlight(context, "Hike completed successfully!",
            Icons.celebration_rounded, Colors.green.shade600, appTextTheme),
        const SizedBox(height: 24),
      ]);
    } else if (_currentPlan.status == HikeStatus.cancelled) {
      content.addAll([
        _buildStatusHighlight(context, "This hike has been cancelled.",
            Icons.block_rounded, AppColors.errorColor(context), appTextTheme),
        const SizedBox(height: 24),
      ]);
    }

    if (_currentPlan.notes != null && _currentPlan.notes!.isNotEmpty) {
      content.addAll([
        _buildSectionTitle(
            context, "Notes", Icons.sticky_note_2_outlined, appTextTheme),
        const SizedBox(height: 4),
        _buildNotesSection(context, appTextTheme),
        const SizedBox(height: 24),
      ]);
    }
    content.add(const SizedBox(height: 40));

    return ListView(
      padding: const EdgeInsets.all(0),
      children: content,
    );
  }

  // --- UUDELLEENJÄRJESTELLYT JA HIENOSÄÄDETYT ALKUPEÄISET WIDGETIT ---

  Widget _buildSectionTitle(
      BuildContext context, String title, IconData icon, TextTheme appTextTheme,
      {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon,
              color: iconColor ?? AppColors.primaryColor(context), size: 24),
          const SizedBox(width: 12),
          Text(title,
              style: appTextTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor(context))),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(BuildContext context, TextTheme appTextTheme) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 1,
        color: AppColors.cardColor(context).withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildInfoRow(context, Icons.fmd_good_outlined,
                  _currentPlan.location, appTextTheme,
                  isHeader: true),
              const SizedBox(height: 12),
              _buildInfoRow(
                  context,
                  Icons.date_range_outlined,
                  '${dateFormat.format(_currentPlan.startDate)}${_currentPlan.endDate != null && _currentPlan.endDate != _currentPlan.startDate ? " – ${dateFormat.format(_currentPlan.endDate!)}" : ""}',
                  appTextTheme),
              if (_currentPlan.lengthKm != null &&
                  _currentPlan.lengthKm! > 0) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                    context,
                    Icons.linear_scale_rounded,
                    'Approx. ${_currentPlan.lengthKm?.toStringAsFixed(1)} km',
                    appTextTheme),
              ],
              if (_currentPlan.difficulty != HikeDifficulty.unknown) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.speed_rounded,
                        size: 20, color: AppColors.accentColor(context)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: RichText(
                      text: TextSpan(
                          style: appTextTheme.bodyLarge?.copyWith(
                              color: AppColors.textColor(context)
                                  .withOpacity(0.9)),
                          children: [
                            const TextSpan(text: 'Difficulty: '),
                            TextSpan(
                                text: _currentPlan.difficulty.toShortString(),
                                style: TextStyle(
                                    color: _currentPlan.difficulty
                                        .getColor(context),
                                    fontWeight: FontWeight.bold)),
                          ]),
                    )),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String text, TextTheme appTextTheme,
      {bool isHeader = false}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon,
            size: 20,
            color: isHeader
                ? AppColors.primaryColor(context)
                : AppColors.accentColor(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style:
                  (isHeader ? appTextTheme.titleMedium : appTextTheme.bodyLarge)
                      ?.copyWith(
                color: AppColors.textColor(context)
                    .withOpacity(isHeader ? 1.0 : 0.9),
                fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
              )),
        ),
      ],
    );
  }

  Widget _buildStatusHighlight(BuildContext context, String message,
      IconData icon, Color color, TextTheme appTextTheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
              child: Text(message,
                  style: appTextTheme.titleMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildPreparationSection(
      BuildContext context, TextTheme appTextTheme) {
    int completed = _currentPlan.completedPreparationItems;
    int total = _currentPlan.totalPreparationItems;
    double progress = total > 0 ? completed / total : 0.0;
    bool allDone = completed == total && total > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        color: AppColors.cardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: _openAndUpdatePreparationModal,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(
                            allDone
                                ? 'All items checked!'
                                : '$completed of $total tasks done',
                            style: appTextTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600))),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 18, color: AppColors.subtleTextColor(context)),
                  ],
                ),
                if (total > 0) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor:
                          AppColors.primaryColor(context).withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor(context)),
                      minHeight: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, TextTheme appTextTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 1,
        color: AppColors.cardColor(context).withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _currentPlan.notes ?? "No notes for this hike.",
            style: appTextTheme.bodyLarge?.copyWith(
              color: AppColors.onCardColor(context).withOpacity(
                  _currentPlan.notes != null && _currentPlan.notes!.isNotEmpty
                      ? 0.95
                      : 0.7),
              height: 1.5,
              fontStyle:
                  _currentPlan.notes != null && _currentPlan.notes!.isNotEmpty
                      ? FontStyle.normal
                      : FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  // UUTTA: Muutettu teemaa ja värejä vastaamaan muiden sivujen ilmettä
  Widget _buildPlannerActionsGrid(BuildContext context) {
    final theme = Theme.of(context);
    final actions = [
      {
        'title': "Weather",
        'icon': Icons.thermostat_auto_rounded,
        'onPressed': () {
          if (_currentPlan.latitude != null && _currentPlan.longitude != null) {
            GoRouter.of(context).pushNamed('weatherPage',
                pathParameters: {'planId': _currentPlan.id},
                extra: _currentPlan);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  const Text('Location coordinates are required for weather.'),
              backgroundColor: AppColors.errorColor(context),
            ));
          }
        }
      },
      {
        'title': "Packing List",
        'icon': Icons.backpack_outlined,
        'onPressed': () => GoRouter.of(context).pushNamed('packingListPage',
            pathParameters: {'planId': _currentPlan.id}, extra: _currentPlan)
      },
      {
        'title': "Route Plan",
        'icon': Icons.map_outlined,
        'onPressed': () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Route Plan: Coming soon!")))
      },
      {
        'title': "Meal Plan",
        'icon': Icons.restaurant_menu_outlined,
        'onPressed': () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Meal Plan: Coming soon!")))
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.25,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return _buildPlannerGridItem(
              context,
              action['title'] as String,
              action['icon'] as IconData,
              action['onPressed'] as VoidCallback,
              theme);
        },
      ),
    );
  }

  Widget _buildPlannerGridItem(BuildContext context, String title,
      IconData icon, VoidCallback onPressed, ThemeData theme) {
    return Card(
      elevation: 2.5,
      shadowColor: theme.shadowColor.withOpacity(0.3),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: _getAppTextTheme(context)
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // UUTTA: Lasimainen SliverAppBar, joka on linjassa PackingListPage-näkymän kanssa
  SliverAppBar _buildHubSliverAppBar(
      BuildContext context, TextTheme appTextTheme) {
    final theme = Theme.of(context);
    const double expandedHeight = 280.0;
    final bool hasImage =
        _currentPlan.imageUrl != null && _currentPlan.imageUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: Colors.transparent, // Tärkeä lasimaisuudelle
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => GoRouter.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Taustakuva tai gradientti
            if (hasImage)
              CachedNetworkImage(
                imageUrl: _currentPlan.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                    color: theme.colorScheme.primary.withOpacity(0.1)),
                errorWidget: (context, url, error) => Container(
                    color: theme.colorScheme.primary.withOpacity(0.1)),
              )
            else
              Container(color: theme.colorScheme.surface),

            // Tumma gradientti kuvan päällä luettavuuden parantamiseksi
            Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [
                        Colors.teal.shade500,
                        Colors.teal.shade700.withOpacity(0.8),
                        Colors.black.withOpacity(0.6)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.5, 1.0])),
            ),

            // Lasimainen sumennus skrollatessa
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(color: Colors.black.withOpacity(0.1)),
              ),
            ),

            // Sisältö (Otsikko, sijainti, päivämäärä)
            Positioned(
              bottom: 65, // Jättää tilaa TabBarille
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentPlan.hikeName,
                    style: appTextTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          const Shadow(blurRadius: 2, color: Colors.black54)
                        ]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.pin_drop_outlined,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _currentPlan.location,
                        style: appTextTheme.bodyLarge?.copyWith(
                            color: Colors.orange.shade300,
                            shadows: [
                              const Shadow(blurRadius: 1, color: Colors.black54)
                            ]),
                      )
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
