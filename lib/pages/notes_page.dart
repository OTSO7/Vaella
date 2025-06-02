// lib/pages/notes_page.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
// import 'package:go_router/go_router.dart'; // GoRouteria ei käytetä tässä suoraan navigaatioon hubiin
import 'package:provider/provider.dart';
import '../models/hike_plan_model.dart';
import '../widgets/hike_plan_card.dart';
import '../widgets/add_hike_plan_form.dart';
import '../services/hike_plan_service.dart';
import '../providers/auth_provider.dart';
import './hike_plan_hub_page.dart'; // UUSI: Tuodaan hub-sivu
import '../widgets/preparation_progress_modal.dart'; // UUSI: Tuodaan modaali

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
      duration: const Duration(milliseconds: 600), // Hieman nopeampi
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05), // Hienovaraisempi aloitus
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeOutQuart));
    _animationController.forward();
  }

  Future<void> _openAddHikePlanModal({HikePlan? existingPlan}) async {
    // ... (tämä metodi pysyy pääosin ennallaan, mutta varmista että palauttaa HikePlan)
    // Varmistetaan, että AddHikePlanForm palauttaa HikePlan-olion
    final newOrUpdatedPlanData = await showModalBottomSheet<HikePlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9, // Hieman korkeampi oletuksena
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24.0)),
              ),
              child: ClipRRect(
                // Lisätty ClipRRect varmistamaan pyöristykset sisällölle
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24.0)),
                child: PrimaryScrollController(
                  // Varmista, että tämä on tarpeen
                  controller: scrollController,
                  child: AddHikePlanForm(
                    existingPlan: existingPlan,
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (newOrUpdatedPlanData != null && mounted) {
      // newOrUpdatedPlanData on nyt HikePlan
      try {
        if (existingPlan == null) {
          // Uusi suunnitelma
          // AddHikePlanForm luo jo ID:n, HikePlanService käyttää sitä
          await _hikePlanService.addHikePlan(newOrUpdatedPlanData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Uusi suunnitelma "${newOrUpdatedPlanData.hikeName}" lisätty!'),
                backgroundColor: Colors.green[700]),
          );
        } else {
          // Olemassa olevan päivitys
          await _hikePlanService.updateHikePlan(newOrUpdatedPlanData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Suunnitelma "${newOrUpdatedPlanData.hikeName}" päivitetty!'),
                backgroundColor: Colors.blue[700]),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Virhe tallennuksessa: $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _deleteHikePlan(String planId, String hikeName) async {
    // ... (tämä metodi pysyy ennallaan)
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Poista suunnitelma?'),
          content: Text('Haluatko varmasti poistaa suunnitelman "$hikeName"?'),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Peruuta')),
            TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('Poista', style: TextStyle(color: Colors.red))),
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
                content: Text('Suunnitelma "$hikeName" poistettu!'),
                backgroundColor: Colors.red[700]),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Virhe poistossa: $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  // UUSI: Metodi valmistautumisen päivitysmodaalin avaamiseen
  Future<void> _handleUpdatePreparation(HikePlan planToUpdate) async {
    final updatedItemsMap =
        await showPreparationProgressModal(context, planToUpdate);

    if (updatedItemsMap != null && mounted) {
      final updatedPlan =
          planToUpdate.copyWith(preparationItems: updatedItemsMap);
      try {
        await _hikePlanService.updateHikePlan(updatedPlan);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Suunnitelman "${updatedPlan.hikeName}" valmistelut päivitetty!'),
              backgroundColor: Colors.teal.shade700, // Käytetään teeman väriä
            ),
          );
        }
        // StreamBuilder päivittää UI:n automaattisesti
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Virhe valmistelujen päivityksessä: $e'),
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
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.user?.uid;

    return Scaffold(
      appBar: AppBar(
        // ... (AppBar ennallaan)
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Log out',
          onPressed: () {
            authProvider.logout();
          },
        ),
        title: Hero(
          tag:
              'appLogoNotes', // Vaihdettu tagi, jotta ei konfliktoi HomePage:n kanssa
          child: Image.asset(
            'assets/images/white2.png', // Varmista, että tämä polku on oikein
            height: 80,
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search hikes',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Search functionality is not implemented yet.')),
              );
            },
          ),
        ],
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
                    print(
                        "Error in StreamBuilder: ${snapshot.error}"); // Lisätty print
                    return Center(
                        child: Text(
                            'Virhe suunnitelmien latauksessa: ${snapshot.error}'));
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
              onPressed: () => _openAddHikePlanModal(),
              tooltip: 'Luo uusi vaellussuunnitelma',
              icon: const Icon(
                  Icons.add_location_alt_outlined), // Vaihdettu ikoni
              label: const Text('Uusi Suunnitelma'), // Suomennettu
              heroTag: 'addHikePlanFab_NotesPage', // Uniikki heroTag
              backgroundColor: theme.colorScheme.secondary, // Teeman mukainen
              foregroundColor: theme.colorScheme.onSecondary,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLoginPromptState(BuildContext context, ThemeData theme) {
    // ... (koodi ennallaan)
    final textTheme = theme.textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/login_required.json', // Varmista, että tämä tiedosto on olemassa
              width: 250,
              height: 250,
              fit: BoxFit.contain,
              repeat: true,
            ),
            const SizedBox(height: 24),
            Text(
              'Kirjaudu nähdäksesi suunnitelmasi!',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sinun tulee olla kirjautuneena sisään nähdäksesi ja hallitaksesi vaellussuunnitelmiasi.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // GoRouter.of(context).go('/login'); // Varmista, että GoRouter on konfiguroitu oikein
                // Jos GoRouter ei ole saatavilla suoraan, käytä AuthProvideria tai muuta navigaatiotapaa
                // Oletetaan, että AuthProvider hoitaa uloskirjautumisen ja GoRouter ohjaa
                // Tässä tapauksessa, jos ei ole kirjautunut, tämä nappi voi ohjata login-sivulle
                // Tämä sivu on jo suojattu reitti, joten tämä tila ei pitäisi olla mahdollinen ilman bugia
                // Mutta jos on, ohjataan login-sivulle.
                // Provider.of<AuthProvider>(context, listen:false).logout(); // Tämä ei ole loogista tässä
                // Yksinkertaisempi:
                Navigator.of(context).pushReplacementNamed(
                    '/login'); // Tai context.go('/login') jos käytät GoRouteria
              },
              icon: const Icon(Icons.login),
              label: const Text('Kirjaudu sisään'),
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

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    // ... (koodi ennallaan)
    final textTheme = theme.textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/mountain.json', // Varmista, että tämä tiedosto on olemassa
              width: 250,
              height: 250,
              fit: BoxFit.contain,
              repeat: true,
            ),
            const SizedBox(height: 24),
            Text(
              'Seikkailusi odottaa!',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
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
              onPressed: () => _openAddHikePlanModal(),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Luo ensimmäinen'),
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
      padding: const EdgeInsets.only(top: 12.0, bottom: 96.0), // Tilaa FAB:lle
      itemCount: hikePlans.length,
      itemBuilder: (context, index) {
        final plan = hikePlans[index];
        return HikePlanCard(
          plan: plan,
          onTap: () {
            // UUSI: Navigoidaan HikePlanHubPage-sivulle
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HikePlanHubPage(initialPlan: plan),
              ),
            ).then((updatedPlanMaybe) {
              // Kun palataan Hub-sivulta, päivitetään tila, jos suunnitelma on muuttunut siellä
              // Tämä vaatii, että HubPage palauttaa päivitetyn suunnitelman, jos se muokkaa sitä
              if (updatedPlanMaybe is HikePlan && mounted) {
                // Päivitä lista tai hae uudelleen. StreamBuilder hoitaa tämän automaattisesti,
                // jos HubPage päivittää Firebasen.
                // Tässä voisi manuaalisesti päivittää paikallista tilaa, jos tarpeen.
                setState(() {
                  final planIndex =
                      hikePlans.indexWhere((p) => p.id == updatedPlanMaybe.id);
                  if (planIndex != -1) {
                    hikePlans[planIndex] = updatedPlanMaybe;
                  }
                });
              }
            });
          },
          onEdit: () => _openAddHikePlanModal(existingPlan: plan),
          onDelete: () => _deleteHikePlan(plan.id, plan.hikeName),
          onUpdatePreparation:
              _handleUpdatePreparation, // UUSI: Välitetään callback
        );
      },
      separatorBuilder: (context, index) =>
          const SizedBox(height: 0), // Ei erotinta, kortit hoitavat marginaalit
    );
  }
}
