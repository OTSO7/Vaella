import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/hike_plan_model.dart';
import '../widgets/hike_plan_card.dart';
import '../widgets/add_hike_plan_form.dart';
import '../services/hike_plan_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart'; // Lisää GoRouter-importti

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
              content: Text(
                  'Uusi vaellussuunnitelma "${newOrUpdatedPlan.hikeName}" lisätty!'),
              backgroundColor: Colors.green[700],
            ),
          );
        } else {
          await _hikePlanService.updateHikePlan(newOrUpdatedPlan);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Vaellussuunnitelma "${newOrUpdatedPlan.hikeName}" päivitetty!'),
              backgroundColor: Colors.blue[700],
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Virhe: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _deleteHikePlan(String planId, String hikeName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Poista vaellus?'),
          content: Text('Haluatko varmasti poistaa vaelluksen "$hikeName"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Peruuta'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Poista', style: TextStyle(color: Colors.red)),
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
              content: Text('Vaellus "$hikeName" poistettu!'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Virhe poistettaessa vaellusta: $e'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Omat Suunnitelmat',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: Consumer<AuthProvider>(
          // Käytetään Consumeria kuuntelemaan AuthProviderin tilaa
          builder: (context, authProvider, child) {
            final userId =
                authProvider.user?.uid; // Käytä AuthProviderin user ID:tä

            if (userId == null) {
              return _buildLoginPromptState(
                  context, theme); // Näytä kehote, jos ei kirjautunut
            } else {
              return StreamBuilder<List<HikePlan>>(
                stream: _hikePlanService.getHikePlans(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text(
                            'Virhe ladattaessa vaelluksia: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState(context, theme);
                  }

                  final List<HikePlan> hikePlans = snapshot.data!;
                  return _buildHikeList(hikePlans);
                },
              );
            }
          },
        ),
      ),
      floatingActionButton: Consumer<AuthProvider>(
        // FAB myös riippuvainen kirjautumistilasta
        builder: (context, authProvider, child) {
          if (authProvider.user == null) {
            return const SizedBox
                .shrink(); // Piilota FAB, jos käyttäjä ei ole kirjautunut
          }
          return FloatingActionButton.extended(
            onPressed: _openAddHikePlanModal,
            tooltip: 'Luo uusi vaellussuunnitelma',
            icon: const Icon(Icons.add_road),
            label: const Text('Uusi Suunnitelma'),
            heroTag: 'addHikePlanFab',
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
              'Seikkailusi odottaa!',
              style: textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Täällä on vielä tyhjää! Kun luot ensimmäisen vaellussuunnitelmasi, se ilmestyy tänne.',
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
              label: const Text('Luo Ensimmäinen'),
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

  Widget _buildLoginPromptState(BuildContext context, ThemeData theme) {
    final textTheme = theme.textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/login_required.json', // Käytä sopivaa Lottie-animaatiota tai lisää sellainen
              width: 250,
              height: 250,
              fit: BoxFit.contain,
              repeat: true,
            ),
            const SizedBox(height: 24),
            Text(
              'Kirjaudu sisään nähdäksesi vaelluksesi!',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sinun täytyy olla kirjautuneena sisään nähdäksesi ja hallitaksesi vaellussuunnitelmiasi. Kirjaudu sisään tai luo uusi tili.',
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
              label: const Text('Kirjaudu sisään'),
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
                'Luo uusi tili',
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

  Widget _buildHikeList(List<HikePlan> hikePlans) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12.0, bottom: 96.0),
      itemCount: hikePlans.length,
      itemBuilder: (context, index) {
        final plan = hikePlans[index];
        return HikePlanCard(
          plan: plan,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Tarkastellaan suunnitelmaa: ${plan.hikeName} (${plan.status == HikeStatus.completed ? 'suoritettu' : 'tulossa'})')));
          },
          onEdit: () => _openAddHikePlanModal(existingPlan: plan),
          onDelete: () => _deleteHikePlan(plan.id, plan.hikeName),
        );
      },
    );
  }
}
