// Revolutionary Modern Hike Plan Hub - Clean Implementation
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/hike_plan_model.dart';
import '../providers/auth_provider.dart';

class ModernHikePlanHubPage extends StatefulWidget {
  final HikePlan initialPlan;
  const ModernHikePlanHubPage({super.key, required this.initialPlan});

  @override
  State<ModernHikePlanHubPage> createState() => _ModernHikePlanHubPageState();
}

class _ModernHikePlanHubPageState extends State<ModernHikePlanHubPage>
    with TickerProviderStateMixin {
  late HikePlan _plan;
  List<String> _participantIds = [];
  bool _isInitialized = false;
  bool _isGroupPlan = false;

  // Enhanced group navigation with tabs
  TabController? _tabController;
  AnimationController? _animationController;
  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    _updateParticipantIds();
    _initializeGroupNavigation();

    // Defer initialization to avoid flickering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only update participants after initialization to prevent flickering
    if (_isInitialized) {
      _updateParticipantIds();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  void _initializeGroupNavigation() {
    if (_participantIds.length > 1) {
      _tabController = TabController(
        length: 3, // Overview, Coordination, Members
        vsync: this,
      );
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      _animationController!.forward();
    }
  }

  void _updateParticipantIds() {
    final authProvider = context.read<AuthProvider>();
    final me = authProvider.userProfile;
    final newIds = <String>{
      if (_plan.collabOwnerId != null && _plan.collabOwnerId!.isNotEmpty)
        _plan.collabOwnerId!,
      ..._plan.collaboratorIds,
      if (me != null && me.uid.isNotEmpty) me.uid,
    }.toList();

    final wasGroupPlan = _participantIds.length > 1;
    final isGroupPlan = newIds.length > 1;

    _participantIds = newIds;
    _isGroupPlan = isGroupPlan;

    // Reinitialize navigation if group status changed
    if (wasGroupPlan != isGroupPlan) {
      _tabController?.dispose();
      _animationController?.dispose();
      _initializeGroupNavigation();
    }
  }

  String _dateRangeString(DateTime start, DateTime? end) {
    if (end == null || DateUtils.isSameDay(start, end)) {
      return DateFormat('d.M.yyyy').format(start);
    }
    final sameYear = start.year == end.year;
    final sameMonth = sameYear && start.month == end.month;
    if (sameMonth) {
      return '${DateFormat('d').format(start)}–${DateFormat('d.M.yyyy').format(end)}';
    } else if (sameYear) {
      return '${DateFormat('d.M').format(start)}–${DateFormat('d.M.yyyy').format(end)}';
    }
    return '${DateFormat('d.M.yyyy').format(start)}–${DateFormat('d.M.yyyy').format(end)}';
  }

  Future<void> _openWeather() async {
    context.go('/hike-plan-edit/${_plan.id}/weather');
  }

  Future<void> _openPlanner() async {
    context.go('/hike-plan-edit/${_plan.id}/route-planner');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Show loading screen until initialized to prevent flickering
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Watch for auth changes but use cached state to avoid flickering
    context.watch<AuthProvider>();

    if (_isGroupPlan) {
      // Revolutionary group collaboration interface
      return _buildModernGroupInterface(cs, _participantIds);
    } else {
      // Individual plan interface
      return _buildIndividualInterface(cs);
    }
  }

  Widget _buildModernGroupInterface(
      ColorScheme cs, List<String> participantIds) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: cs.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildGroupHeroHeader(cs, participantIds),
            ),
            bottom: _tabController != null
                ? _ModernTabBarDelegate(
                    tabController: _tabController!,
                    colorScheme: cs,
                  )
                : null,
          ),
        ],
        body: _tabController != null
            ? TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(cs, participantIds),
                  _buildCoordinationTab(cs, participantIds),
                  _buildMembersTab(cs, participantIds),
                ],
              )
            : const SizedBox(),
      ),
    );
  }

  Widget _buildIndividualInterface(ColorScheme cs) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_plan.hikeName),
        backgroundColor: cs.surface,
      ),
      body: const Center(
        child: Text('Individual Plan Interface'),
      ),
    );
  }

  // Revolutionary group hero header
  Widget _buildGroupHeroHeader(ColorScheme cs, List<String> participantIds) {
    final dateRange = _dateRangeString(_plan.startDate, _plan.endDate);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.primaryContainer.withOpacity(0.8),
            cs.surface,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),

          // Group info overlay
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildGroupInfoCard(cs, participantIds, dateRange),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupInfoCard(
      ColorScheme cs, List<String> participantIds, String dateRange) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _plan.hikeName,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
              if (_plan.location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _plan.location,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(dateRange, Icons.calendar_today_rounded),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                      '${participantIds.length} hikers', Icons.group_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Tab content builders
  Widget _buildOverviewTab(ColorScheme cs, List<String> participantIds) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group readiness
          _buildGroupReadinessCard(cs, participantIds),
          const SizedBox(height: 20),

          // Quick actions
          _buildQuickActionsGrid(cs),
          const SizedBox(height: 20),

          // Activity feed
          _buildActivityFeed(cs),
        ],
      ),
    );
  }

  Widget _buildCoordinationTab(ColorScheme cs, List<String> participantIds) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group Coordination Hub',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 20),

          // Gear coordination matrix
          _buildGearCoordinationMatrix(cs, participantIds),
          const SizedBox(height: 20),

          // Food coordination
          _buildFoodCoordination(cs, participantIds),
          const SizedBox(height: 20),

          // Logistics management
          _buildLogisticsManagement(cs, participantIds),
        ],
      ),
    );
  }

  Widget _buildMembersTab(ColorScheme cs, List<String> participantIds) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team Members',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          ...participantIds
              .map((id) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildEnhancedParticipantCard(cs, id),
                  ))
              .toList(),
        ],
      ),
    );
  }

  // Revolutionary coordination components
  Widget _buildGroupReadinessCard(ColorScheme cs, List<String> participantIds) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group Readiness',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Progress indicators
          Row(
            children: [
              Expanded(
                child:
                    _buildReadinessIndicator(cs, 'Packing', 0.8, Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildReadinessIndicator(
                    cs, 'Planning', 0.6, Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    _buildReadinessIndicator(cs, 'Logistics', 0.4, Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessIndicator(
      ColorScheme cs, String label, double progress, Color color) {
    return Column(
      children: [
        CircularProgressIndicator(
          value: progress,
          backgroundColor: cs.outline.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          '${(progress * 100).toInt()}%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                cs,
                'Weather',
                'Check forecast',
                Icons.cloud_rounded,
                Colors.blue,
                _openWeather,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                cs,
                'Route',
                'Plan path',
                Icons.route_rounded,
                Colors.green,
                _openPlanner,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    ColorScheme cs,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityFeed(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withOpacity(0.2)),
          ),
          child: const Text('No recent activity'),
        ),
      ],
    );
  }

  // Revolutionary gear coordination matrix
  Widget _buildGearCoordinationMatrix(
      ColorScheme cs, List<String> participantIds) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gear Coordination Matrix',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Matrix grid
          _buildGearMatrix(cs, participantIds),
        ],
      ),
    );
  }

  Widget _buildGearMatrix(ColorScheme cs, List<String> participantIds) {
    final gearCategories = ['Shelter', 'Cooking', 'Navigation', 'Safety'];

    return Table(
      border: TableBorder.all(color: cs.outline.withOpacity(0.2)),
      children: [
        // Header row
        TableRow(
          decoration:
              BoxDecoration(color: cs.primaryContainer.withOpacity(0.3)),
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child:
                  Text('Gear', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...participantIds
                .take(3)
                .map((id) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('User ${id.substring(0, 3)}...',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ],
        ),

        // Category rows
        ...gearCategories
            .map((category) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(category),
                    ),
                    ...participantIds
                        .take(3)
                        .map((id) => Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                math.Random().nextBool()
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: math.Random().nextBool()
                                    ? Colors.green
                                    : cs.outline,
                                size: 20,
                              ),
                            ))
                        .toList(),
                  ],
                ))
            .toList(),
      ],
    );
  }

  Widget _buildFoodCoordination(ColorScheme cs, List<String> participantIds) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Food Coordination',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Meal assignments and shared cooking duties',
            style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
          ),
          const SizedBox(height: 12),

          // Meal cards
          _buildMealCard(cs, 'Day 1 Breakfast', 'John'),
          const SizedBox(height: 8),
          _buildMealCard(cs, 'Day 1 Dinner', 'Sarah'),
          const SizedBox(height: 8),
          _buildMealCard(cs, 'Day 2 Breakfast', 'Mike'),
        ],
      ),
    );
  }

  Widget _buildMealCard(ColorScheme cs, String meal, String assignee) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.restaurant, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child:
                Text(meal, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Text(
            assignee,
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsManagement(
      ColorScheme cs, List<String> participantIds) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Logistics Management',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Meeting point
          _buildLogisticsItem(
              cs, 'Meeting Point', 'Trailhead Parking', Icons.location_on),
          const SizedBox(height: 12),

          // Transportation
          _buildLogisticsItem(
              cs, 'Transportation', '2 cars needed', Icons.directions_car),
          const SizedBox(height: 12),

          // Emergency contact
          _buildLogisticsItem(
              cs, 'Emergency Contact', 'Set up', Icons.emergency),
        ],
      ),
    );
  }

  Widget _buildLogisticsItem(
      ColorScheme cs, String title, String detail, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                detail,
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedParticipantCard(ColorScheme cs, String participantId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: cs.primaryContainer,
            child: Text(
              participantId.substring(0, 2).toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User ${participantId.substring(0, 8)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Ready to hike!',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.message, color: cs.primary),
          ),
        ],
      ),
    );
  }
}

// Custom tab bar delegate for modern interface
class _ModernTabBarDelegate extends StatelessWidget
    implements PreferredSizeWidget {
  final TabController tabController;
  final ColorScheme colorScheme;

  const _ModernTabBarDelegate({
    required this.tabController,
    required this.colorScheme,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.surface,
      child: TabBar(
        controller: tabController,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Coordination'),
          Tab(text: 'Members'),
        ],
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
        indicatorColor: colorScheme.primary,
      ),
    );
  }
}
