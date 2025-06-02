import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
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
      duration: const Duration(milliseconds: 300),
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
      duration: Duration(milliseconds: 400 + (index * 25)),
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

    // Set status bar style based on app bar background color
    final appBarBackgroundColor = theme.colorScheme.surfaceContainer;
    final appBarBrightness =
        ThemeData.estimateBrightnessForColor(appBarBackgroundColor);
    final statusBarIconBrightness = appBarBrightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: appBarBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: AnimationLimiter(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: <Widget>[
              _buildHubSliverAppBar(theme, textTheme, statusBarIconBrightness),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed(
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
                theme, "Preparation", Icons.fact_check_outlined),
            index: animationIndex++),
        _buildAnimatedItem(
            child: _buildPreparationSection(theme, textTheme),
            index: animationIndex++),
        const SizedBox(height: 32),
      ] else if (_currentPlan.status == HikeStatus.completed) ...[
        _buildAnimatedItem(
            child: _buildStatusHighlight(theme, "Hike completed successfully!",
                Icons.celebration_rounded, Colors.green.shade600),
            index: animationIndex++),
        const SizedBox(height: 32),
      ] else if (_currentPlan.status == HikeStatus.cancelled) ...[
        _buildAnimatedItem(
            child: _buildStatusHighlight(theme, "This hike has been cancelled.",
                Icons.block_rounded, theme.colorScheme.error),
            index: animationIndex++),
        const SizedBox(height: 32),
      ],
      if (_currentPlan.notes != null && _currentPlan.notes!.isNotEmpty) ...[
        _buildAnimatedItem(
            child: _buildSectionTitle(
                theme, "Notes", Icons.sticky_note_2_outlined),
            index: animationIndex++),
        _buildAnimatedItem(
            child: _buildNotesSection(theme, textTheme),
            index: animationIndex++),
        const SizedBox(height: 32),
      ],
      _buildAnimatedItem(
          child: _buildSectionTitle(
              theme, "Planning Tools", Icons.category_outlined),
          index: animationIndex++),
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
              childAspectRatio: 1.3,
              children: [
                _buildPlannerGridItem(
                    context, "Weather Forecast", Icons.thermostat_rounded, () {
                  /*TODO*/
                }, Colors.orange.shade300, animationIndex++),
                _buildPlannerGridItem(
                    context, "Packing List", Icons.backpack_rounded, () {
                  /*TODO*/
                }, Colors.orange.shade300, animationIndex++),
                _buildPlannerGridItem(
                    context, "Route Plan", Icons.route_rounded, () {
                  /*TODO*/
                }, Colors.orange.shade300, animationIndex++),
                _buildPlannerGridItem(
                    context, "Meal Plan", Icons.restaurant_rounded, () {
                  /*TODO*/
                }, Colors.orange.shade300, animationIndex++),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 40),
    ];
  }

  Widget _buildHubSliverAppBar(ThemeData theme, TextTheme textTheme,
      Brightness statusBarIconBrightnessForAppBar) {
    final appBarBackgroundColor = theme.colorScheme.surfaceContainer;
    final onAppBarColor = theme.colorScheme.onSurface;

    return SliverAppBar(
      expandedHeight: 160.0,
      floating: false,
      pinned: true,
      stretch: false,
      backgroundColor: appBarBackgroundColor,
      foregroundColor: onAppBarColor,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarIconBrightness: statusBarIconBrightnessForAppBar,
        statusBarBrightness:
            ThemeData.estimateBrightnessForColor(appBarBackgroundColor) ==
                    Brightness.dark
                ? Brightness.light
                : Brightness.dark,
      ),
      shape: Border(
        bottom: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1.0,
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: onAppBarColor, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
        title: Text(
          _currentPlan.hikeName,
          style: textTheme.titleLarge?.copyWith(
            color: onAppBarColor,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        background: Container(
          color: appBarBackgroundColor,
        ),
      ),
    );
  }

  Widget _buildOverviewSection(ThemeData theme, TextTheme textTheme) {
    final dateFormat = DateFormat('d.M.yyyy', 'en_US');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(theme, "Overview", Icons.info_outline_rounded),
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
              'Length: ${_currentPlan.lengthKm?.toStringAsFixed(1)} km'),
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
          Icon(icon, size: 20, color: theme.colorScheme.secondary),
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
          color: theme.cardColor.withOpacity(0.1),
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
                  allDone ? 'All done!' : '$completed/$total items ready',
                  style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      fontSize: 16),
                ),
              ),
              TextButton(
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
                    Text(allDone ? 'View' : 'Edit'),
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
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              allDone
                  ? "Excellent, you're ready to go!"
                  : "Finish your preparations.",
              style: textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8)),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Text(
                "No preparation items defined.",
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
      color: itemColor.withOpacity(0.12),
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

  Widget _buildPlannerActionsGrid(BuildContext context, ThemeData theme) {
    final actions = [
      {
        'title': "Weather Forecast",
        'icon': Icons.thermostat_rounded,
        'onPressed': () {/*TODO*/},
        'color': theme.colorScheme.primary,
        'textColor': theme.colorScheme.onPrimaryContainer
      },
      {
        'title': "Packing List",
        'icon': Icons.backpack_rounded,
        'onPressed': () {/*TODO*/},
        'color': theme.colorScheme.secondary,
        'textColor': theme.colorScheme.onSecondaryContainer
      },
      {
        'title': "Route Plan",
        'icon': Icons.route_rounded,
        'onPressed': () {/*TODO*/},
        'color': theme.colorScheme.tertiary,
        'textColor': theme.colorScheme.onTertiaryContainer
      },
      {
        'title': "Meal Plan",
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
            action['color'] as Color,
            index,
            textColor: action['textColor'] as Color?);
      },
    );
  }
}

// ---- _CustomSliverAppBarDelegate remains as in the previous answer ----
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

    final Brightness delegateStatusBarIconBrightness = (imageUrl.isNotEmpty ||
            ThemeData.estimateBrightnessForColor(theme.colorScheme.primary) ==
                Brightness.dark)
        ? Brightness.light
        : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: delegateStatusBarIconBrightness,
        statusBarBrightness: delegateStatusBarIconBrightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5)),
              errorWidget: (context, url, error) => Container(
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                  theme.colorScheme.surfaceVariant,
                  theme.colorScheme.surfaceContainer,
                ], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                child: Icon(Icons.broken_image_outlined,
                    size: 80,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
              ),
            )
          else
            Container(color: theme.colorScheme.surfaceContainer),
          if (currentBlur > 0.05 && imageUrl.isNotEmpty)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                    sigmaX: currentBlur, sigmaY: currentBlur),
                child: Container(
                    color:
                        Colors.black.withOpacity(currentOverlayOpacity * 0.3)),
              ),
            ),
          if (imageUrl.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.30),
                    Colors.transparent,
                    Colors.black.withOpacity(0.50)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
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
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: imageUrl.isNotEmpty
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    size: 20),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back',
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 20,
            right: 20,
            child: Opacity(
              opacity: titleOpacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    planName,
                    style: textTheme.titleLarge?.copyWith(
                      color: imageUrl.isNotEmpty
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      shadows: imageUrl.isNotEmpty
                          ? [
                              const Shadow(
                                  blurRadius: 4.0,
                                  color: Colors.black54,
                                  offset: Offset(1, 1))
                            ]
                          : null,
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
