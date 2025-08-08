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
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _onAuthStateChanged(fb_auth.User? firebaseUser) async {
    _setLoading(true);
    _user = firebaseUser;
    if (_user != null) {
      await _fetchCurrentUserProfile();
    } else {
      _userProfile = null;
    }
    _setLoading(false);
  }

  // --- KÄYTTÄJIEN JA SEURAAMISEN HALLINTA ---

  // TÄRKEÄÄ: Jotta tämä haku toimisi, sinun on luotava Firestore-indeksi.
  // Mene Firebase-konsoliin -> Firestore Database -> Indexes.
  // Luo uusi indeksi:
  // - Collection ID: users
  // - Fields to index: username (Ascending)
  Future<List<UserProfile>> searchUsersByUsername(String query) async {
    if (!isLoggedIn || query.isEmpty) return [];
    final currentUserId = _user!.uid;

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username',
              isLessThan: query.toLowerCase() +
                  '\uf8ff') // \uf8ff is a high Unicode character
          .limit(15)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return [];
      }

      final List<UserProfile> results = [];
      for (var doc in querySnapshot.docs) {
        if (doc.id == currentUserId) continue; // Don't show self in results

        final userProfile = UserProfile.fromFirestore(doc);

        if (_userProfile?.followingIds.contains(userProfile.uid) ?? false) {
          userProfile.relationToCurrentUser = UserRelation.following;
        } else {
          userProfile.relationToCurrentUser = UserRelation.notFollowing;
        }
        results.add(userProfile);
      }
      return results;
    } catch (e) {
      // This will print the error to the console, which is often a missing index warning.
      debugPrint('--- FIRESTORE SEARCH ERROR ---');
      debugPrint('Error searching users by username: $e');
      debugPrint(
          'This likely means you are missing a Firestore index for the "users" collection on the "username" field (Ascending).');
      debugPrint('------------------------------');
      return []; // Return an empty list on error to prevent the app from crashing.
    }
  }

  Future<UserProfile> fetchUserProfileById(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception('User not found.');
      }
      UserProfile profile = UserProfile.fromFirestore(userDoc);

      if (!isLoggedIn) {
        profile.relationToCurrentUser = UserRelation.unknown;
      } else if (userId == _user!.uid) {
        profile.relationToCurrentUser = UserRelation.self;
      } else {
        if (_userProfile == null) await _fetchCurrentUserProfile();
        final isFollowing =
            _userProfile?.followingIds.contains(userId) ?? false;
        profile.relationToCurrentUser =
            isFollowing ? UserRelation.following : UserRelation.notFollowing;
      }
      return profile;
    } catch (e) {
      debugPrint('Error fetching profile for $userId: $e');
      rethrow;
    }
  }

  Future<void> toggleFollowStatus(
      String otherUserId, bool isCurrentlyFollowing) async {
    if (!isLoggedIn) return;
    final currentUserId = _user!.uid;

    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    final otherUserRef = _firestore.collection('users').doc(otherUserId);

    try {
      await _firestore.runTransaction((transaction) async {
        if (isCurrentlyFollowing) {
          transaction.update(currentUserRef, {
            'followingIds': FieldValue.arrayRemove([otherUserId])
          });
          transaction.update(otherUserRef, {
            'followerIds': FieldValue.arrayRemove([currentUserId])
          });
        } else {
          transaction.update(currentUserRef, {
            'followingIds': FieldValue.arrayUnion([otherUserId])
          });
          transaction.update(otherUserRef, {
            'followerIds': FieldValue.arrayUnion([currentUserId])
          });
        }
      });
      if (_userProfile != null) {
        if (isCurrentlyFollowing) {
          _userProfile!.followingIds.remove(otherUserId);
        } else {
          _userProfile!.followingIds.add(otherUserId);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error toggling follow status: $e");
      rethrow;
    }
  }

  // --- POSTAUSLASKURIN JA XP:N HALLINTA ---

  Future<void> synchronizePostsCount() async {
    if (!isLoggedIn || _userProfile == null) return;
    try {
      final postsQuery = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: _user!.uid)
          .get();
      final actualPostsCount = postsQuery.docs.length;

      if (actualPostsCount != _userProfile!.postsCount) {
        await _firestore.collection('users').doc(_user!.uid).update({
          'postsCount': actualPostsCount,
        });
        _userProfile = _userProfile!.copyWith(postsCount: actualPostsCount);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error synchronizing post count: $e');
    }
  }

  Future<void> handlePostCreationSuccess() async {
    if (_userProfile == null || !isLoggedIn) return;
    await _firestore.collection('users').doc(_user!.uid).update({
      'postsCount': FieldValue.increment(1),
    });
    _userProfile =
        _userProfile!.copyWith(postsCount: _userProfile!.postsCount + 1);
    await addExperience(50);
    notifyListeners();
  }

  Future<void> handlePostDeletionSuccess() async {
    if (_userProfile == null || !isLoggedIn || _userProfile!.postsCount <= 0) {
      return;
    }
    await _firestore.collection('users').doc(_user!.uid).update({
      'postsCount': FieldValue.increment(-1),
    });
    _userProfile =
        _userProfile!.copyWith(postsCount: _userProfile!.postsCount - 1);
    notifyListeners();
  }

  Future<void> addExperience(int amount) async {
    if (_userProfile == null || !isLoggedIn) return;
    int newTotalExperience = _userProfile!.experience + amount;
    int newLevel = _userProfile!.level;
    while (
        newTotalExperience >= _getTotalExperienceToReachLevel(newLevel + 1)) {
      newLevel++;
    }
    if (newTotalExperience != _userProfile!.experience ||
        newLevel != _userProfile!.level) {
      await _firestore.collection('users').doc(_user!.uid).update({
        'experience': newTotalExperience,
        'level': newLevel,
      });
      _userProfile = _userProfile!
          .copyWith(experience: newTotalExperience, level: newLevel);
      notifyListeners();
    }
  }

  int getExperienceRequiredForLevel(int level) {
    if (level <= 0) return 100;
    return 100 + (level - 1) * 50;
  }

  int _getTotalExperienceToReachLevel(int targetLevel) {
    int totalXp = 0;
    for (int i = 1; i < targetLevel; i++) {
      totalXp += getExperienceRequiredForLevel(i);
    }
    return totalXp;
  }

  // --- PROFIILIN HAKU JA PÄIVITYS ---

  Future<void> _fetchCurrentUserProfile() async {
    if (_user == null) {
      _userProfile = null;
      notifyListeners();
      return;
    }
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_user!.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        _userProfile = UserProfile.fromFirestore(userDoc);
        await synchronizePostsCount();
      } else {
        _userProfile = UserProfile(
          uid: _user!.uid,
          username: _user!.email?.split('@')[0] ??
              'user${_user!.uid.substring(0, 6)}',
          displayName: _user!.displayName ?? 'New Adventurer',
          email: _user!.email ?? '',
          photoURL: _user!.photoURL,
          level: 1,
          experience: 0,
          postsCount: 0,
          hikeStats: HikeStats(),
        );
        await _firestore
            .collection('users')
            .doc(_user!.uid)
            .set(_userProfile!.toFirestore());
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      _userProfile = null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> updateLocalUserProfile(UserProfile updatedProfile) async {
    if (_user == null) return;
    _userProfile = updatedProfile;
    notifyListeners();
    if (_user!.displayName != updatedProfile.displayName) {
      await _user!
          .updateDisplayName(updatedProfile.displayName)
          .catchError((e) {});
    }
    if (updatedProfile.photoURL != null &&
        _user!.photoURL != updatedProfile.photoURL) {
      await _user!.updatePhotoURL(updatedProfile.photoURL).catchError((e) {});
    }
    try {
      await _firestore
          .collection('users')
          .doc(_user!.uid)
          .update(updatedProfile.toFirestore());
    } catch (e) {
      debugPrint('Error updating user profile in Firestore: $e');
    }
  }

  // --- AUTENTIKOINTIMETODIT ---

  bool _isEmail(String input) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(input);
  }

  Future<void> loginWithUsernameOrEmail(
      String identifier, String password) async {
    _setLoading(true);
    try {
      String emailToLogin;
      if (_isEmail(identifier)) {
        emailToLogin = identifier.trim();
      } else {
        final query = await _firestore
            .collection('users')
            .where('username', isEqualTo: identifier.trim().toLowerCase())
            .limit(1)
            .get();
        if (query.docs.isEmpty) {
          throw Exception('Username or email not found.');
        }
        emailToLogin = query.docs.first.data()['email'];
      }
      await _auth.signInWithEmailAndPassword(
          email: emailToLogin, password: password);
    } on fb_auth.FirebaseAuthException catch (e) {
      throw Exception('Login failed: ${e.message}');
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
      _user = userCredential.user;
      if (_user != null) {
        await _user!.updateDisplayName(name.trim());
        UserProfile newUserProfile = UserProfile(
          uid: _user!.uid,
          username: usernameLower,
          displayName: name.trim(),
          email: email.trim().toLowerCase(),
          level: 1,
          experience: 0,
          postsCount: 0,
          hikeStats: HikeStats(),
        );
        await _firestore
            .collection('users')
            .doc(_user!.uid)
            .set(newUserProfile.toFirestore());
        _userProfile = newUserProfile;
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      throw Exception('Registration failed: ${e.message}');
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
