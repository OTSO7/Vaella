import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  String? _username;
  bool _isLoading = false;

  User? get user => _user;
  String? get username => _username;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _auth.authStateChanges().listen((User? firebaseUser) async {
      _user = firebaseUser;
      if (_user != null) {
        await _fetchUserProfile();
      } else {
        _username = null;
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
          _username = userDoc.get('username');
        } else {
          _username = null;
          print("Warning: User Firestore document not found for ${_user!.uid}");
        }
      } catch (e) {
        print('Error fetching user profile: $e');
        _username = null;
      }
    }
  }

  // Apufunktio tarkistamaan, onko syöte sähköpostimuodossa
  bool _isEmail(String input) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(input);
  }

  // UUSI KIRJAUTUMISLOGIIKKA: hyväksyy käyttäjätunnuksen tai sähköpostin
  Future<void> loginWithUsernameOrEmail(
      String identifier, String password) async {
    _isLoading = true;
    notifyListeners();
    String emailToLogin;

    try {
      if (_isEmail(identifier)) {
        // Jos tunnus on sähköposti, käytä sitä suoraan
        emailToLogin = identifier.trim();
      } else {
        // Jos tunnus ei ole sähköposti, oletetaan sen olevan käyttäjätunnus
        final QuerySnapshot userQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: identifier.trim().toLowerCase())
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          throw Exception('Käyttäjätunnusta tai sähköpostia ei löytynyt.');
        }

        // Käyttäjätunnus löytyi, haetaan sähköposti
        emailToLogin = userQuery.docs.first.get('email');
      }

      // Yritä kirjautua sisään löydetyllä sähköpostilla
      await _auth.signInWithEmailAndPassword(
          email: emailToLogin, password: password);
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'Käyttäjää ei löydy.'; // Yleistetty virhe
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

  // Vanha login-metodi, jota ei enää käytetä, mutta jätän sen kommentoituna vertailua varten
  // Future<void> login(String email, String password) async {
  //   _isLoading = true;
  //   notifyListeners();
  //   try {
  //     await _auth.signInWithEmailAndPassword(email: email, password: password);
  //   } on FirebaseAuthException catch (e) {
  //     String message;
  //     if (e.code == 'user-not-found') {
  //       message = 'Käyttäjää ei löydy tällä sähköpostilla.';
  //     } else if (e.code == 'wrong-password') {
  //       message = 'Väärä salasana.';
  //     } else if (e.code == 'invalid-email') {
  //       message = 'Virheellinen sähköpostiosoite.';
  //     } else {
  //       message = 'Kirjautuminen epäonnistui: ${e.message}';
  //     }
  //     throw Exception(message);
  //   } catch (e) {
  //     throw Exception('Kirjautuminen epäonnistui: $e');
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

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
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': email.toLowerCase(),
          'username': username.toLowerCase(),
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
        });
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
      _username = null;
    } catch (e) {
      print('Error during logout: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
