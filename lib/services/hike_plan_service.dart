// lib/services/hike_plan_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/hike_plan_model.dart';

class HikePlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? getUserId() {
    final userId = _auth.currentUser?.uid;
    print('HikePlanService: getUserId() returned: $userId');
    return userId;
  }

  Stream<List<HikePlan>> getActiveHikePlans() {
    String? userId = getUserId();
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('plans')
        .where('status', whereIn: [
          HikeStatus.planned.toString().split('.').last,
          HikeStatus.upcoming.toString().split('.').last,
          HikeStatus.cancelled.toString().split('.').last,
        ])
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) => HikePlan.fromFirestore(doc))
                .toList();
          } catch (e) {
            print(
                "HikePlanService: Error mapping active plans from Firestore: $e");
            return [];
          }
        });
  }

  Stream<List<HikePlan>> getCompletedHikePlans() {
    String? userId = getUserId();
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('plans')
        .where('status',
            isEqualTo: HikeStatus.completed.toString().split('.').last)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs.map((doc) => HikePlan.fromFirestore(doc)).toList();
      } catch (e) {
        print(
            "HikePlanService: Error mapping completed plans from Firestore: $e");
        return [];
      }
    });
  }

  // NEW METHOD: Stream for a single HikePlan
  Stream<HikePlan?> getHikePlanStream(String planId) {
    String? userId = getUserId();
    if (userId == null) {
      print('HikePlanService: Cannot get plan stream, user not logged in.');
      return Stream.value(null); // Return empty stream if no user
    }
    print(
        'HikePlanService: Subscribing to plan stream for $planId under user $userId');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('plans')
        .doc(planId)
        .snapshots()
        .map((docSnapshot) {
      if (docSnapshot.exists && docSnapshot.data() != null) {
        print('HikePlanService: Plan $planId data received from stream.');
        return HikePlan.fromFirestore(docSnapshot);
      } else {
        print('HikePlanService: Plan $planId not found or no data.');
        return null;
      }
    });
  }

  Future<void> addHikePlan(HikePlan plan) async {
    String? userId = getUserId();
    if (userId == null) {
      throw Exception(
          "HikePlanService: Ei kirjautunutta käyttäjää. Vaellussuunnitelmaa ei voida lisätä.");
    }
    print('HikePlanService: Adding plan ${plan.id} for user $userId');
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('plans')
          .doc(plan.id)
          .set(plan.toFirestore());
      print('HikePlanService: Plan ${plan.id} added successfully.');
    } catch (e) {
      print('HikePlanService: Error adding plan ${plan.id}: $e');
      rethrow;
    }
  }

  Future<HikePlan> updateHikePlan(HikePlan plan) async {
    print('HikePlanService: Attempting to update plan ${plan.id}');
    String? userId = getUserId();
    if (userId == null) {
      print('HikePlanService: Update failed - No logged in user.');
      throw Exception(
          "HikePlanService: Ei kirjautunutta käyttäjää. Vaellussuunnitelmaa ei voida päivittää.");
    }

    print('HikePlanService: Updating plan ${plan.id} for user $userId');
    final planData = plan.toFirestore();
    print(
        'HikePlanService: Plan packingList data being sent: ${plan.packingList.map((item) => item.name).toList()}');
    print('HikePlanService: Plan toFirestore() map: $planData');

    try {
      final planRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('plans')
          .doc(plan.id);

      await planRef.update(planData);
      print('HikePlanService: Plan ${plan.id} updated successfully.');

      // Fetch the updated document from Firestore to ensure we have the latest data
      final updatedDoc = await planRef.get();
      // Return the updated HikePlan object
      return HikePlan.fromFirestore(updatedDoc);
    } catch (e) {
      print('HikePlanService: Error updating plan ${plan.id}: $e');
      rethrow;
    }
  }

  Future<void> deleteHikePlan(String planId) async {
    String? userId = getUserId();
    if (userId == null) {
      throw Exception(
          "HikePlanService: Ei kirjautunutta käyttäjää. Vaellussuunnitelmaa ei voida poistaa.");
    }
    print('HikePlanService: Deleting plan $planId for user $userId');
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('plans')
          .doc(planId)
          .delete();
      print('HikePlanService: Plan $planId deleted successfully.');
    } catch (e) {
      print('HikePlanService: Error deleting plan $planId: $e');
      rethrow;
    }
  }
}
