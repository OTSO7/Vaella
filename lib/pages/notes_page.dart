import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/hike_plan_model.dart';
import '../widgets/hike_plan_card.dart';
import '../widgets/add_hike_plan_form.dart';
import '../services/hike_plan_service.dart';
import '../providers/auth_provider.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage>
    with SingleTickerProviderStateMixin {
  final HikePlanService _hikePlanService = HikePlanService();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward();
  }

  Future<void> _openAddHikePlanModal({HikePlan? existingPlan}) async {
    final newOrUpdatedPlan = await showModalBottomSheet<HikePlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24.0)),
              ),
              child: PrimaryScrollController(
                controller: scrollController,
                child: AddHikePlanForm(
                  existingPlan: existingPlan,
                ),
              ),
            );
          },
        );
      },
    );

    if (newOrUpdatedPlan != null && mounted) {
      try {
        if (existingPlan == null) {
          await _hikePlanService.addHikePlan(newOrUpdatedPlan);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('New hike plan "${newOrUpdatedPlan.hikeName}" added!'),
              backgroundColor: Colors.green[700],
            ),
          );
        } else {
          await _hikePlanService.updateHikePlan(newOrUpdatedPlan);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Hike plan "${newOrUpdatedPlan.hikeName}" updated!'),
              backgroundColor: Colors.blue[700],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _deleteHikePlan(String planId, String hikeName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete hike?'),
          content:
              Text('Are you sure you want to delete the hike "$hikeName"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _hikePlanService.deleteHikePlan(planId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hike "$hikeName" deleted!'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting hike: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.user?.uid;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: userId == null
            ? _buildLoginPromptState(context, theme)
            : StreamBuilder<List<HikePlan>>(
                stream: _hikePlanService.getHikePlans(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error loading hikes: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState(context, theme);
                  }

                  final List<HikePlan> hikePlans = snapshot.data!;
                  return _buildHikeList(hikePlans);
                },
              ),
      ),
      floatingActionButton: userId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddHikePlanModal,
              tooltip: 'Create a new hike plan',
              icon: const Icon(Icons.add_road),
              label: const Text('New Plan'),
              heroTag: 'addHikePlanFab',
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
              'Sign in to see your hikes!',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You need to be signed in to view and manage your hike plans. Sign in or create a new account.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                GoRouter.of(context).go('/login');
              },
              icon: const Icon(Icons.login),
              label: const Text('Sign in'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                GoRouter.of(context).go('/register');
              },
              child: Text(
                'Create new account',
                style: textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    final textTheme = theme.textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/mountain.json',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
              repeat: true,
            ),
            const SizedBox(height: 24),
            Text(
              'Your adventure awaits!',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'It\'s still empty here! When you create your first hike plan, it will appear here.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openAddHikePlanModal,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create First'),
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

  Widget _buildHikeList(List<HikePlan> hikePlans) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 12.0, bottom: 96.0),
      itemCount: hikePlans.length,
      itemBuilder: (context, index) {
        final plan = hikePlans[index];
        return HikePlanCard(
          plan: plan,
          onTap: () {
            String coords = '';
            if (plan.latitude != null && plan.longitude != null) {
              coords =
                  ' (Coords: ${plan.latitude?.toStringAsFixed(4)}, ${plan.longitude?.toStringAsFixed(4)})';
            }
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Viewing plan: ${plan.hikeName} (${plan.status == HikeStatus.completed ? 'completed' : 'upcoming'})$coords')));
          },
          onEdit: () => _openAddHikePlanModal(existingPlan: plan),
          onDelete: () => _deleteHikePlan(plan.id, plan.hikeName),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 16.0),
    );
  }
}
