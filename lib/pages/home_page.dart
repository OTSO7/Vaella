// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<Post> _dummyPosts;

  @override
  void initState() {
    super.initState();
    _dummyPosts = _getDummyPosts();
  }

  // Nykyiset dummy-postaukset
  List<Post> _getDummyPosts() {
    return [
      Post(
        id: '1',
        username: 'Maija Retkeilijä',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=1',
        postImageUrl: 'https://picsum.photos/seed/trail1/600/400',
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
      Post(
        id: '5',
        username: 'Sini Sääksjärvi',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=5',
        postImageUrl: 'https://picsum.photos/seed/lake5/600/400',
        caption:
            'Upea aamu Sääksjärvellä! Kajakointi auringonnousun aikaan on parasta. 🌅🛶 #kajakointi #auringonnousu #järvimaisema',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        likes: 180,
        comments: 20,
        location: 'Sääksjärvi',
      ),
      Post(
        id: '6',
        username: 'Ville Vaeltaja',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=6',
        postImageUrl: 'https://picsum.photos/seed/forest6/600/400',
        caption:
            'Pitkä vaellus Korouoman kanjonissa takana. Jäätiköt olivat huikeita! 💪❄️ #korouoma #jääputous #talvivaellus',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        likes: 250,
        comments: 38,
        location: 'Korouoman kanjoni',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'appLogo',
          child: Image.asset(
            'assets/images/white1.png',
            height: 32,
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
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
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          setState(() {
            _dummyPosts = _getDummyPosts()..shuffle();
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Postaukset "päivitetty" (järjestys sekoitettu).')),
          );
        },
        color: theme.colorScheme.secondary,
        backgroundColor: theme.primaryColor,
        child: ListView.separated(
          // MUUTETTU: Käytetään ListView.separated
          padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
          itemCount: _dummyPosts.length,
          itemBuilder: (context, index) {
            return PostCard(post: _dummyPosts[index]);
          },
          separatorBuilder: (context, index) =>
              const SizedBox(height: 16.0), // LISÄTTY: Väliä korttien väliin
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Uuden postauksen/muistiinpanon lisäystä ei ole vielä toteutettu.')),
          );
        },
        tooltip: 'Lisää postaus tai muistiinpano',
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text("Lisää postaus"),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
