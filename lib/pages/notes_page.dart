// lib/pages/notes_page.dart
import 'package:flutter/material.dart';
import '../models/hike_plan_model.dart';
import '../widgets/hike_plan_card.dart';
import '../widgets/add_hike_plan_form.dart'; // Tuo lomake

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

    _loadDummyHikePlans();
  }

  void _loadDummyHikePlans() {
    setState(() {
      _hikePlans.addAll([
        HikePlan(
          id: '1',
          hikeName: 'Päiväretki Nuuksioon',
          location: 'Nuuksion kansallispuisto, Espoo',
          startDate: DateTime.now().add(const Duration(days: 7)),
          endDate: DateTime.now().add(const Duration(days: 7, hours: 4)),
          lengthKm: 8.5,
          notes: 'Mukavat eväät mukaan ja kamera käden ulottuville!',
          status: HikeStatus.planned,
        ),
        HikePlan(
          id: '2',
          hikeName: 'Kolin kansallismaisemat',
          location: 'Kolin kansallispuisto, Lieksa',
          startDate: DateTime.now().add(const Duration(days: 30)),
          endDate: DateTime.now().add(const Duration(days: 32)),
          lengthKm: 25.0,
          notes: 'Varaa majoitus etukäteen. Tarkista sääennusteet!',
          status: HikeStatus.planned,
        ),
        HikePlan(
          id: '3',
          hikeName: 'Pallas-Yllästunturi, Hetta-Pallas',
          location: 'Pallas-Yllästunturin kansallispuisto, Lappi',
          startDate: DateTime.now().add(const Duration(days: 90)),
          endDate: DateTime.now().add(const Duration(days: 97)),
          lengthKm: 55.0,
          notes:
              'Kevyt rinkka, hyvät kengät. Varaudu sääolosuhteiden muutoksiin.',
          status: HikeStatus.planned,
        ),
        HikePlan(
          id: '4',
          hikeName: 'Lokale Waldrunde',
          location: 'Kaupin urheilupuisto, Tampere',
          startDate: DateTime.now().subtract(const Duration(days: 10)),
          endDate: DateTime.now().subtract(const Duration(days: 10, hours: 2)),
          lengthKm: 5.0,
          notes: 'Rentouttava iltakävely. Muista ottaa juomapullo mukaan.',
          status: HikeStatus.completed,
        ),
      ]);
      _sortPlans();
    });
  }

  void _sortPlans() {
    _hikePlans.sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  Future<void> _openAddHikePlanModal() async {
    final newPlan = await showModalBottomSheet<HikePlan>(
      context: context,
      isScrollControlled: true, // Tämä mahdollistaa täyskorkean modaalin
      backgroundColor: Colors.transparent, // Pohjan väri
      builder: (BuildContext modalContext) {
        // Otetaan turvallinen alue yläreunasta ja näppäimistön tila huomioon
        final mediaQuery = MediaQuery.of(modalContext);
        final topPadding = mediaQuery.padding.top; // Safe area yläreunassa
        final keyboardHeight =
            mediaQuery.viewInsets.bottom; // Näppäimistön korkeus

        // Lomakkeen maksimikorkeus, jätetään tilaa yläreunaan ja näppäimistölle
        final formMaxHeight = mediaQuery.size.height -
            topPadding -
            keyboardHeight -
            20; // 20px lisämarginaali

        return Padding(
          padding: EdgeInsets.only(
              top: topPadding + 20), // Yläpadding safearean ja lisätilan verran
          child: Container(
            constraints: BoxConstraints(
              maxHeight: formMaxHeight, // Asetetaan maksimikorkeus
              minHeight:
                  mediaQuery.size.height * 0.5, // Minikorkeus varmuuden vuoksi
            ),
            decoration: BoxDecoration(
              color: Theme.of(modalContext).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24.0)),
            ),
            child: const AddHikePlanForm(),
          ),
        );
      },
    );

    if (newPlan != null && mounted) {
      setState(() {
        _hikePlans.add(newPlan);
        _sortPlans();
      });
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddHikePlanModal,
        tooltip: 'Luo uusi vaellussuunnitelma',
        icon: const Icon(Icons.add_road),
        label: const Text('Uusi Suunnitelma'),
        heroTag: 'addHikePlanFab',
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
            Icon(Icons.map_outlined,
                size: 96, color: theme.colorScheme.primary.withOpacity(0.6)),
            const SizedBox(height: 24),
            Text(
              'Ei vaellussuunnitelmia vielä',
              style: textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.9),
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Aloita seikkailusi luomalla ensimmäinen vaellussuunnitelmasi alta!',
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
