// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile_model.dart'; // Nyt voidaan käyttää suoraan UserProfile

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

  // --- XP-järjestelmän logiikka ---
  int getExperienceRequiredForLevel(int level) {
    if (level <= 0) return 100;
    // Olen säätänyt tätä kaavaa hieman, jotta se skaalautuu paremmin korkeammille tasoille
    // ja antaa tasokohtaisia XP-arvoja, jotka eivät kasva liian jyrkästi.
    // Voit edelleen hienosäätää tätä.
    // Esimerkkejä:
    // L1: 100 XP
    // L2: 150 XP
    // L3: 200 XP
    // L4: 250 XP
    // L5: 300 XP
    // ...
    // L32: ~1650 XP (riippuu tarkasta kaavasta)
    return 100 + (level - 1) * 50; // Lineaarinen kasvu
  }

  Future<void> addExperience(int amount) async {
    if (_userProfile == null || _user == null) return;

    int currentTotalExperience = _userProfile!.experience;
    int currentLevel = _userProfile!.level;

    int newTotalExperience = currentTotalExperience + amount;
    int newLevel = currentLevel;

    // Käsittele tasojen nousu
    while (
        newTotalExperience >= _getTotalExperienceToReachLevel(newLevel + 1)) {
      newLevel++;
      print('Level up! New level: $newLevel');
      // Tässä voit lisätä ilmoituksen tai muun toiminnallisuuden tason noususta.
    }

    // Päivitä tilastot (esim. "Vaelluksia"-kenttä, jos se liittyy XP:hen)
    Map<String, dynamic> updatedStats = Map.from(_userProfile!.stats);
    updatedStats['Vaelluksia'] = (updatedStats['Vaelluksia'] as num? ?? 0) + 1;

    UserProfile updatedProfile = _userProfile!.copyWith(
      experience: newTotalExperience,
      level: newLevel,
      stats: updatedStats,
    );

    await _firestore
        .collection('users')
        .doc(_user!.uid)
        .update(updatedProfile.toFirestore())
        .then((_) {
      _userProfile = updatedProfile;
      notifyListeners(); // Varmista, että UI päivittyy XP:n lisäyksen jälkeen
    }).catchError((e) {
      print('Error updating XP/Level in Firestore: $e');
    });
  }

  int _getTotalExperienceToReachLevel(int targetLevel) {
    int totalXp = 0;
    // Laske XP-kynnykset kaikille edellisille tasoille
    for (int i = 1; i < targetLevel; i++) {
      totalXp += getExperienceRequiredForLevel(i);
    }
    return totalXp;
  }
  // --- XP-järjestelmän logiikka loppuu ---

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
        // Luo UserProfile olemassa olevasta datasta
        _userProfile = UserProfile.fromFirestore(userDoc.data()!, _user!.uid);

        // TÄRKEÄ KORJAUS: Tarkista, puuttuvatko level ja experience. Jos puuttuvat, alusta ne.
        // Ja päivitä Firestoreen.
        bool needsUpdateInFirestore = false;
        if (userDoc.data()!['level'] == null) {
          _userProfile = _userProfile!.copyWith(level: 1);
          needsUpdateInFirestore = true;
        }
        if (userDoc.data()!['experience'] == null) {
          _userProfile = _userProfile!.copyWith(experience: 0);
          needsUpdateInFirestore = true;
        }

        // Varmista myös, että stats-kartta sisältää 'Vaelluksia' -kentän, jos se puuttuu
        if (!_userProfile!.stats.containsKey('Vaelluksia')) {
          Map<String, dynamic> updatedStats = Map.from(_userProfile!.stats);
          updatedStats['Vaelluksia'] = 0;
          _userProfile = _userProfile!.copyWith(stats: updatedStats);
          needsUpdateInFirestore = true;
        }

        if (needsUpdateInFirestore) {
          print(
              'User profile missing level/experience/stats, initializing and updating Firestore.');
          await _firestore
              .collection('users')
              .doc(_user!.uid)
              .set(_userProfile!.toFirestore());
        }
      } else {
        // Jos käyttäjän profiilia ei ole vielä luotu, luo oletusprofiili
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
          level: 1,
          experience: 0,
        );
        await _firestore
            .collection('users')
            .doc(_user!.uid)
            .set(_userProfile!.toFirestore());
      }
    } catch (e) {
      _userProfile = null;
      print('Error fetching user profile: $e');
    } finally {
      _setLoading(false); // Aseta lataustila falseksi lopuksi
      // TÄRKEÄ: NotifyListeners() KUTSUTaan AINA TÄSSÄ!
      // Varmistaa, että UI päivittyy haun jälkeen, olipa se onnistunut tai ei.
      notifyListeners();
    }
  }

  Future<void> updateLocalUserProfile(UserProfile updatedProfile) async {
    _userProfile = updatedProfile; // Päivitä paikallisesti heti
    notifyListeners();

    if (_user != null) {
      if (_user!.displayName != updatedProfile.displayName) {
        await _user!
            .updateDisplayName(updatedProfile.displayName)
            .catchError((e) {/* error handling */});
      }
      if (updatedProfile.photoURL != null &&
          _user!.photoURL != updatedProfile.photoURL) {
        await _user!
            .updatePhotoURL(updatedProfile.photoURL)
            .catchError((e) {/* error handling */});
      }
      try {
        await _firestore
            .collection('users')
            .doc(_user!.uid)
            .update(updatedProfile.toFirestore());
      } catch (e) {
        print('Error updating user profile in Firestore: $e');
      }
    }
  }

  // UUSI METODI: Profiilin suora päivittäminen (käytettävä testaukseen tai erikoistilanteisiin)
  Future<void> updateProfileDataDirectly(
      Map<String, dynamic> dataToUpdate) async {
    if (_userProfile == null || _user == null) {
      print('Cannot update profile: user not logged in or profile not loaded.');
      return;
    }

    _setLoading(true);
    try {
      // Päivitä Firestore
      await _firestore.collection('users').doc(_user!.uid).update(dataToUpdate);

      // TÄRKEÄ KORJAUS: Päivitä paikallinen _userProfile-objekti suoraan lähetetyillä tiedoilla.
      // Käytä copyWith-metodia yhdistämään olemassa olevat tiedot uusien kanssa.
      UserProfile currentProfile = _userProfile!;
      int? newLevel = dataToUpdate['level'] as int?;
      int? newExperience = dataToUpdate['experience'] as int?;
      Map<String, dynamic>? newStats =
          dataToUpdate['stats'] as Map<String, dynamic>?;

      _userProfile = currentProfile.copyWith(
        level: newLevel,
        experience: newExperience,
        stats: newStats,
        // Kopioi myös muut kentät, jos niitä voi päivittää suoraan tällä metodilla.
        // Jos dataToUpdate sisältää muita kenttiä, ne tulisi käsitellä tässä.
        // Koska tämä on 'direct' päivitys, voi olla turvallisempaa hakea koko profiili uudelleen,
        // mutta tehokkuuden kannalta tämä on parempi, kun tiedetään mitä päivitetään.
        // Jos halutaan varmistaa kaikki kentät, voisi hakea profiilin uudelleen.
        // Mutta useimmissa tapauksissa suorat päivitykset kohdistuvat vain muutamaan kenttään.
      );

      notifyListeners(); // Ilmoita UI:lle välittömästi päivityksestä

      print('Profile updated directly in Firestore and locally: $dataToUpdate');
    } catch (e) {
      print('Error updating profile directly: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> handlePostCreationSuccess() async {
    if (_userProfile != null && _user != null) {
      final userDocRef = _firestore.collection('users').doc(_user!.uid);
      await userDocRef
          .update({'postsCount': FieldValue.increment(1)}).then((_) {
        _userProfile =
            _userProfile!.copyWith(postsCount: _userProfile!.postsCount + 1);
        notifyListeners();
      }).catchError((e) {
        print('Error updating postsCount in Firestore: $e');
      });
    }
  }

  Future<void> handlePostDeletionSuccess() async {
    if (_userProfile != null && _user != null && _userProfile!.postsCount > 0) {
      final userDocRef = _firestore.collection('users').doc(_user!.uid);
      await userDocRef
          .update({'postsCount': FieldValue.increment(-1)}).then((_) {
        _userProfile =
            _userProfile!.copyWith(postsCount: _userProfile!.postsCount - 1);
        notifyListeners();
      }).catchError((e) {
        print('Error updating postsCount in Firestore: $e');
      });
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
        if (userQuery.docs.isEmpty) {
          throw Exception('Username or email not found.');
        }
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
      if (usernameExists.docs.isNotEmpty) {
        throw Exception('Username is already taken.');
      }

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
          level: 1,
          experience: 0,
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
      if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      } else if (e.code == 'email-already-in-use')
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
      _setLoading(false);
    }
  }
}
