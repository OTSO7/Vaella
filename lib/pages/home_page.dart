// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/post_model.dart'; // <-- UUSI IMPORT
import '../widgets/post_card.dart'; // <-- UUSI IMPORT

class HomePage extends StatefulWidget {
  // Muutettu StatefulWidgetiksi, jotta voidaan hallita dataa
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<Post> _dummyPosts; // Tehdään tästä late, alustetaan initState:ssa

  @override
  void initState() {
    super.initState();
    _dummyPosts = _getDummyPosts();
  }

  List<Post> _getDummyPosts() {
    return [
      Post(
        id: '1',
        username: 'Maija Retkeilijä',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=1', // Satunnainen avatar
        postImageUrl:
            'https://picsum.photos/seed/trail1/600/400', // Satunnainen kuva
        caption:
            'Upea päiväretki Teijon kansallispuistossa! Polut olivat hyvässä kunnossa ja maisemat henkeäsalpaavat. 🌲☀️ #vaellus #luonto #teijo',
        timestamp:
            DateTime.now().subtract(const Duration(hours: 2, minutes: 35)),
        likes: 125,
        comments: 18,
        location: 'Teijon kansallispuisto',
      ),
      Post(
        id: '2',
        username: 'Erkki Eräilijä',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=2',
        postImageUrl: 'https://picsum.photos/seed/mountain2/600/400',
        caption:
            'Viikonlopun seikkailu Kolilla. Huipulla tuuli, mutta näkymät korvasivat kaiken! Suosittelen lämpimästi. #koli #kansallismaisema #retkeily #suomi',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
        likes: 210,
        comments: 32,
        location: 'Kolin kansallispuisto',
      ),
      Post(
        id: '3',
        username: 'Laura Luontokuvaaja',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=3',
        // Ei kuvaa tässä postauksessa
        caption:
            'Lyhyt iltakävely paikallisessa metsässä. Hiljaisuus ja raikas ilma tekevät niin hyvää. Pieniä iloja arjessa. 😌 #metsä #luontoterapia #iltakävely',
        timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 12)),
        likes: 95,
        comments: 12,
        location: 'Kaupin urheilupuisto, Tampere',
      ),
      Post(
        id: '4',
        username: 'Petteri PolunTallaaja',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=4',
        postImageUrl: 'https://picsum.photos/seed/aurora4/600/400',
        caption:
            'Revontulibongaus Inarissa viime yönä oli maagista! Kylmä, mutta ehdottomasti sen arvoista. ✨🌌 #revontulet #lappi #inarjärvi #yötaivas',
        timestamp: DateTime.now().subtract(const Duration(hours: 10)),
        likes: 302,
        comments: 45,
        location: 'Inari, Lappi',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seikkailut'), // Päivitetty otsikko
        backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
        elevation: 1, // Pieni varjo AppBarille
        actions: [
          IconButton(
            icon: const Icon(Icons.search), // Esim. hakutoiminto
            tooltip: 'Hae postauksia',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Hakutoimintoa ei ole vielä toteutettu.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Kirjaudu ulos',
            onPressed: () {
              authProvider.logout();
            },
          )
        ],
      ),
      body: RefreshIndicator(
        // Lisätään RefreshIndicator postausten päivittämiseen (myöhemmin)
        onRefresh: () async {
          // TODO: Toteuta oikea datan päivityslogiikka
          await Future.delayed(const Duration(seconds: 1)); // Simuloitu viive
          setState(() {
            _dummyPosts = _getDummyPosts()
              ..shuffle(); // Esim. sekoitetaan järjestys "päivityksenä"
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Postaukset "päivitetty" (järjestys sekoitettu).')),
          );
        },
        color: theme.colorScheme.secondary,
        backgroundColor: theme.primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.only(
              top: 8.0,
              bottom: 80.0), // Padding, jotta FAB ei peitä alinta korttia
          itemCount: _dummyPosts.length,
          itemBuilder: (context, index) {
            return PostCard(post: _dummyPosts[index]);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Muutettu .extended:ksi
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Uuden postauksen/muistiinpanon lisäystä ei ole vielä toteutettu.')),
          );
        },
        tooltip: 'Lisää postaus tai muistiinpano',
        backgroundColor: theme.colorScheme.secondary,
        icon: const Icon(Icons.edit_note_outlined), // Sopivampi ikoni
        label: const Text("Luo uusi"),
      ),
    );
  }
}
