import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_model.dart'; // Tuo UserProfile-malli

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user; // Firebase Auth User
  UserProfile? _userProfile; // Firestoresta haettu käyttäjäprofiili
  bool _isLoading = false;

  User? get user => _user;
  UserProfile? get userProfile => _userProfile;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    // Kuuntele Firebase Auth -tilan muutoksia
    _auth.authStateChanges().listen((User? firebaseUser) async {
      _user = firebaseUser;
      if (_user != null) {
        await _fetchUserProfile(); // Hae Firestore-profiili, jos käyttäjä on kirjautunut
      } else {
        _userProfile = null; // Nollaa profiili uloskirjautuessa
      }
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _fetchUserProfile() async {
    if (_user != null) {
      try {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(_user!.uid).get();
        if (userDoc.exists) {
          _userProfile = UserProfile.fromFirestore(
              userDoc.data() as Map<String, dynamic>, _user!.uid);
        } else {
          // Tämä tilanne ei pitäisi tapahtua, jos rekisteröinti tallentaa aina profiilin.
          // Mutta jos tapahtuu, luodaan perusprofiili.
          print(
              "Warning: User Firestore document not found for ${_user!.uid}. Creating default profile.");
          _userProfile = UserProfile(
            uid: _user!.uid,
            username: _user!.email?.split('@')[0] ??
                'käyttäjä${_user!.uid.substring(0, 6)}',
            displayName: 'Uusi Seikkailija',
            email: _user!.email ?? '',
            photoURL: _user!.photoURL,
            bio: 'Tämä on uusi profiili! Aloita seikkailu.',
            bannerImageUrl: null,
            stats: {
              'Vaelluksia': 0,
              'Kilometrejä': 0.0,
              'Huippuja': 0,
              'Kuvia jaettu': 0
            },
            achievements: [],
            stickers: [],
            friends: [], // UUSI: Alusta tyhjällä friends-listalla
          );
          await _firestore
              .collection('users')
              .doc(_user!.uid)
              .set(_userProfile!.toFirestore());
        }
      } catch (e) {
        print('Error fetching or creating user profile: $e');
        _userProfile = null;
        // Tässä voit näyttää virheilmoituksen käyttäjälle, jos profiilin lataaminen epäonnistuu
      }
    }
  }

  // Päivitä käyttäjäprofiilia paikallisesti (kutsutaan edit_profile_page.dartista)
  // Huom: Firestore-päivitys tapahtuu yleensä EditProfilePage:ssa itsessään
  // tai sen omassa palvelussa. Tässä vain päivitetään paikallinen tila.
  Future<void> updateLocalUserProfile(UserProfile updatedProfile) async {
    _userProfile = updatedProfile;
    notifyListeners();
    // Päivitä Firebase Auth -käyttäjän display name ja photoURL, jos ne ovat muuttuneet
    if (_user != null) {
      if (_user!.displayName != updatedProfile.displayName) {
        await _user!.updateDisplayName(updatedProfile.displayName);
      }
      if (_user!.photoURL != updatedProfile.photoURL) {
        await _user!.updatePhotoURL(updatedProfile.photoURL);
      }
    }
  }

  bool _isEmail(String input) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(input);
  }

  Future<void> loginWithUsernameOrEmail(
      String identifier, String password) async {
    _setLoading(true);
    String emailToLogin;

    try {
      if (_isEmail(identifier)) {
        emailToLogin = identifier.trim();
      } else {
        // Etsi käyttäjän sähköpostia käyttäjätunnuksen perusteella
        final QuerySnapshot userQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: identifier.trim().toLowerCase())
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          throw Exception('Käyttäjätunnusta tai sähköpostia ei löytynyt.');
        }
        emailToLogin = userQuery.docs.first.get('email');
      }

      // Kirjaudu sisään Firebase Authenticationilla
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: emailToLogin, password: password);

      _user = userCredential.user; // Päivitä _user tässä
      await _fetchUserProfile(); // Hae käyttäjäprofiili sisäänkirjautumisen jälkeen
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Virheellinen käyttäjätunnus/sähköposti tai salasana.';
      } else if (e.code == 'invalid-email') {
        message = 'Virheellinen sähköpostiosoite tai käyttäjätunnus.';
      } else if (e.code == 'network-request-failed') {
        message = 'Verkkovirhe. Tarkista internetyhteytesi.';
      } else {
        message = 'Kirjautuminen epäonnistui: ${e.message}';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Kirjautuminen epäonnistui: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(
      String email, String password, String username, String name) async {
    _setLoading(true);
    try {
      // Tarkista, onko käyttäjätunnus jo käytössä (case-insensitive)
      final usernameExists = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (usernameExists.docs.isNotEmpty) {
        throw Exception('Käyttäjätunnus on jo varattu.');
      }

      // Luo Firebase-käyttäjä sähköpostilla ja salasanalla
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        _user = userCredential.user; // Päivitä _user tässä
        // Tallenna kaikki profiilitiedot Firestoreen rekisteröitymisen yhteydessä
        _userProfile = UserProfile(
          uid: _user!.uid,
          username: username.toLowerCase(),
          displayName: name,
          email: email.toLowerCase(),
          photoURL: null,
          bio: '',
          bannerImageUrl: null,
          stats: {
            'Vaelluksia': 0,
            'Kilometrejä': 0.0,
            'Huippuja': 0,
            'Kuvia jaettu': 0
          },
          achievements: [],
          stickers: [],
          friends: [], // UUSI: Alusta tyhjällä friends-listalla
        );
        await _firestore
            .collection('users')
            .doc(_user!.uid)
            .set(_userProfile!.toFirestore());
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'Salasana on liian heikko.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Sähköpostiosoite on jo käytössä.';
      } else if (e.code == 'invalid-email') {
        message = 'Virheellinen sähköpostiosoite.';
      } else if (e.code == 'network-request-failed') {
        message = 'Verkkovirhe. Tarkista internetyhteytesi.';
      } else {
        message = 'Rekisteröinti epäonnistui: ${e.message}';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Rekisteröinti epäonnistui: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _auth.signOut();
      _user = null; // Nollaa Firebase-käyttäjä
      _userProfile = null; // Nollaa profiili uloskirjautuessa
    } catch (e) {
      print('Error during logout: $e');
      throw Exception('Uloskirjautuminen epäonnistui: $e');
    } finally {
      _setLoading(false);
    }
  }
}
