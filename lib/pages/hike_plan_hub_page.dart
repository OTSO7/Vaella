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

// Extension to provide a short string for HikeStatus enum
extension HikeStatusExtension on HikeStatus {
  String toShortString() {
    return toString().split('.').last.replaceAll('_', ' ').replaceFirstMapped(
        RegExp(r'^[a-z]'), (match) => match.group(0)!.toUpperCase());
  }
}

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

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.initialPlan;
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
          fontWeight: FontWeight.w800),
      headlineMedium: currentTheme.textTheme.headlineMedium?.copyWith(
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontWeight: FontWeight.w700),
      headlineSmall: currentTheme.textTheme.headlineSmall?.copyWith(
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontWeight: FontWeight.w600),
      titleLarge: currentTheme.textTheme.titleLarge?.copyWith(
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontWeight: FontWeight.w700),
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
    final appTextTheme = _createAppTextTheme(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildHeroHeader(appTextTheme),
          SliverToBoxAdapter(child: _buildMainContent(appTextTheme, theme)),
        ],
      ),
      // quick action button removed
    );
  }

  Widget _buildHeroHeader(TextTheme appTextTheme) {
    final theme = Theme.of(context);
    final bool hasImage =
        _currentPlan.imageUrl != null && _currentPlan.imageUrl!.isNotEmpty;
    final dateFormat = DateFormat('MMM d, yyyy');

    return SliverAppBar(
      expandedHeight: 320,
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
              Container(color: theme.colorScheme.surfaceContainerHighest),
            if (hasImage)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                child: Container(color: Colors.black.withOpacity(0.22)),
              ),
            Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Colors.transparent,
                        theme.scaffoldBackgroundColor.withOpacity(0.7),
                        theme.scaffoldBackgroundColor,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.5, 0.8, 1.0])),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentPlan.hikeName,
                      style: appTextTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 30,
                        shadows: [
                          const Shadow(
                              blurRadius: 10,
                              offset: Offset(1, 2),
                              color: Colors.black87)
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.fmd_good_outlined,
                            color: Colors.white.withOpacity(0.92), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentPlan.location,
                            style: appTextTheme.titleMedium?.copyWith(
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                              shadows: [
                                const Shadow(
                                    blurRadius: 6,
                                    offset: Offset(1, 1),
                                    color: Colors.black87)
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.date_range_rounded,
                            color: Colors.white.withOpacity(0.92), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${dateFormat.format(_currentPlan.startDate)}'
                          '${_currentPlan.endDate != null && _currentPlan.endDate != _currentPlan.startDate ? " – ${dateFormat.format(_currentPlan.endDate!)}" : ""}',
                          style: appTextTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.93),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_currentPlan.lengthKm != null &&
                            _currentPlan.lengthKm! > 0) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.linear_scale_rounded,
                              color: Colors.white.withOpacity(0.92), size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${_currentPlan.lengthKm?.toStringAsFixed(1)} km',
                            style: appTextTheme.bodyLarge?.copyWith(
                              color: Colors.white.withOpacity(0.93),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(TextTheme appTextTheme, ThemeData theme) {
    bool isPreparationRelevant = _currentPlan.status == HikeStatus.planned ||
        _currentPlan.status == HikeStatus.upcoming ||
        _currentPlan.status == HikeStatus.ongoing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status chip
        Padding(
          padding: const EdgeInsets.only(top: 18, left: 24, right: 24),
          child: Row(
            children: [
              _buildStatusChip(_currentPlan.status, theme),
              const Spacer(),
              if (_currentPlan.status == HikeStatus.completed)
                const Icon(Icons.celebration_rounded,
                    color: Colors.green, size: 28),
              if (_currentPlan.status == HikeStatus.cancelled)
                Icon(Icons.block_rounded,
                    color: AppColors.errorColor(context), size: 28),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Preparation Progress
        if (isPreparationRelevant)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildPreparationCard(appTextTheme, theme),
          ),
        if (isPreparationRelevant) const SizedBox(height: 24),

        // Dashboard
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildDashboardGrid(appTextTheme, theme),
        ),
        const SizedBox(height: 30),

        // Notes
        if (_currentPlan.notes != null && _currentPlan.notes!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildNotesCard(appTextTheme, theme),
          ),
        if (_currentPlan.notes != null && _currentPlan.notes!.isNotEmpty)
          const SizedBox(height: 30),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildStatusChip(HikeStatus status, ThemeData theme) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case HikeStatus.completed:
        color = Colors.green.shade600;
        label = "Completed";
        icon = Icons.check_circle_rounded;
        break;
      case HikeStatus.cancelled:
        color = AppColors.errorColor(context);
        label = "Cancelled";
        icon = Icons.block_rounded;
        break;
      case HikeStatus.ongoing:
        color = Colors.orange.shade700;
        label = "Ongoing";
        icon = Icons.directions_walk_rounded;
        break;
      case HikeStatus.upcoming:
        color = Colors.blue.shade600;
        label = "Upcoming";
        icon = Icons.schedule_rounded;
        break;
      default:
        color = theme.colorScheme.primary;
        label = "Planned";
        icon = Icons.flag_rounded;
    }
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(label,
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildPreparationCard(TextTheme appTextTheme, ThemeData theme) {
    int completed = _currentPlan.completedPreparationItems;
    int total = _currentPlan.totalPreparationItems;
    double progress = total > 0 ? completed / total : 0.0;
    bool allDone = completed == total && total > 0;

    return Card(
      elevation: 3,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      // POISTETTU OUTLINE: ei borderia Cardissa eikä InkWellissä
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openAndUpdatePreparationModal,
        splashColor: theme.colorScheme.primary.withOpacity(0.08),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.13),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary),
                    ),
                  ),
                  Icon(
                    allDone ? Icons.verified_rounded : Icons.fact_check_rounded,
                    color: allDone
                        ? Colors.green.shade700
                        : theme.colorScheme.primary,
                    size: 32,
                  ),
                ],
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allDone
                          ? "All preparation done!"
                          : "Preparation in progress",
                      style: appTextTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Tap to view or update your checklist",
                      style: appTextTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(TextTheme appTextTheme, ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 18,
      crossAxisSpacing: 18,
      childAspectRatio: 1.18,
      children: [
        _dashboardTile(
          icon: Icons.thermostat_auto_rounded,
          color: Colors.orange.shade400,
          title: "Weather",
          subtitle: "Forecast & conditions",
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
        _dashboardTile(
          icon: Icons.map_outlined,
          color: Colors.blue.shade400,
          title: "Route Planner",
          subtitle: "View & edit map",
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
        _dashboardTile(
          icon: Icons.backpack_outlined,
          color: Colors.green.shade400,
          title: "Packing List",
          subtitle: "Gear & essentials",
          onTap: () => GoRouter.of(context).pushNamed('packingListPage',
              pathParameters: {'planId': _currentPlan.id}, extra: _currentPlan),
        ),
        // KORJATTU: Meal Plan -nappi otettu käyttöön
        _dashboardTile(
          icon: Icons.restaurant_menu_outlined,
          color: Colors.purple.shade400,
          title: "Meal Plan",
          subtitle: "Foods & nutrition",
          onTap: () {
            context.pushNamed('foodPlannerPage',
                pathParameters: {'planId': _currentPlan.id},
                extra: _currentPlan);
          },
          enabled: true,
        ),
      ],
    );
  }

  Widget _dashboardTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Material(
      color: enabled ? color.withOpacity(0.09) : Colors.grey.withOpacity(0.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.18),
                radius: 26,
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16.5,
                  color: enabled ? color : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.lato(
                  fontSize: 13.5,
                  color: enabled ? color.withOpacity(0.8) : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesCard(TextTheme appTextTheme, ThemeData theme) {
    return Card(
      elevation: 1,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sticky_note_2_outlined,
                color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _currentPlan.notes ?? "No notes for this hike.",
                style: appTextTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.95),
                  height: 1.5,
                  fontStyle: _currentPlan.notes != null &&
                          _currentPlan.notes!.isNotEmpty
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
