// lib/pages/notes_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../models/hike_plan_model.dart';
import '../models/post_model.dart';
import '../widgets/hike_plan_card.dart';
import '../widgets/add_hike_plan_form.dart';
import '../services/hike_plan_service.dart';
import '../providers/auth_provider.dart';
import 'hike_plan_hub_page.dart';
import '../widgets/preparation_progress_modal.dart';
import '../widgets/complete_hike_dialog.dart';
import '../widgets/review_hike_card.dart';

// Helper-palvelu postausten hakemiseen
class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, String>> getPostedPlanMap() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return {};

    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('planId', isNotEqualTo: null)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {};
      }

      final Map<String, String> planPostMap = {};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final planId = data['planId'] as String?;
        if (planId != null) {
          planPostMap[planId] = doc.id;
        }
      }
      return planPostMap;
    } catch (e) {
      debugPrint('Error fetching posted plan map: $e');
      return {};
    }
  }
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with TickerProviderStateMixin {
  final HikePlanService _hikePlanService = HikePlanService();
  final PostService _postService = PostService();
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;
  TabController? _tabController;

  final List<Tab> _tabs = <Tab>[
    const Tab(text: 'Plans'),
    const Tab(text: 'Completed'),
  ];

  Stream<List<HikePlan>>? _activePlansStream;
  Stream<List<HikePlan>>? _completedPlansStream;
  Future<Map<String, String>>? _postedPlansMapFuture;

  @override
  void initState() {
    super.initState();
    _slideAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideAnimationController, curve: Curves.easeOutQuart));
    _tabController = TabController(length: _tabs.length, vsync: this);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      _loadData();
    }
    authProvider.addListener(_authListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _slideAnimationController.forward();
    });
  }

  void _authListener() {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      _loadData();
    } else {
      setState(() {
        _activePlansStream = Stream.value([]);
        _completedPlansStream = Stream.value([]);
        _postedPlansMapFuture = Future.value({});
      });
    }
  }

  void _loadData() {
    if (mounted) {
      setState(() {
        _activePlansStream = _hikePlanService.getActiveHikePlans();
        _completedPlansStream = _hikePlanService.getCompletedHikePlans();
        _postedPlansMapFuture = _postService.getPostedPlanMap();
      });
    }
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    _tabController?.dispose();
    Provider.of<AuthProvider>(context, listen: false)
        .removeListener(_authListener);
    super.dispose();
  }

  Future<void> _showCompleteHikeDialog(HikePlan plan) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CompleteHikeDialog(plan: plan),
    );

    if (result != null && mounted) {
      final updatedPlan = plan.copyWith(
        status: HikeStatus.completed,
        notes: result['notes'],
        overallRating: result['rating'],
      );
      try {
        await _hikePlanService.updateHikePlan(updatedPlan);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Congratulations on completing "${plan.hikeName}"!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _openAddHikePlanModal({HikePlan? existingPlan}) async {
    final newOrUpdatedPlanData = await showModalBottomSheet<HikePlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (BuildContext draggableContext,
                ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(draggableContext).scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24.0)),
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24.0)),
                  child: PrimaryScrollController(
                    controller: scrollController,
                    child: AddHikePlanForm(
                      existingPlan: existingPlan,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    if (newOrUpdatedPlanData != null && mounted) {
      try {
        if (existingPlan == null) {
          await _hikePlanService.addHikePlan(newOrUpdatedPlanData);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('New plan "${newOrUpdatedPlanData.hikeName}" added!'),
                backgroundColor: Colors.green[700]),
          );
        } else {
          await _hikePlanService.updateHikePlan(newOrUpdatedPlanData);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Plan "${newOrUpdatedPlanData.hikeName}" updated!'),
                backgroundColor: Colors.blue[700]),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error saving: $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _deleteHikePlan(String planId, String hikeName) async {
    if (!mounted) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete plan?'),
          content:
              Text('Are you sure you want to delete the plan "$hikeName"?'),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        );
      },
    );
    if (confirm == true) {
      try {
        await _hikePlanService.deleteHikePlan(planId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Plan "$hikeName" deleted!'),
              backgroundColor: Colors.red[700]),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error deleting: $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _handleUpdatePreparation(HikePlan planToUpdate) async {
    if (!mounted) return;
    final updatedItemsMap =
        await showPreparationProgressModal(context, planToUpdate);
    if (updatedItemsMap != null && mounted) {
      final updatedPlan =
          planToUpdate.copyWith(preparationItems: updatedItemsMap);
      try {
        await _hikePlanService.updateHikePlan(updatedPlan);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Preparations for "${updatedPlan.hikeName}" updated!'),
            backgroundColor: Colors.teal.shade700,
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error updating preparations: $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _navigateToCreatePost(HikePlan plan) {
    context.push('/create-post', extra: {
      'plan': plan,
      'visibility': PostVisibility.public,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.user?.uid;
    if (_tabController == null && userId != null) {
      _tabController = TabController(length: _tabs.length, vsync: this);
      _loadData();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Log out',
          onPressed: () => authProvider.logout(),
        ),
        title: Hero(
          tag: 'appLogoNotes',
          child: Image.asset('assets/images/white3.png',
              height: 80, fit: BoxFit.contain),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search plans',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Search feature is not implemented yet.')),
              );
            },
          ),
        ],
        bottom: userId == null || _tabController == null
            ? null
            : TabBar(
                controller: _tabController,
                tabs: _tabs,
                indicatorColor: theme.colorScheme.secondary,
                labelColor: theme.colorScheme.secondary,
                unselectedLabelColor:
                    theme.colorScheme.onSurface.withAlpha((255 * 0.7).round()),
              ),
      ),
      body: userId == null || _tabController == null
          ? _buildLoginPromptState(context, theme)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPlansList(context, theme,
                    _activePlansStream ?? Stream.value([]), "No active plans.",
                    isCompletedList: false),
                _buildPlansList(
                    context,
                    theme,
                    _completedPlansStream ?? Stream.value([]),
                    "No completed hikes yet.",
                    isCompletedList: true),
              ],
            ),
      floatingActionButton: userId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openAddHikePlanModal(),
              tooltip: 'Create new hike plan',
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('New Plan'),
              heroTag: 'addHikePlanFab_NotesPage',
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildPlansList(BuildContext context, ThemeData theme,
      Stream<List<HikePlan>> stream, String emptyListMessage,
      {required bool isCompletedList}) {
    return FutureBuilder<Map<String, String>>(
      future: isCompletedList ? _postedPlansMapFuture : Future.value({}),
      builder: (context, postedPlansSnapshot) {
        if (isCompletedList && !postedPlansSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final postedPlansMap = postedPlansSnapshot.data ?? {};

        return SlideTransition(
          position: _slideAnimation,
          child: StreamBuilder<List<HikePlan>>(
            stream: stream,
            builder: (context, plansSnapshot) {
              if (plansSnapshot.connectionState == ConnectionState.waiting &&
                  !plansSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (plansSnapshot.hasError) {
                return Center(
                    child: Text('Error loading plans.\n${plansSnapshot.error}',
                        textAlign: TextAlign.center));
              }
              final List<HikePlan> hikePlans = plansSnapshot.data ?? [];

              if (hikePlans.isEmpty) {
                return _buildEmptyState(context, theme,
                    customMessage: emptyListMessage);
              }

              if (!isCompletedList) {
                hikePlans.sort((a, b) {
                  bool aIsPast =
                      a.endDate != null && a.endDate!.isBefore(DateTime.now());
                  bool bIsPast =
                      b.endDate != null && b.endDate!.isBefore(DateTime.now());
                  if (aIsPast && !bIsPast) return -1;
                  if (!aIsPast && bIsPast) return 1;
                  return a.startDate.compareTo(b.startDate);
                });
              } else {
                hikePlans.sort((a, b) => b.endDate!.compareTo(a.endDate!));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 12.0, bottom: 96.0),
                itemCount: hikePlans.length,
                itemBuilder: (context, index) {
                  final plan = hikePlans[index];
                  final bool isPosted = postedPlansMap.containsKey(plan.id);
                  final String? postId =
                      isPosted ? postedPlansMap[plan.id] : null;

                  if (isCompletedList) {
                    return CompletedHikeCard(
                      plan: plan,
                      isPosted: isPosted,
                      postId: postId,
                      onCreatePost: () => _navigateToCreatePost(plan),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  HikePlanHubPage(initialPlan: plan))),
                    );
                  }

                  final bool isPastDue = plan.endDate != null &&
                      plan.endDate!.isBefore(DateTime.now());

                  if (isPastDue) {
                    return ReviewHikeCard(
                      plan: plan,
                      onComplete: () => _showCompleteHikeDialog(plan),
                    );
                  }

                  return HikePlanCard(
                    key: ValueKey(plan.id),
                    plan: plan,
                    onTap: () async {
                      if (!mounted) return;
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  HikePlanHubPage(initialPlan: plan)));
                    },
                    onEdit: () => _openAddHikePlanModal(existingPlan: plan),
                    onDelete: () => _deleteHikePlan(plan.id, plan.hikeName),
                    onUpdatePreparation: _handleUpdatePreparation,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoginPromptState(BuildContext context, ThemeData theme) {
    final textTheme = theme.textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/login_required.json',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
              repeat: true,
            ),
            const SizedBox(height: 24),
            Text(
              'Sign in to see your plans!',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color:
                    theme.colorScheme.onSurface.withAlpha((255 * 0.9).round()),
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You need to be signed in to view and manage your hiking plans.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color:
                    theme.colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Provider.of<AuthProvider>(context, listen: false).logout();
              },
              icon: const Icon(Icons.login),
              label: const Text('Sign in'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme,
      {String? customMessage}) {
    final textTheme = theme.textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/mountain.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              customMessage ?? 'Your adventure awaits!',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color:
                    theme.colorScheme.onSurface.withAlpha((255 * 0.85).round()),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              customMessage == null || customMessage == "No active plans."
                  ? 'When you create your first hiking plan, it will appear here.'
                  : (customMessage == "No completed hikes yet."
                      ? "When you mark plans as completed, they will show up here."
                      : 'Start by creating a new plan!'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color:
                    theme.colorScheme.onSurface.withAlpha((255 * 0.65).round()),
                height: 1.4,
              ),
            ),
            if (customMessage == null ||
                customMessage == "No active plans.") ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _openAddHikePlanModal(),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create new plan'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class CompletedHikeCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback onCreatePost;
  final VoidCallback onTap;
  final bool isPosted;
  final String? postId;

  const CompletedHikeCard({
    super.key,
    required this.plan,
    required this.onCreatePost,
    required this.onTap,
    required this.isPosted,
    this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleTextStyle = GoogleFonts.poppins(
      fontWeight: FontWeight.w700,
      fontSize: 19,
      color: theme.colorScheme.onSurface,
    );
    final infoRowTextStyle = GoogleFonts.lato(
      color: theme.colorScheme.onSurface.withAlpha((255 * 0.85).round()),
      fontSize: 14,
    );

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: theme.cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        splashColor: theme.colorScheme.primary.withAlpha((255 * 0.1).round()),
        highlightColor:
            theme.colorScheme.primary.withAlpha((255 * 0.05).round()),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.hikeName,
                style: titleTextStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                theme,
                Icons.location_on_outlined,
                plan.location,
                textStyle: infoRowTextStyle,
              ),
              const SizedBox(height: 6),
              if (plan.endDate != null)
                _buildInfoRow(
                  theme,
                  Icons.calendar_month_outlined,
                  "Completed on ${DateFormat.yMMMd().format(plan.endDate!)}",
                  textStyle: infoRowTextStyle,
                ),
              const SizedBox(height: 12),
              if (plan.overallRating != null && plan.overallRating! > 0) ...[
                _buildRatingStars(plan.overallRating!.toDouble(), theme),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildStatusBadge(
                    theme,
                    theme.colorScheme.primary,
                    Icons.check_circle_outline_rounded,
                    'Completed',
                  ),
                  if (isPosted)
                    InkWell(
                      onTap: () {
                        if (postId != null) {
                          // KORJATTU: Käytetään reittiä /post/ yksikössä
                          context.push('/post/$postId');
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: _buildPostedBadge(theme),
                    )
                  else
                    TextButton.icon(
                      onPressed: onCreatePost,
                      icon: Icon(Icons.auto_stories_outlined,
                          size: 20, color: theme.colorScheme.secondary),
                      label: Text(
                        'Share Story',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        backgroundColor: theme.colorScheme.secondary
                            .withAlpha((255 * 0.12).round()),
                      ),
                    )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String text,
      {required TextStyle textStyle}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 17, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingStars(double rating, ThemeData theme) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: Colors.amber.shade700,
          size: 22,
        );
      }),
    );
  }

  Widget _buildStatusBadge(
      ThemeData theme, Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.18).round()),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.lato(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostedBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha((255 * 0.18).round()),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 17, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Text(
            'Posted',
            style: GoogleFonts.lato(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
