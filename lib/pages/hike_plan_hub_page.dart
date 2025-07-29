// lib/pages/hike_plan_hub_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/hike_plan_model.dart';
import '../widgets/preparation_progress_modal.dart';
import '../services/hike_plan_service.dart';
import '../utils/app_colors.dart';
import '../providers/route_planner_provider.dart';

class HikePlanHubPage extends StatefulWidget {
  final HikePlan initialPlan;
  const HikePlanHubPage({super.key, required this.initialPlan});

  @override
  State<HikePlanHubPage> createState() => _HikePlanHubPageState();
}

class _HikePlanHubPageState extends State<HikePlanHubPage> {
  late HikePlan _currentPlan;
  final HikePlanService _hikePlanService = HikePlanService();
  final ScrollController _scrollController = ScrollController();

  // The TextTheme is no longer a state variable.

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.initialPlan;
    // The TextTheme is NOT initialized here anymore.
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  TextTheme _createAppTextTheme(BuildContext context) {
    final currentTheme = Theme.of(context);
    return GoogleFonts.latoTextTheme(currentTheme.textTheme).copyWith(
      headlineLarge: currentTheme.textTheme.headlineLarge?.copyWith(
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontWeight: FontWeight.w700),
      headlineMedium: currentTheme.textTheme.headlineMedium?.copyWith(
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontWeight: FontWeight.w700),
      headlineSmall: currentTheme.textTheme.headlineSmall?.copyWith(
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontWeight: FontWeight.w600),
      titleLarge: currentTheme.textTheme.titleLarge?.copyWith(
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontWeight: FontWeight.w600),
      titleMedium: currentTheme.textTheme.titleMedium?.copyWith(
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontWeight: FontWeight.w600),
      titleSmall: currentTheme.textTheme.titleSmall?.copyWith(
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontWeight: FontWeight.w500),
      labelLarge: currentTheme.textTheme.labelLarge?.copyWith(
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontWeight: FontWeight.w600),
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
    // **FIXED**: The TextTheme is now created here, where the context is safe to use.
    final appTextTheme = _createAppTextTheme(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          _buildHubSliverAppBar(appTextTheme),
          _buildHubContent(appTextTheme),
        ],
      ),
    );
  }

  // **FIXED**: The method now accepts the TextTheme as a parameter.
  Widget _buildHubContent(TextTheme appTextTheme) {
    bool isPreparationRelevant = _currentPlan.status == HikeStatus.planned ||
        _currentPlan.status == HikeStatus.upcoming ||
        _currentPlan.status == HikeStatus.ongoing;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          const SizedBox(height: 24),
          if (_currentPlan.status == HikeStatus.completed) ...[
            _buildStatusHighlight("Hike completed successfully!",
                Icons.celebration_rounded, Colors.green.shade600, appTextTheme),
            const SizedBox(height: 24),
          ] else if (_currentPlan.status == HikeStatus.cancelled) ...[
            _buildStatusHighlight(
                "This hike has been cancelled.",
                Icons.block_rounded,
                AppColors.errorColor(context),
                appTextTheme),
            const SizedBox(height: 24),
          ],
          if (isPreparationRelevant) ...[
            _buildSectionTitle(
                "Preparation Status", Icons.fact_check_outlined, appTextTheme),
            const SizedBox(height: 8),
            _buildPreparationSection(appTextTheme),
            const SizedBox(height: 32),
          ],
          _buildSectionTitle(
              "Overview", Icons.info_outline_rounded, appTextTheme),
          const SizedBox(height: 8),
          _buildOverviewSection(appTextTheme),
          const SizedBox(height: 32),
          _buildSectionTitle(
              "Planning Tools", Icons.construction_rounded, appTextTheme),
          const SizedBox(height: 16),
          _buildActionDashboard(appTextTheme),
          const SizedBox(height: 32),
          if (_currentPlan.notes != null && _currentPlan.notes!.isNotEmpty) ...[
            _buildSectionTitle(
                "Notes", Icons.sticky_note_2_outlined, appTextTheme),
            const SizedBox(height: 8),
            _buildNotesSection(appTextTheme),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _buildActionDashboard(TextTheme appTextTheme) {
    return Column(
      children: [
        _buildDashboardActionCard(
          title: "Weather Forecast",
          subtitle: "Check the conditions for your trip",
          icon: Icons.thermostat_auto_rounded,
          appTextTheme: appTextTheme,
          onTap: () {
            if (_currentPlan.latitude != null &&
                _currentPlan.longitude != null) {
              GoRouter.of(context).pushNamed('weatherPage',
                  pathParameters: {'planId': _currentPlan.id},
                  extra: _currentPlan);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text(
                    'Location coordinates are required for weather.'),
                backgroundColor: AppColors.errorColor(context),
              ));
            }
          },
        ),
        _buildDashboardActionCard(
          title: "Route Planner",
          subtitle: "View and edit the route map",
          icon: Icons.map_outlined,
          appTextTheme: appTextTheme,
          onTap: () {
            context.read<RoutePlannerProvider>().loadPlan(_currentPlan);
            context.push('/route-planner').then((_) {
              if (mounted) {
                setState(() {
                  _currentPlan = context.read<RoutePlannerProvider>().plan;
                });
              }
            });
          },
        ),
        _buildDashboardActionCard(
          title: "Packing List",
          subtitle: "Manage your gear and essentials",
          icon: Icons.backpack_outlined,
          appTextTheme: appTextTheme,
          onTap: () => GoRouter.of(context).pushNamed('packingListPage',
              pathParameters: {'planId': _currentPlan.id}, extra: _currentPlan),
        ),
        _buildDashboardActionCard(
          title: "Meal Plan",
          subtitle: "Coming soon!",
          icon: Icons.restaurant_menu_outlined,
          appTextTheme: appTextTheme,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Meal Plan feature is under development."))),
          isEnabled: false,
        ),
      ],
    );
  }

  Widget _buildDashboardActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required TextTheme appTextTheme,
    bool isEnabled = true,
  }) {
    final theme = Theme.of(context);
    final color = isEnabled ? theme.colorScheme.primary : theme.disabledColor;

    return Card(
      elevation: 1,
      shadowColor: theme.shadowColor.withOpacity(0.1),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
          child: Row(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: appTextTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: appTextTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (isEnabled)
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 18, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, TextTheme appTextTheme,
      {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon,
              color: iconColor ?? AppColors.primaryColor(context), size: 22),
          const SizedBox(width: 12),
          Text(title, style: appTextTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(TextTheme appTextTheme) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Card(
      elevation: 1,
      color: AppColors.cardColor(context).withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildInfoRow(
                Icons.date_range_outlined,
                '${dateFormat.format(_currentPlan.startDate)}${_currentPlan.endDate != null && _currentPlan.endDate != _currentPlan.startDate ? " – ${dateFormat.format(_currentPlan.endDate!)}" : ""}',
                appTextTheme),
            if (_currentPlan.lengthKm != null &&
                _currentPlan.lengthKm! > 0) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                  Icons.linear_scale_rounded,
                  'Approx. ${_currentPlan.lengthKm?.toStringAsFixed(1)} km',
                  appTextTheme),
            ],
            if (_currentPlan.difficulty != HikeDifficulty.unknown) ...[
              const SizedBox(height: 12),
              _buildDifficultyRow(appTextTheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, TextTheme appTextTheme) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: AppColors.accentColor(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: appTextTheme.bodyLarge?.copyWith(
                color: AppColors.textColor(context).withOpacity(0.9),
              )),
        ),
      ],
    );
  }

  Widget _buildDifficultyRow(TextTheme appTextTheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.speed_rounded,
            size: 20, color: AppColors.accentColor(context)),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
                style: appTextTheme.bodyLarge?.copyWith(
                    color: AppColors.textColor(context).withOpacity(0.9)),
                children: [
                  const TextSpan(text: 'Difficulty: '),
                  TextSpan(
                      text: _currentPlan.difficulty.toShortString(),
                      style: TextStyle(
                          color: _currentPlan.difficulty.getColor(context),
                          fontWeight: FontWeight.bold)),
                ]),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHighlight(
      String message, IconData icon, Color color, TextTheme appTextTheme) {
    return Container(
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
                  style: appTextTheme.titleMedium?.copyWith(color: color))),
        ],
      ),
    );
  }

  Widget _buildPreparationSection(TextTheme appTextTheme) {
    int completed = _currentPlan.completedPreparationItems;
    int total = _currentPlan.totalPreparationItems;
    double progress = total > 0 ? completed / total : 0.0;
    bool allDone = completed == total && total > 0;

    return Card(
      elevation: 2,
      color: AppColors.cardColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openAndUpdatePreparationModal,
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
                          style: appTextTheme.titleMedium)),
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
    );
  }

  Widget _buildNotesSection(TextTheme appTextTheme) {
    return Card(
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
    );
  }

  // **FIXED**: The method now accepts the TextTheme as a parameter.
  SliverAppBar _buildHubSliverAppBar(TextTheme appTextTheme) {
    final theme = Theme.of(context);
    const double expandedHeight = 260.0;
    final bool hasImage =
        _currentPlan.imageUrl != null && _currentPlan.imageUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => GoRouter.of(context).pop(),
        color: Colors.white,
        style: IconButton.styleFrom(
            backgroundColor: Colors.black.withOpacity(0.3)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
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
              Container(color: theme.colorScheme.surfaceVariant),
            if (hasImage)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                child: Container(color: Colors.black.withOpacity(0.25)),
              ),
            Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        theme.scaffoldBackgroundColor.withOpacity(0.5),
                        theme.scaffoldBackgroundColor,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.5, 0.8, 1.0])),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentPlan.hikeName,
                    style: appTextTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        shadows: [
                          const Shadow(
                              blurRadius: 6,
                              offset: Offset(1, 2),
                              color: Colors.black87)
                        ]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.fmd_good_outlined,
                          color: Colors.white.withOpacity(0.9), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentPlan.location,
                          style: appTextTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                const Shadow(
                                    blurRadius: 4,
                                    offset: Offset(1, 1),
                                    color: Colors.black87)
                              ]),
                          overflow: TextOverflow.ellipsis,
                        ),
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
