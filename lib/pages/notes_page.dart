// lib/pages/notes_page.dart
import 'package:flutter/material.dart';
import '../models/hike_plan_model.dart';
import '../widgets/hike_plan_card.dart';
import '../widgets/add_hike_plan_form.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final List<HikePlan> _hikePlans = []; // Aloitetaan tyhjällä listalla

  @override
  void initState() {
    super.initState();
    // _loadDummyHikePlans(); // Voit kutsua tätä, jos haluat esimerkkidataa aluksi
  }

  // Voit halutessasi lisätä tämän metodin takaisin testidatan luomiseksi
  /*
  void _loadDummyHikePlans() {
    setState(() {
      _hikePlans.addAll([
        HikePlan(
          id: '1',
          hikeName: 'Päiväretki Nuuksioon',
          location: 'Nuuksion kansallispuisto, Espoo',
          startDate: DateTime.now().add(const Duration(days: 7)),
          notes: 'Eväät mukaan!',
        ),
        HikePlan(
          id: '2',
          hikeName: 'Kolin valloitus',
          location: 'Kolin kansallispuisto',
          startDate: DateTime.now().add(const Duration(days: 30)),
          lengthKm: 20,
        ),
      ]);
      _sortPlans();
    });
  }
  */

  void _sortPlans() {
    _hikePlans.sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  Future<void> _openAddHikePlanModal() async {
    final newPlan = await showModalBottomSheet<HikePlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent, // Tehdään modaalin oma tausta näkyväksi
      builder: (BuildContext modalContext) {
        return ClipRRect(
          // Tarvitaan, jotta AddHikePlanFormin pyöristetyt kulmat näkyvät
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
          child: Container(
            // Tämä Container antaa taustavärin ja hallitsee muotoa
            color: Theme.of(modalContext).cardColor, // Käytä teeman korttiväriä
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Omat Vaellussuunnitelmat'),
      ),
      body: _hikePlans.isEmpty
          ? _buildEmptyState(context, theme)
          : _buildHikeList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddHikePlanModal,
        tooltip: 'Luo uusi vaellussuunnitelma',
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Luo uusi'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_add_outlined,
                size: 80, color: theme.colorScheme.primary.withOpacity(0.7)),
            const SizedBox(height: 20),
            Text('Ei suunnitelmia vielä', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'Luo ensimmäinen vaellussuunnitelmasi painamalla plus-nappia!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHikeList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8.0, bottom: 88.0), // Tilaa FABille
      itemCount: _hikePlans.length,
      itemBuilder: (context, index) {
        final plan = _hikePlans[index];
        return HikePlanCard(
          plan: plan,
          onTap: () {
            // Myöhemmin: navigoi suunnitelman tietosivulle
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Tarkastellaan suunnitelmaa: ${plan.hikeName} (tulossa)')));
          },
        );
      },
    );
  }
}
