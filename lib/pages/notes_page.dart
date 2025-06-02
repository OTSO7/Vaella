// lib/pages/notes_page.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../models/hike_plan_model.dart';
import '../widgets/hike_plan_card.dart';
import '../widgets/add_hike_plan_form.dart';
import '../services/hike_plan_service.dart';
import '../providers/auth_provider.dart';
import './hike_plan_hub_page.dart';
import '../widgets/preparation_progress_modal.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with TickerProviderStateMixin {
  final HikePlanService _hikePlanService = HikePlanService();
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;
  // KORJATTU: Käytetään nullable tyyppiä ja alustetaan initState:ssa
  TabController? _tabController;

  final List<Tab> _tabs = <Tab>[
    const Tab(text: 'Suunnitelmat'),
    const Tab(text: 'Suoritetut'),
  ];

  Stream<List<HikePlan>>? _activePlansStream;
  Stream<List<HikePlan>>? _completedPlansStream;

  @override
  void initState() {
    super.initState(); // KRIITTINEN: super.initState() ensin!
    _slideAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideAnimationController, curve: Curves.easeOutQuart));

    // Alustetaan TabController vasta, kun tiedetään käyttäjän tila
    // tai siirretään alustus kohtaan, jossa userId on varmasti saatavilla.
    // Parempi: Alusta se tässä ja päivitä streamit _onAuthChanged-metodissa.
    _tabController = TabController(length: _tabs.length, vsync: this);

    // Kuunnellaan AuthProviderin muutoksia streamien päivittämiseksi
    // Tämä on jo HomePage:ssa, mutta NotesPage on erillinen, joten tarvitsee oman logiikan
    // tai parempi tapa olisi välittää userId Providerista suoraan build-metodiin.
    // Tässä oletetaan, että AuthProvider on jo alustettu.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      _loadStreams();
    }
    // Lisätään listener auth-tilan muutoksille, jos se voi muuttua tämän sivun ollessa auki
    authProvider.addListener(_authListener);

    // Ajetaan animaatio vasta, kun widget on rakennettu kerran
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
      // Tyhjennä streamit, jos käyttäjä kirjautuu ulos
      setState(() {
        _activePlansStream = Stream.value([]);
        _completedPlansStream = Stream.value([]);
      });
    }
  }

  void _loadStreams() {
    // Varmista, että _hikePlanService on alustettu ja userId on saatavilla
    // Tämä voidaan tehdä turvallisemmin, jos getUserId ei ole riippuvainen _auth.currentUser suoraan
    // vaan AuthProviderin tilasta. Oletetaan, että AuthProvider on jo päivittynyt.
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
    _tabController?.dispose(); // KORJATTU: Lisätty null-tarkistus
    Provider.of<AuthProvider>(context, listen: false)
        .removeListener(_authListener); // Poista listener
    super.dispose();
  }

  Future<void> _openAddHikePlanModal({HikePlan? existingPlan}) async {
    final newOrUpdatedPlanData = await showModalBottomSheet<HikePlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        // Käytä modalContextia modaalin sisällä
        return Padding(
          // Lisätty Padding näppäimistön varalle
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
                content: Text(
                    'Uusi suunnitelma "${newOrUpdatedPlanData.hikeName}" lisätty!'),
                backgroundColor: Colors.green[700]),
          );
        } else {
          await _hikePlanService.updateHikePlan(newOrUpdatedPlanData);
          if (!mounted) return;
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
    if (!mounted) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        // Käytä dialogContextia
        return AlertDialog(
          title: const Text('Poista suunnitelma?'),
          content: Text('Haluatko varmasti poistaa suunnitelman "$hikeName"?'),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Peruuta')),
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child:
                    const Text('Poista', style: TextStyle(color: Colors.red))),
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
              content: Text('Suunnitelma "$hikeName" poistettu!'),
              backgroundColor: Colors.red[700]),
        );
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
            content: Text(
                'Suunnitelman "${updatedPlan.hikeName}" valmistelut päivitetty!'),
            backgroundColor: Colors.teal.shade700,
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Virhe valmistelujen päivityksessä: $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.user?.uid;

    // Varmista, että _tabController on alustettu ennen kuin sitä käytetään
    if (_tabController == null && userId != null) {
      // Tämä on hätävara, _tabController pitäisi alustaa initStatessa
      // tai _loadStreams-metodissa sen jälkeen, kun userId on varmistettu.
      // Parempi tapa on, että build-metodi ei yritä käyttää _tabControlleria, jos userId on null.
      _tabController = TabController(length: _tabs.length, vsync: this);
      _loadStreams(); // Ladataan streamit, jos ne eivät ole vielä latautuneet
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Kirjaudu ulos',
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
            tooltip: 'Hae suunnitelmia',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Hakuominaisuus ei ole vielä toteutettu.')),
              );
            },
          ),
        ],
        bottom: userId == null ||
                _tabController ==
                    null // Näytä TabBar vain jos käyttäjä kirjautunut JA controller alustettu
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
      body: userId == null ||
              _tabController ==
                  null // KORJATTU: Näytä login-prompt, jos ei käyttäjää TAI _tabController on null
          ? _buildLoginPromptState(context, theme)
          : TabBarView(
              controller: _tabController,
              children: [
                // Streamit alustetaan _loadStreams-metodissa
                _buildPlansList(
                    context,
                    theme,
                    _activePlansStream ?? Stream.value([]),
                    "Ei aktiivisia suunnitelmia."),
                _buildPlansList(
                    context,
                    theme,
                    _completedPlansStream ?? Stream.value([]),
                    "Ei suoritettuja vaelluksia vielä."),
              ],
            ),
      floatingActionButton: userId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openAddHikePlanModal(),
              tooltip: 'Luo uusi vaellussuunnitelma',
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Uusi Suunnitelma'),
              heroTag: 'addHikePlanFab_NotesPage',
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildPlansList(BuildContext context, ThemeData theme,
      Stream<List<HikePlan>> stream, String emptyListMessage) {
    return SlideTransition(
      position: _slideAnimation,
      child: StreamBuilder<List<HikePlan>>(
        stream: stream, // Stream tulee nyt parametrina
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData &&
              !snapshot.hasError) {
            // Parannettu lataustilan tarkistus
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print(
                "Error in _buildPlansList StreamBuilder for '$emptyListMessage': ${snapshot.error}");
            return Center(
                child: Text(
              'Virhe suunnitelmien latauksessa.\n${snapshot.error}',
              textAlign: TextAlign.center,
            ));
          }
          final List<HikePlan> hikePlans =
              snapshot.data ?? []; // Oletus tyhjä lista, jos data on null

          if (hikePlans.isEmpty) {
            return _buildEmptyState(context, theme,
                customMessage: emptyListMessage);
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 12.0, bottom: 96.0),
            itemCount: hikePlans.length,
            itemBuilder: (context, index) {
              final plan = hikePlans[index];
              return HikePlanCard(
                key: ValueKey(plan.id),
                plan: plan,
                onTap: () async {
                  // Muutettu asynciksi, jotta voidaan odottaa paluuta
                  if (!mounted) return;
                  // Navigoidaan ja odotetaan mahdollista palautettua arvoa (päivitetty suunnitelma)
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HikePlanHubPage(initialPlan: plan),
                    ),
                  );
                  // Jos HikePlanHubPage palauttaa päivitetyn suunnitelman,
                  // tai jos halutaan vain "päivittää näkymä" palatessa:
                  if (mounted && result != null) {
                    // result voi olla päivitetty HikePlan tai vain signaali
                    // StreamBuilderin pitäisi päivittyä automaattisesti, jos data Firebasessa muuttui.
                    // Manuaalinen setState voi olla tarpeen, jos paikallista tilaa muutetaan.
                    // Koska streamit ladataan uudelleen _loadStreams-kutsulla, se voi riittää.
                    // _loadStreams(); // Tämä lataa streamit uudelleen, mikä voi olla raskasta.
                    // Parempi, jos HubPage ilmoittaa muutoksesta ja tämä sivu reagoi siihen
                    // esim. Providerin kautta tai palauttamalla päivitetyn objektin.
                    print(
                        "Returned from HikePlanHubPage, potential update needed.");
                    // setState(() {}); // Yksinkertainen uudelleenrakennus, jos tarpeen
                  }
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

  // _buildLoginPromptState ja _buildEmptyState pysyvät ennallaan
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
              'Kirjaudu nähdäksesi suunnitelmasi!',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sinun tulee olla kirjautuneena sisään nähdäksesi ja hallitaksesi vaellussuunnitelmiasi.',
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
                // GoRouter pitäisi hoitaa uudelleenohjaus LoginSivulle
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
              customMessage ?? 'Seikkailusi odottaa!',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              customMessage == null ||
                      customMessage == "Ei aktiivisia suunnitelmia."
                  ? 'Kun luot ensimmäisen vaellussuunnitelmasi, se ilmestyy tänne.'
                  : (customMessage == "Ei suoritettuja vaelluksia vielä."
                      ? "Kun merkitset suunnitelmia suoritetuiksi, ne näkyvät täällä."
                      : 'Aloita luomalla uusi suunnitelma!'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.65),
                height: 1.4,
              ),
            ),
            if (customMessage == null ||
                customMessage == "Ei aktiivisia suunnitelmia.") ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _openAddHikePlanModal(),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Luo uusi suunnitelma'),
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
