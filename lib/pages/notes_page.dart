// lib/pages/notes_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // LISÄTTY
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../models/hike_plan_model.dart';
import '../models/post_model.dart'; // LISÄTTY
import '../widgets/hike_plan_card.dart';
import '../widgets/add_hike_plan_form.dart';
import '../services/hike_plan_service.dart';
import '../providers/auth_provider.dart';
import 'hike_plan_hub_page.dart';
import '../widgets/preparation_progress_modal.dart';
import '../widgets/complete_hike_dialog.dart';
import '../widgets/review_hike_card.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with TickerProviderStateMixin {
  final HikePlanService _hikePlanService = HikePlanService();
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;
  TabController? _tabController;

  final List<Tab> _tabs = <Tab>[
    const Tab(text: 'Plans'),
    const Tab(text: 'Completed'),
  ];

  Stream<List<HikePlan>>? _activePlansStream;
  Stream<List<HikePlan>>? _completedPlansStream;

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
      _loadStreams();
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
      _loadStreams();
    } else {
      setState(() {
        _activePlansStream = Stream.value([]);
        _completedPlansStream = Stream.value([]);
      });
    }
  }

  void _loadStreams() {
    if (mounted) {
      setState(() {
        _activePlansStream = _hikePlanService.getActiveHikePlans();
        _completedPlansStream = _hikePlanService.getCompletedHikePlans();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Congratulations on completing "${plan.hikeName}"!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } catch (e) {
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

  // UUSI METODI: Navigoi postauksen luontisivulle ja välittää suunnitelman.
  void _navigateToCreatePost(HikePlan plan) {
    // Välitetään sekä suunnitelma että oletusnäkyvyys GoRouterin 'extra'-parametrissa.
    // Oletetaan, että reititys on konfiguroitu käsittelemään Map-tyyppistä extraa.
    context.push('/create-post', extra: {
      'plan': plan,
      'visibility': PostVisibility.public, // Oletusarvo, kun luodaan postaus
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.user?.uid;
    if (_tabController == null && userId != null) {
      _tabController = TabController(length: _tabs.length, vsync: this);
      _loadStreams();
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
          child: Image.asset('assets/images/white2.png',
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
                    theme.colorScheme.onSurface.withOpacity(0.7),
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

  // MUUTOS: Lisätty logiikka näyttämään "CompletedHikeCard", kun lista on suoritetuille vaelluksille.
  Widget _buildPlansList(BuildContext context, ThemeData theme,
      Stream<List<HikePlan>> stream, String emptyListMessage,
      {required bool isCompletedList}) {
    return SlideTransition(
      position: _slideAnimation,
      child: StreamBuilder<List<HikePlan>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading plans.\n${snapshot.error}',
                    textAlign: TextAlign.center));
          }
          final List<HikePlan> hikePlans = snapshot.data ?? [];

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
            // Järjestetään suoritetut vaellukset uusimmasta vanhimpaan
            hikePlans.sort((a, b) => b.endDate!.compareTo(a.endDate!));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 12.0, bottom: 96.0),
            itemCount: hikePlans.length,
            itemBuilder: (context, index) {
              final plan = hikePlans[index];

              // MUUTOS TÄSSÄ: Jos lista on suoritetuille vaelluksille, käytä uutta korttia.
              if (isCompletedList) {
                return CompletedHikeCard(
                  plan: plan,
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
                color: theme.colorScheme.onSurface.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You need to be signed in to view and manage your hiking plans.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                color: theme.colorScheme.onSurface.withOpacity(0.85),
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
                color: theme.colorScheme.onSurface.withOpacity(0.65),
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

// UUSI WIDGET: Kortti suoritetulle vaellukselle.
class CompletedHikeCard extends StatelessWidget {
  final HikePlan plan;
  final VoidCallback onCreatePost;
  final VoidCallback onTap;

  const CompletedHikeCard({
    super.key,
    required this.plan,
    required this.onCreatePost,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.hikeName,
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      plan.location,
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCreatePost,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share Your Experience'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
