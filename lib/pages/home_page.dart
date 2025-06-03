import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart'; // Lisätty Google Fonts
import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../models/user_profile_model.dart';
import '../widgets/post_card.dart';
import '../pages/create_post_page.dart';
import '../widgets/select_visibility_modal.dart'; // Oletetaan, että tämä widget on olemassa

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
  StreamSubscription<List<Post>>? _postsSubscription;

  @override
  void initState() {
    super.initState();
    // Varmistetaan, että AuthProvider-kuuntelija lisätään vasta, kun widget on rakennettu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Lisätään mounted-tarkistus
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.addListener(_onAuthChanged);
        _onAuthChanged(); // Kutsutaan heti, jotta tila päivittyy
      }
    });
  }

  @override
  void dispose() {
    // Varmistetaan, että Provider.of-kutsu on turvallinen dispose-metodissa
    if (mounted) {
      // Ei välttämättä tarvitse poistaa kuuntelijaa tällä tavalla,
      // jos AuthProvider elää pidempään ja HomePage voi tulla ja mennä.
      // Mutta jos HomePage on aina olemassa kun AuthProvider on, tämä on ok.
      try {
        Provider.of<AuthProvider>(context, listen: false)
            .removeListener(_onAuthChanged);
      } catch (e) {
        // print("Error removing listener from AuthProvider: $e");
        // Tämä voi tapahtua, jos provideria ei enää löydy widget-puusta.
      }
    }
    _postsSubscription?.cancel();
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return; // Varmista, että widget on yhä aktiivinen
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn && authProvider.userProfile != null) {
      _startPostsStream(authProvider.userProfile!);
    } else {
      _postsSubscription?.cancel();
      if (mounted) {
        setState(() {
          _posts = [];
          _isLoadingPosts = false; // Asetetaan false, koska ei ladata mitään
          _errorMessage = authProvider.isLoggedIn
              ? 'Loading profile to see posts...'
              : 'Sign in to see posts.';
        });
      }
    }
  }

  void _startPostsStream(UserProfile currentUserProfile) {
    _postsSubscription?.cancel(); // Peruuta aiempi tilaus, jos sellainen on

    if (mounted) {
      setState(() {
        _isLoadingPosts = true;
        _errorMessage = null;
      });
    }

    // Streami julkaisujen hakemiseksi ja suodattamiseksi
    final stream = _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            // Varmistetaan tyyppi DocumentSnapshot<Map<String, dynamic>> Post.fromFirestore-metodille
            .map((doc) => Post.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList())
        .map((allPosts) => allPosts.where((post) {
              // Näkyvyyslogiikka
              if (post.visibility == PostVisibility.public) return true;
              if (post.visibility == PostVisibility.private) {
                return post.userId == currentUserProfile.uid;
              }
              if (post.visibility == PostVisibility.friends) {
                // KORJATTU KOHTA: Käytetään `followingIds`-kenttää `friends`-kentän sijaan
                return post.userId == currentUserProfile.uid ||
                    (currentUserProfile.followingIds.contains(post.userId));
              }
              return false; // Oletuksena ei näytetä, jos näkyvyys on tuntematon
            }).toList());

    _postsSubscription = stream.listen((posts) {
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoadingPosts = false;
          _errorMessage = null;
        });
      }
    }, onError: (error, stackTrace) {
      // print('Posts stream error: $error \nStackTrace: $stackTrace'); // Käytä loggeria tuotannossa
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
          _errorMessage = 'Error loading posts. Please try again.';
        });
      }
    });
  }

  Future<void> _refreshPosts() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn && authProvider.userProfile != null) {
      // Asetetaan lataustila vain, jos ollaan oikeasti hakemassa uutta dataa.
      // _startPostsStream hoitaa oman _isLoadingPosts = true -asetuksensa.
      // Tässä voidaan näyttää RefreshIndicatorin oma latausikoni.
      _startPostsStream(
          authProvider.userProfile!); // Käynnistää streamin uudelleen
      // Pieni viive, jotta RefreshIndicator ehtii näkyä hetken
      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false; // Ei ladata, jos ei olla kirjautuneena
          _errorMessage = 'Sign in to refresh posts.';
          _posts =
              []; // Tyhjennetään postaukset, jos käyttäjä ei ole kirjautunut
        });
      }
    }
    // Ei tarvita erillistä _isLoadingPosts = false -asetusta tässä,
    // koska _startPostsStream hoitaa sen, kun dataa saapuu tai tulee virhe.
    // SnackBar voidaan näyttää, kun _startPostsStream on saanut dataa.
    // Tämän voi integroida stream.listenin onDone- tai data-kohtaan,
    // tai pitää sen tässä yksinkertaisena ilmoituksena.
    if (mounted) {
      // Viivästetty SnackBar, jotta se ei peitä heti latausindikaattoria
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted && _errorMessage == null) {
          // Näytä vain jos ei virhettä
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Posts refreshed!', style: GoogleFonts.lato()),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: theme.appBarTheme.elevation ?? 0.5,
        leading: authProvider.isLoggedIn // Näytä logout vain jos kirjauduttu
            ? IconButton(
                icon: Icon(Icons.logout_outlined,
                    color: theme.colorScheme.onSurfaceVariant),
                tooltip: "Log out",
                onPressed: () => authProvider.logout(),
              )
            : null, // Ei leading-ikonia, jos ei kirjauduttu
        title: Hero(
          tag:
              'appLogo', // Varmista, että tämä tagi on uniikki tai käytössä oikein
          child: Image.asset(
              'assets/images/white2.png', // Varmista kuvan polku ja olemassaolo
              height: 35, // Säädä korkeutta tarvittaessa
              fit: BoxFit.contain),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.search_outlined,
                color: theme.colorScheme.onSurfaceVariant),
            tooltip: "Search",
            onPressed: () {
              // TODO: Toteuta hakuominaisuus
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Search feature is not implemented yet.',
                      style: GoogleFonts.lato()),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(10),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        color: theme.colorScheme.primary, // Käytä pääväriä indikaattorissa
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: _isLoadingPosts &&
                _posts.isEmpty // Näytä lataus vain jos postauksia ei vielä ole
            ? Center(
                child:
                    CircularProgressIndicator(color: theme.colorScheme.primary))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 40, color: theme.colorScheme.error),
                          const SizedBox(height: 12),
                          Text(_errorMessage!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lato(
                                  color: theme.colorScheme.error,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                : _posts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.feed_outlined,
                                  size: 50,
                                  color: theme.hintColor.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text(
                                authProvider.isLoggedIn
                                    ? 'No posts to show right now.'
                                    : 'Sign in to see hiking posts.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lato(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5),
                              ),
                              if (authProvider.isLoggedIn) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Follow others or create your first post!',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.lato(
                                      color: theme.hintColor, fontSize: 14),
                                ),
                              ]
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(
                            top: 8.0, bottom: 90.0), // Tilaa FAB:lle
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          return PostCard(key: ValueKey(post.id), post: post);
                        },
                        separatorBuilder: (context, index) => const SizedBox(
                            height: 12.0), // Pienempi väli korttien välissä
                      ),
      ),
      floatingActionButton: authProvider
              .isLoggedIn // Näytä FAB vain jos kirjauduttu
          ? FloatingActionButton.extended(
              onPressed: () {
                final currentAuthProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                // Tarkistus on jo yllä, mutta varmuuden vuoksi
                if (!currentAuthProvider.isLoggedIn ||
                    currentAuthProvider.userProfile == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign in to create a post.',
                          style: GoogleFonts.lato()),
                      backgroundColor: theme.colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.all(10),
                    ),
                  );
                  return;
                }

                // Näytä näkyvyyden valintaikkuna ensin
                showSelectVisibilityModal(context, (selectedVisibility) async {
                  if (mounted) {
                    // Tarkista mounted uudelleen asynkronisen operaation jälkeen
                    try {
                      // Navigoi CreatePostPage-sivulle valitun näkyvyyden kanssa
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (navContext) => CreatePostPage(
                              initialVisibility: selectedVisibility),
                        ),
                      );
                      // Tässä voisi päivittää postaukset automaattisesti, jos uusi postaus luotiin
                      // _refreshPosts(); // Tai jos stream päivittyy automaattisesti, tämä ei ole välttämätön
                    } catch (e, s) {
                      // print( // Käytä loggeria
                      //     'ERROR during Navigator.push or CreatePostPage build: $e\nStackTrace: $s');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to open the page.',
                                style: GoogleFonts.lato()),
                            backgroundColor: theme.colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.all(10),
                          ),
                        );
                      }
                    }
                  }
                });
              },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text("New post",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              backgroundColor: theme.colorScheme.secondary, // Oranssi
              foregroundColor: theme.colorScheme.onSecondary, // Valkoinen
            )
          : null, // Ei FABia, jos ei kirjauduttu
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
