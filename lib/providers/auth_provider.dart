// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_model.dart';

class AuthProvider with ChangeNotifier {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  fb_auth.User? _user;
  UserProfile? _userProfile;
  bool _isLoading = false;

  fb_auth.User? get user => _user;
  UserProfile? get userProfile => _userProfile;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _auth.authStateChanges().listen((fb_auth.User? firebaseUser) async {
      bool wasLoading = _isLoading;
      if (!_isLoading) _setLoading(true);
      _user = firebaseUser;
      if (_user != null) {
        await _fetchUserProfile();
      } else {
        _userProfile = null;
        if (!wasLoading) notifyListeners();
      }
      _setLoading(false);
    });
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _fetchUserProfile() async {
    if (_user == null) {
      if (_userProfile != null) {
        _userProfile = null;
        notifyListeners();
      }
      return;
    }
    try {
      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(_user!.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        _userProfile = UserProfile.fromFirestore(userDoc.data()!, _user!.uid);
      } else {
        _userProfile = UserProfile(
          uid: _user!.uid,
          username: _user!.email?.split('@')[0] ??
              'user${_user!.uid.substring(0, 6)}',
          displayName: 'New Adventurer',
          email: _user!.email ?? '',
          photoURL: _user!.photoURL,
          bio: 'This is a new profile! Start your adventure.',
          bannerImageUrl: null,
          stats: {
            'Vaelluksia': 0,
            'Kilometrejä': 0.0,
            'Huippuja': 0,
            'Kuvia jaettu': 0
          },
          achievements: [],
          stickers: [],
          followingIds: [],
          followerIds: [],
          postsCount: 0,
        );
        await _firestore
            .collection('users')
            .doc(_user!.uid)
            .set(_userProfile!.toFirestore());
      }
    } catch (e) {
      _userProfile = null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> updateLocalUserProfile(UserProfile updatedProfile) async {
    _userProfile = updatedProfile;
    notifyListeners();
    if (_user != null) {
      if (_user!.displayName != updatedProfile.displayName) {
        await _user!
            .updateDisplayName(updatedProfile.displayName)
            .catchError((e) {/* error handling */});
      }
      if (_user!.photoURL != updatedProfile.photoURL) {
        await _user!
            .updatePhotoURL(updatedProfile.photoURL)
            .catchError((e) {/* error handling */});
      }
    }
  }

  Future<void> handlePostCreationSuccess() async {
    if (_userProfile != null && _user != null) {
      _userProfile =
          _userProfile!.copyWith(postsCount: _userProfile!.postsCount + 1);
      notifyListeners();
      try {
        final userDocRef = _firestore.collection('users').doc(_user!.uid);
        await userDocRef.update({'postsCount': FieldValue.increment(1)});
      } catch (e) {
        // Virheenkäsittely Firestore-päivitykselle
      }
    }
  }

  Future<void> handlePostDeletionSuccess() async {
    if (_userProfile != null && _user != null && _userProfile!.postsCount > 0) {
      _userProfile =
          _userProfile!.copyWith(postsCount: _userProfile!.postsCount - 1);
      notifyListeners();
      try {
        final userDocRef = _firestore.collection('users').doc(_user!.uid);
        await userDocRef.update({'postsCount': FieldValue.increment(-1)});
      } catch (e) {
        // Virheenkäsittely Firestore-päivitykselle
      }
    } else if (_userProfile != null &&
        _user != null &&
        _userProfile!.postsCount == 0) {
      // Jos laskuri on jo nolla, ei tehdä mitään (tai varmistetaan ettei se mene negatiiviseksi Firestore:ssa)
      // FieldValue.increment(-1) voi tehdä arvosta negatiivisen, jos sitä ei valvota.
      // On parempi, että sovelluslogiikka estää tämän.
      // Tässä tapauksessa _userProfile!.postsCount > 0 -ehto jo estää tämän.
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
        final QuerySnapshot<Map<String, dynamic>> userQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: identifier.trim().toLowerCase())
            .limit(1)
            .get();
        if (userQuery.docs.isEmpty)
          throw Exception('Username or email not found.');
        final userData = userQuery.docs.first.data();
        if (userData.containsKey('email') && userData['email'] != null) {
          emailToLogin = userData['email'];
        } else {
          throw Exception('Email not found for the given username.');
        }
      }
      fb_auth.UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: emailToLogin, password: password);
      if (userCredential.user != null &&
          _user?.uid != userCredential.user?.uid) {
        _user = userCredential.user;
        await _fetchUserProfile();
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Invalid username/email or password.';
      } else if (e.code == 'invalid-email')
        message = 'Invalid email address or username.';
      else if (e.code == 'network-request-failed')
        message = 'Network error. Please check your internet connection.';
      else
        message = 'Login failed: ${e.message}';
      throw Exception(message);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(
      String email, String password, String username, String name) async {
    _setLoading(true);
    try {
      final usernameLower = username.toLowerCase().trim();
      if (usernameLower.isEmpty) throw Exception('Username cannot be empty.');
      if (name.trim().isEmpty) throw Exception('Display name cannot be empty.');

      final usernameExists = await _firestore
          .collection('users')
          .where('username', isEqualTo: usernameLower)
          .limit(1)
          .get();
      if (usernameExists.docs.isNotEmpty)
        throw Exception('Username is already taken.');

      fb_auth.UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
              email: email.trim(), password: password);

      if (userCredential.user != null) {
        _user = userCredential.user;
        _userProfile = UserProfile(
          uid: _user!.uid,
          username: usernameLower,
          displayName: name.trim(),
          email: email.trim().toLowerCase(),
          photoURL: _user!.photoURL,
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
          followingIds: [],
          followerIds: [],
          postsCount: 0,
        );
        await _firestore
            .collection('users')
            .doc(_user!.uid)
            .set(_userProfile!.toFirestore());
        notifyListeners();
      } else {
        throw Exception('User registration failed, user object not created.');
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password')
        message = 'Password is too weak.';
      else if (e.code == 'email-already-in-use')
        message = 'Email address is already in use.';
      else if (e.code == 'invalid-email')
        message = 'Invalid email address.';
      else if (e.code == 'network-request-failed')
        message = 'Network error. Please check your internet connection.';
      else
        message = 'Registration failed: ${e.message}';
      throw Exception(message);
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      if (_user != null || _userProfile != null) {
        _user = null;
        _userProfile = null;
      }
    } catch (e) {
      throw Exception('Logout failed: ${e.toString()}');
    } finally {
      _setLoading(false); // Varmista, että setLoading(false) kutsutaan aina
    }
  }
}
