// lib/pages/hike_plan_hub_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:ui' as ui;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/hike_plan_model.dart';
import '../widgets/preparation_progress_modal.dart';
import '../services/hike_plan_service.dart';
import '../utils/app_colors.dart'; // Import centralized colors

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

  Widget _buildAnimatedItem(
      {required Widget child, required int index, Duration? duration}) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: duration ?? Duration(milliseconds: 400 + (index * 30)),
      child: SlideAnimation(
        verticalOffset: 40.0,
        curve: Curves.easeOutCubic,
        child: FadeInAnimation(curve: Curves.easeOutCubic, child: child),
      ),
    );
  }

  TextTheme _getAppTextTheme(BuildContext context) {
    final currentTheme = Theme.of(context);
    // Use GoogleFonts.latoTextTheme for base and Poppins for headlines/titles
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

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context);
    final appTextTheme = _getAppTextTheme(context);
    bool isPreparationRelevant = _currentPlan.status == HikeStatus.planned ||
        _currentPlan.status == HikeStatus.upcoming ||
        _currentPlan.status == HikeStatus.ongoing;

    final bool hasImageForAppBar =
        _currentPlan.imageUrl != null && _currentPlan.imageUrl!.isNotEmpty;
    final Brightness statusBarIconBrightness = (hasImageForAppBar ||
            ThemeData.estimateBrightnessForColor(
                    AppColors.primaryColor(context).withOpacity(0.3)) ==
                Brightness.dark)
        ? Brightness.light
        : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: statusBarIconBrightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Theme(
        data: currentTheme.copyWith(textTheme: appTextTheme),
        child: Scaffold(
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor(context).withOpacity(0.3),
                      AppColors.backgroundColor(context),
                      AppColors.backgroundColor(context),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.3, 1.0])),
            child: SafeArea(
              top: false,
              bottom: true,
              child: AnimationLimiter(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: <Widget>[
                    SliverPersistentHeader(
                      pinned: true,
                      floating: false,
                      delegate: HubPageSliverAppBarDelegate(
                        expandedHeight: 220.0,
                        minHeight:
                            kToolbarHeight + MediaQuery.of(context).padding.top,
                        planName: _currentPlan.hikeName,
                        imageUrl: _currentPlan.imageUrl ?? '',
                        currentPlan: _currentPlan,
                        appTextTheme: appTextTheme,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate.fixed(
                            _buildContentWidgetsList(
                                context, appTextTheme, isPreparationRelevant)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContentWidgetsList(BuildContext context,
      TextTheme appTextTheme, bool isPreparationRelevant) {
    int animationIndex = 0;
    final List<Widget> content = [];

    content.add(_buildAnimatedItem(
        child: _buildOverviewSectionNew(context, appTextTheme),
        index: animationIndex++));
    content.add(const SizedBox(height: 24));

    if (isPreparationRelevant) {
      content.add(_buildAnimatedItem(
          child: _buildSectionTitleNew(
              context, "Preparation", Icons.fact_check_outlined, appTextTheme),
          index: animationIndex++));
      content.add(_buildAnimatedItem(
          child: _buildPreparationSectionNew(context, appTextTheme),
          index: animationIndex++));
      content.add(const SizedBox(height: 24));
    } else if (_currentPlan.status == HikeStatus.completed) {
      content.add(_buildAnimatedItem(
          child: _buildStatusHighlightNew(
              context,
              "Hike completed successfully!",
              Icons.celebration_rounded,
              Colors.green.shade600,
              appTextTheme),
          index: animationIndex++));
      content.add(const SizedBox(height: 24));
    } else if (_currentPlan.status == HikeStatus.cancelled) {
      content.add(_buildAnimatedItem(
          child: _buildStatusHighlightNew(
              context,
              "This hike has been cancelled.",
              Icons.block_rounded,
              AppColors.errorColor(context),
              appTextTheme),
          index: animationIndex++));
      content.add(const SizedBox(height: 24));
    }

    if (_currentPlan.notes != null && _currentPlan.notes!.isNotEmpty) {
      content.add(_buildAnimatedItem(
          child: _buildSectionTitleNew(
              context, "Notes", Icons.sticky_note_2_outlined, appTextTheme),
          index: animationIndex++));
      content.add(_buildAnimatedItem(
          child: _buildNotesSectionNew(context, appTextTheme),
          index: animationIndex++));
      content.add(const SizedBox(height: 24));
    }

    content.add(_buildAnimatedItem(
        child: _buildSectionTitleNew(
            context, "Planning Tools", Icons.category_outlined, appTextTheme),
        index: animationIndex++));

    content.add(AnimationConfiguration.staggeredList(
      position: animationIndex++,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50,
        child: FadeInAnimation(
          child: _buildPlannerActionsGridNew(context),
        ),
      ),
    ));
    content.add(const SizedBox(height: 40));

    return content;
  }

  Widget _buildSectionTitleNew(
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
          Text(
            title,
            style: appTextTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSectionNew(
      BuildContext context, TextTheme appTextTheme) {
    final dateFormat = DateFormat('MMM d,yyyy', 'en_US');
    final primaryColor = AppColors.primaryColor(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withOpacity(0.15),
              AppColors.backgroundColor(context).withOpacity(0.2)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRowNew(context, Icons.fmd_good_outlined,
              _currentPlan.location, appTextTheme,
              isHeader: true),
          const SizedBox(height: 12),
          _buildInfoRowNew(
              context,
              Icons.date_range_outlined,
              '${dateFormat.format(_currentPlan.startDate)}${_currentPlan.endDate != null && _currentPlan.endDate != _currentPlan.startDate ? " – ${dateFormat.format(_currentPlan.endDate!)}" : ""}',
              appTextTheme),
          if (_currentPlan.lengthKm != null && _currentPlan.lengthKm! > 0) ...[
            const SizedBox(height: 12),
            _buildInfoRowNew(
                context,
                Icons.linear_scale_rounded,
                'Approx. ${_currentPlan.lengthKm?.toStringAsFixed(1)} km',
                appTextTheme),
          ],
          if (_currentPlan.difficulty != HikeDifficulty.unknown) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.speed_rounded,
                    size: 20, color: AppColors.accentColor(context)),
                const SizedBox(width: 12),
                Expanded(
                    child: RichText(
                  text: TextSpan(
                      style: appTextTheme.bodyLarge?.copyWith(
                          color: AppColors.textColor(context).withOpacity(0.9),
                          height: 1.4),
                      children: [
                        const TextSpan(text: 'Difficulty: '),
                        TextSpan(
                            text: _currentPlan.difficulty.toShortString(),
                            style: TextStyle(
                                color:
                                    _currentPlan.difficulty.getColor(context),
                                fontWeight: FontWeight.w600)),
                      ]),
                )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRowNew(
      BuildContext context, IconData icon, String text, TextTheme appTextTheme,
      {bool isHeader = false}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: isHeader ? 22 : 20,
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
                          fontWeight:
                              isHeader ? FontWeight.w600 : FontWeight.normal,
                          height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildStatusHighlightNew(BuildContext context, String message,
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
                    ?.copyWith(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreparationSectionNew(
      BuildContext context, TextTheme appTextTheme) {
    int completed = _currentPlan.completedPreparationItems;
    int total = _currentPlan.totalPreparationItems;
    double progress = total > 0 ? completed / total : 0.0;
    bool allDone = completed == total && total > 0;
    final cardColor = AppColors.cardColor(context);
    final onCardColor = AppColors.onCardColor(context);
    final primaryActionColor = AppColors.primaryColor(context);
    final secondaryActionColor = AppColors.accentColor(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
          color: cardColor.withOpacity(0.85),
          borderRadius: BorderRadius.circular(18.0),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
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
                      ? 'All items packed!'
                      : '$completed out of $total items checked',
                  style: appTextTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600, color: onCardColor),
                ),
              ),
              TextButton.icon(
                onPressed: _openAndUpdatePreparationModal,
                icon: Icon(
                    allDone
                        ? Icons.checklist_rtl_rounded
                        : Icons.edit_note_rounded,
                    size: 20),
                label: Text(allDone ? 'View List' : 'Update List'),
                style: TextButton.styleFrom(
                    foregroundColor:
                        allDone ? primaryActionColor : secondaryActionColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle:
                        GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor:
                    (allDone ? primaryActionColor : secondaryActionColor)
                        .withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                    allDone ? primaryActionColor : secondaryActionColor),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              allDone
                  ? "You're all set and ready for the adventure!"
                  : "Keep preparing for your hike.",
              style: appTextTheme.bodyMedium
                  ?.copyWith(color: onCardColor.withOpacity(0.8)),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Text(
                "No preparation items defined for this plan yet.",
                style: appTextTheme.bodyMedium?.copyWith(
                    color: onCardColor.withOpacity(0.7),
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesSectionNew(BuildContext context, TextTheme appTextTheme) {
    final cardColor = AppColors.cardColor(context);
    final onCardColor = AppColors.onCardColor(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
          color: cardColor.withOpacity(0.85),
          borderRadius: BorderRadius.circular(18.0),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Text(
        _currentPlan.notes ?? "No notes for this hike.",
        style: appTextTheme.bodyLarge?.copyWith(
          color: onCardColor.withOpacity(
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
    );
  }

  Widget _buildPlannerActionsGridNew(BuildContext context) {
    final primaryColor = AppColors.primaryColor(context);
    final secondaryColor = AppColors.accentColor(context);
    final tertiaryColor = Color.lerp(
        primaryColor,
        AppColors.backgroundColor(context),
        0.6)!; // Using tertiary from app_router
    final onPrimaryContainer =
        AppColors.onPrimaryColor(context); // Now uses onPrimary from AppColors
    final onSecondaryContainer =
        AppColors.onAccentColor(context); // Now uses onAccent from AppColors
    final onTertiaryContainer = AppColors.onCardColor(
        context); // Using onCardColor for tertiary consistency

    final actions = [
      {
        'title': "Weather Forecast",
        'icon': Icons.thermostat_auto_rounded,
        'onPressed': () {
          if (_currentPlan.latitude != null && _currentPlan.longitude != null) {
            GoRouter.of(context).pushNamed('weatherPage',
                pathParameters: {'planId': _currentPlan.id},
                extra: _currentPlan);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text(
                  'Location coordinates are required to show weather.'),
              backgroundColor: AppColors.errorColor(context),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(10),
            ));
          }
        },
        'color': primaryColor,
        'textColor': onPrimaryContainer
      },
      {
        'title': "Packing List",
        'icon': Icons.backpack_outlined,
        'onPressed': () {
          // Navigate to the new PackingListPage
          GoRouter.of(context).pushNamed(
            'packingListPage',
            pathParameters: {'planId': _currentPlan.id},
            extra: _currentPlan,
          );
        },
        'color': primaryColor,
        'textColor': onPrimaryContainer
      },
      {
        'title': "Route Plan",
        'icon': Icons.map_outlined,
        'onPressed': () {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Route Plan: Coming soon!")));
        },
        'color':
            tertiaryColor, // Using tertiary from app_router (deepPurpleAccent.shade200)
        'textColor': AppColors.onCardColor(
            context) // Using onCardColor to ensure readability
      },
      {
        'title': "Meal Plan",
        'icon': Icons.restaurant_menu_outlined,
        'onPressed': () {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Meal Plan: Coming soon!")));
        },
        'color': Color.lerp(secondaryColor, AppColors.backgroundColor(context),
            0.6)!, // Blends accent with background
        'textColor': AppColors.onCardColor(context) // Ensure good contrast
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
          childAspectRatio: 1.2,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return AnimationConfiguration.staggeredGrid(
            columnCount: 2,
            position: index,
            duration: Duration(milliseconds: 300 + (index * 50)),
            child: ScaleAnimation(
              scale: 0.95,
              curve: Curves.easeOutQuart,
              child: FadeInAnimation(
                  curve: Curves.easeOutQuart,
                  child: _buildPlannerGridItemNew(
                    context,
                    action['title'] as String,
                    action['icon'] as IconData,
                    action['onPressed'] as VoidCallback,
                    action['color'] as Color,
                    action['textColor'] as Color?,
                  )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlannerGridItemNew(
      BuildContext context,
      String title,
      IconData icon,
      VoidCallback onPressed,
      Color itemBaseColor,
      Color? textColor) {
    final TextTheme appTextTheme = _getAppTextTheme(context);

    return Material(
      color: itemBaseColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        splashColor: itemBaseColor.withOpacity(0.3),
        highlightColor: itemBaseColor.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: itemBaseColor.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: textColor ?? itemBaseColor),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: appTextTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textColor ??
                        AppColors.onCardColor(context).withOpacity(0.9),
                    fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- New SliverAppBar Delegate using shrinkOffset ---
class HubPageSliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double expandedHeight;
  final double minHeight;
  final String planName;
  final String imageUrl;
  final HikePlan currentPlan;
  final TextTheme appTextTheme;

  HubPageSliverAppBarDelegate({
    required this.expandedHeight,
    required this.minHeight,
    required this.planName,
    required this.imageUrl,
    required this.currentPlan,
    required this.appTextTheme,
  });

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => minHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final bool hasImage = imageUrl.isNotEmpty;
    final double topPadding = MediaQuery.of(context).padding.top;

    final currentHeight = maxExtent - shrinkOffset;
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    final double titleOpacity = 1.0 - progress;
    final double expandedTitleScale = ui.lerpDouble(1.2, 1.0, progress)!;

    double blurSigma = ui.lerpDouble(0, 3, progress)!;
    double imageOverlayOpacity = ui.lerpDouble(0, 0.4, progress)!;

    final Brightness statusBarIconBrightness = (hasImage ||
            ThemeData.estimateBrightnessForColor(
                    AppColors.primaryColor(context).withOpacity(0.3)) ==
                Brightness.dark)
        ? Brightness.light
        : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: statusBarIconBrightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                  color: AppColors.primaryColor(context).withOpacity(0.1)),
              errorWidget: (context, url, error) => Container(
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                  AppColors.primaryColor(context).withOpacity(0.2),
                  AppColors.primaryColor(context).withOpacity(0.1),
                ], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                child: Icon(Icons.image_not_supported_outlined,
                    size: 60, color: AppColors.subtleTextColor(context)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor(context).withOpacity(0.3),
                    AppColors.primaryColor(context).withOpacity(0.15),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          if (hasImage && blurSigma > 0.01)
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                  color: Colors.black.withOpacity(imageOverlayOpacity)),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasImage
                    ? [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                        Colors.black.withOpacity(0.6)
                      ]
                    : [
                        AppColors.primaryColor(context).withOpacity(0.1),
                        Colors.transparent,
                        AppColors.primaryColor(context).withOpacity(0.2)
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: currentHeight > minExtent ? currentHeight : minExtent,
            child: Container(
              padding: EdgeInsets.only(
                bottom: 16.0,
                left: ui.lerpDouble(20, 56 + topPadding * 0.5, progress)!,
                right: ui.lerpDouble(20, 56, progress)!,
              ),
              alignment: Alignment(ui.lerpDouble(-0.8, 0.0, progress)!, 1.0),
              child: Opacity(
                opacity: titleOpacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: expandedTitleScale,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    planName,
                    style: appTextTheme.titleLarge?.copyWith(
                      color: hasImage
                          ? Colors.white
                          : AppColors.textColor(context),
                      fontWeight: FontWeight.bold,
                      shadows: hasImage
                          ? [
                              const Shadow(
                                  blurRadius: 2,
                                  color: Colors.black54,
                                  offset: Offset(1, 1))
                            ]
                          : null,
                    ),
                    textAlign: TextAlign.left,
                    maxLines: currentHeight > minExtent + 20 ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          if (progress == 1.0)
            Positioned(
              top: topPadding,
              left: 56,
              right: 56,
              height: kToolbarHeight,
              child: Center(
                child: Text(
                  planName,
                  style: appTextTheme.titleLarge?.copyWith(
                    color:
                        hasImage ? Colors.white : AppColors.textColor(context),
                    fontWeight: FontWeight.bold,
                    shadows: hasImage
                        ? [
                            const Shadow(
                                blurRadius: 2,
                                color: Colors.black54,
                                offset: Offset(1, 1))
                          ]
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          Positioned(
            top: topPadding,
            left: 8,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color:
                        hasImage ? Colors.white : AppColors.textColor(context),
                    size: 22),
                onPressed: () => GoRouter.of(context).pop(),
                tooltip: 'Back',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(HubPageSliverAppBarDelegate oldDelegate) {
    return expandedHeight != oldDelegate.expandedHeight ||
        minHeight != oldDelegate.minHeight ||
        planName != oldDelegate.planName ||
        imageUrl != oldDelegate.imageUrl ||
        currentPlan != oldDelegate.currentPlan ||
        appTextTheme != oldDelegate.appTextTheme;
  }
}
