// lib/pages/notes_page.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/hike_plan_model.dart';
import '../widgets/hike_plan_card.dart';
import '../widgets/add_hike_plan_form.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage>
    with SingleTickerProviderStateMixin {
  final List<HikePlan> _hikePlans = [];
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

  void _sortPlans() {
    _hikePlans.sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  Future<void> _openAddHikePlanModal() async {
    final newPlan = await showModalBottomSheet<HikePlan>(
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
                child: const AddHikePlanForm(),
              ),
            );
          },
        );
      },
    );

    if (newPlan != null && mounted) {
      setState(() {
        _hikePlans.add(newPlan);
        _sortPlans();
      });
      // Varmista, että FloatingActionButton päivittyy, kun tila muuttuu
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Uusi vaellussuunnitelma "${newPlan.hikeName}" lisätty!'),
          backgroundColor: Colors.green[700],
        ),
      );
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
        child: _hikePlans.isEmpty
            ? _buildEmptyState(context, theme)
            : _buildHikeList(),
      ),
      floatingActionButton: _hikePlans.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _openAddHikePlanModal,
              tooltip: 'Luo uusi vaellussuunnitelma',
              icon: const Icon(Icons.add_road),
              label: const Text('Uusi Suunnitelma'),
              heroTag: 'addHikePlanFab',
            )
          : null, // Jos lista on tyhjä, FAB on null ja piilossa
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

  Widget _buildHikeList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12.0, bottom: 96.0),
      itemCount: _hikePlans.length,
      itemBuilder: (context, index) {
        final plan = _hikePlans[index];
        return HikePlanCard(
          plan: plan,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Tarkastellaan suunnitelmaa: ${plan.hikeName} (tulossa)')));
          },
        );
      },
    );
  }
}
