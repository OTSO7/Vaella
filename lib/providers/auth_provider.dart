import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_model.dart'; // Tuo UserProfile-malli

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  UserProfile? _userProfile; // Tänne tallennetaan koko profiili
  bool _isLoading = false;

  User? get user => _user;
  UserProfile? get userProfile => _userProfile; // UUSI GETTERI
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _auth.authStateChanges().listen((User? firebaseUser) async {
      _user = firebaseUser;
      if (_user != null) {
        await _fetchUserProfile(); // Hae koko profiili
      } else {
        _userProfile = null; // Nollaa profiili uloskirjautuessa
      }
      notifyListeners();
    });
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
          // Jos Firestore-dokumenttia ei löydy, luo oletusprofiili
          // TÄMÄ ON KRITIIKKINEN, KOSKA KÄYTTÄJÄ ON REKISTERÖITYNYT AUTHIN KAUTTA, MUTTA EI FIRESTOREEN
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
          );
          await _firestore
              .collection('users')
              .doc(_user!.uid)
              .set(_userProfile!.toFirestore());
        }
      } catch (e) {
        print('Error fetching or creating user profile: $e');
        _userProfile = null;
      }
    }
  }

  // Päivitä käyttäjäprofiilia Firestoreen (kutsutaan edit_profile_page.dartista)
  Future<void> updateLocalUserProfile(UserProfile updatedProfile) async {
    _userProfile = updatedProfile;
    notifyListeners();
    // Tässä vaiheessa voit myös päivittää Firebase Auth Display Name ja PhotoURL
    if (_user != null) {
      if (_user!.displayName != updatedProfile.displayName) {
        await _user!.updateDisplayName(updatedProfile.displayName);
      }
      if (_user!.photoURL != updatedProfile.photoURL) {
        await _user!.updatePhotoURL(updatedProfile.photoURL);
      }
    }
    // Firestore-päivitys hoidetaan edit_profile_page.dartissa
  }

  bool _isEmail(String input) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(input);
  }

  Future<void> loginWithUsernameOrEmail(
      String identifier, String password) async {
    _isLoading = true;
    notifyListeners();
    String emailToLogin;

    try {
      if (_isEmail(identifier)) {
        emailToLogin = identifier.trim();
      } else {
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

      await _auth.signInWithEmailAndPassword(
          email: emailToLogin, password: password);
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'Käyttäjää ei löydy.';
      } else if (e.code == 'wrong-password') {
        message = 'Väärä salasana.';
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
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(
      String email, String password, String username, String name) async {
    _isLoading = true;
    notifyListeners();
    try {
      final usernameExists = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (usernameExists.docs.isNotEmpty) {
        throw Exception('Käyttäjätunnus on jo varattu.');
      }

      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Tallenna kaikki profiilitiedot Firestoreen rekisteröitymisen yhteydessä
        _userProfile = UserProfile(
          uid: userCredential.user!.uid,
          username: username.toLowerCase(),
          displayName: name,
          email: email.toLowerCase(),
          photoURL: null, // Ei aluksi profiilikuvaa
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
        );
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
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
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signOut();
      _user = null;
      _userProfile = null; // Nollaa profiili uloskirjautuessa
    } catch (e) {
      print('Error during logout: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
