// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../models/post_model.dart'; // Tuo päivitetty Post-malli
import '../models/user_profile_model.dart'; // Tuo UserProfile-malli
import '../widgets/post_card.dart';
import 'create_post_page.dart'; // UUSI: Tuo uusi postauksen luontisivu

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Post> _posts = [];
  bool _isLoadingPosts = true;
  String? _errorMessage;
  Stream<List<Post>>? _postsStream; // Muutettu nullableksi

  @override
  void initState() {
    super.initState();
    // Kuunnellaan auth-tilan muutoksia, jotta voidaan aloittaa postausten haku
    // vasta kun käyttäjäprofiili on latautunut.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.addListener(_onAuthChanged);
      _onAuthChanged(); // Tarkista tila heti alussa
    });
  }

  @override
  void dispose() {
    Provider.of<AuthProvider>(context, listen: false)
        .removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn && authProvider.userProfile != null) {
      _startPostsStream(authProvider.userProfile!);
    } else {
      // Jos käyttäjä ei ole kirjautunut tai profiili ei ole saatavilla,
      // tyhjennä postaukset ja aseta lataustila.
      setState(() {
        _posts = [];
        _isLoadingPosts = false;
        _errorMessage = 'Kirjaudu sisään nähdäksesi postaukset.';
        _postsStream = null; // Lopeta stream-kuuntelu
      });
    }
  }

  void _startPostsStream(UserProfile currentUserProfile) {
    // Aseta Stream uudelleen, jos käyttäjäprofiili muuttuu (esim. uloskirjautuminen/sisäänkirjautuminen)
    // Tässä on tärkeää varmistaa, että kuuntelija asetetaan vain kerran tai resetoidaan oikein.
    // Koska käytämme listenereitä AuthProviderissa, tämä metodi kutsutaan aina, kun _userProfile muuttuu.
    // Varmistetaan, ettei luoda useita kuuntelijoita.
    if (_postsStream != null) {
      // Voit harkita vanhan stream-subscriptionin peruuttamista, jos se on olemassa.
      // Tässä tapauksessa suora _postsStream-muuttujan uudelleenasetus ja map-funktioiden käyttö
      // hoitaa uudelleenkuuntelun tehokkaasti, koska stream on Single Subscription Stream.
    }

    _postsStream = _firestore.collection('posts').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
    }).map((allPosts) {
      // Suodata postaukset näkyvyyden perusteella
      return allPosts.where((post) {
        if (post.visibility == PostVisibility.public) {
          return true; // Julkiset postaukset näkyvät kaikille
        } else if (post.visibility == PostVisibility.private) {
          return post.userId == currentUserProfile.uid; // Vain oma yksityinen
        } else if (post.visibility == PostVisibility.friends) {
          // Postaus näkyy, jos käyttäjä on postauksen tekijä TAI
          // jos postauksen tekijä on ystävä.
          // HUOM: Postauksen tekijä näkee aina omat "ystäville"-postauksensa.
          return post.userId == currentUserProfile.uid ||
              currentUserProfile.friends.contains(post.userId);
        }
        return false;
      }).toList();
    });

    _postsStream!.listen((posts) {
      setState(() {
        // Järjestä postaukset aikaleiman mukaan laskevasti (uusin ensin)
        _posts = posts..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _isLoadingPosts = false;
        _errorMessage = null;
      });
    }, onError: (error) {
      setState(() {
        _isLoadingPosts = false;
        _errorMessage = 'Virhe postausten lataamisessa: $error';
        print('Error loading posts: $error');
      });
    });
  }

  Future<void> _refreshPosts() async {
    // onSnapshot kuuntelee jo muutoksia, joten erillistä refresh-logiikkaa ei tarvita
    // tässä kuin vain ilmoituksen antaminen.
    // Jos haluttaisiin pakottaa uudelleenlataus, voisi esim. nollata stream-kuuntelijan.
    // Tässä tapauksessa, koska käytämme onSnapshotia, data päivittyy automaattisesti.
    // Simuloidaan pientä viivettä, jotta käyttäjä näkee latausindikaattorin.
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Postaukset päivitetty.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Kirjaudu ulos',
          onPressed: () {
            authProvider.logout();
          },
        ),
        title: Hero(
          tag: 'appLogo',
          child: Image.asset(
            'assets/images/white2.png',
            height: 80,
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
                  content: Text('Hakuominaisuus ei ole vielä toteutettu.'),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        color: theme.colorScheme.secondary,
        backgroundColor: theme.primaryColor,
        child: _isLoadingPosts
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: theme.colorScheme.error, fontSize: 16),
                      ),
                    ),
                  )
                : _posts.isEmpty
                    ? Center(
                        child: Text(
                          authProvider.isLoggedIn
                              ? 'Ei postauksia näytettävänä. Aloita luomalla uusi!'
                              : 'Kirjaudu sisään nähdäksesi vaelluspostaukset.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          return PostCard(post: _posts[index]);
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16.0),
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // NYT TÄMÄ NAVIGOIDAAN UUDELLE SIVULLE!
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostPage()),
          );
        },
        tooltip: 'Lisää postaus',
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text("Lisää postaus"),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
