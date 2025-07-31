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
      _setLoading(true);
      _user = firebaseUser;
      if (_user != null) {
        await _fetchUserProfile();
      } else {
        _userProfile = null;
      }
      _setLoading(false);
    });
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  // --- KÄYTTÄJIEN JA SEURAAMISEN HALLINTA ---

  Future<UserProfile> fetchUserProfileById(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception('User not found.');
      }
      UserProfile profile = UserProfile.fromFirestore(userDoc.data()!, userId);

      if (!isLoggedIn) {
        profile = profile.copyWith(relationToCurrentUser: UserRelation.unknown);
      } else if (userId == _user!.uid) {
        profile = profile.copyWith(relationToCurrentUser: UserRelation.self);
      } else {
        if (_userProfile == null) await _fetchUserProfile();
        final isFollowing =
            _userProfile?.followingIds.contains(userId) ?? false;
        profile = profile.copyWith(
          relationToCurrentUser:
              isFollowing ? UserRelation.following : UserRelation.notFollowing,
        );
      }
      return profile;
    } catch (e) {
      print('Error fetching profile for $userId: $e');
      rethrow;
    }
  }

  Future<void> followUser(String userIdToFollow) async {
    if (!isLoggedIn || _user!.uid == userIdToFollow) return;
    await _firestore.runTransaction((transaction) async {
      transaction.update(_firestore.collection('users').doc(_user!.uid), {
        'followingIds': FieldValue.arrayUnion([userIdToFollow])
      });
      transaction.update(_firestore.collection('users').doc(userIdToFollow), {
        'followerIds': FieldValue.arrayUnion([_user!.uid])
      });
    });
    if (_userProfile != null &&
        !_userProfile!.followingIds.contains(userIdToFollow)) {
      _userProfile!.followingIds.add(userIdToFollow);
      notifyListeners();
    }
  }

  Future<void> unfollowUser(String userIdToUnfollow) async {
    if (!isLoggedIn) return;
    await _firestore.runTransaction((transaction) async {
      transaction.update(_firestore.collection('users').doc(_user!.uid), {
        'followingIds': FieldValue.arrayRemove([userIdToUnfollow])
      });
      transaction.update(_firestore.collection('users').doc(userIdToUnfollow), {
        'followerIds': FieldValue.arrayRemove([_user!.uid])
      });
    });
    if (_userProfile != null) {
      _userProfile!.followingIds.remove(userIdToUnfollow);
      notifyListeners();
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
      print('Error synchronizing post count: $e');
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
    if (_userProfile == null || !isLoggedIn || _userProfile!.postsCount <= 0)
      return;
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

  Future<void> _fetchUserProfile() async {
    if (_user == null) {
      _userProfile = null;
      notifyListeners();
      return;
    }
    try {
      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(_user!.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        _userProfile = UserProfile.fromFirestore(userDoc.data()!, _user!.uid);
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
        );
        await _firestore
            .collection('users')
            .doc(_user!.uid)
            .set(_userProfile!.toFirestore());
      }
    } catch (e) {
      print('Error fetching user profile: $e');
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
      print('Error updating user profile in Firestore: $e');
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
    _user = null;
    _userProfile = null;
    notifyListeners();
  }
}
