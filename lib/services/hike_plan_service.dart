// lib/services/hike_plan_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/hike_plan_model.dart';

class HikePlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? getUserId() {
    return _auth.currentUser?.uid;
  }

  Stream<List<HikePlan>> getActiveHikePlans() {
    // Poistettu async* ja yield*, palautetaan suoraan stream
    String? userId = getUserId();
    if (userId == null) {
      return Stream.value([]); // Palauta tyhjä stream, jos ei käyttäjää
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
          // Virheenkäsittely datan muunnoksessa voi olla hyödyllistä
          try {
            return snapshot.docs
                .map((doc) => HikePlan.fromFirestore(doc))
                .toList();
          } catch (e) {
            print("Error mapping active plans from Firestore: $e");
            return []; // Palauta tyhjä lista virhetilanteessa
          }
        });
  }

  Stream<List<HikePlan>> getCompletedHikePlans() {
    // Poistettu async* ja yield*
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
        print("Error mapping completed plans from Firestore: $e");
        return [];
      }
    });
  }

  // addHikePlan, updateHikePlan, deleteHikePlan pysyvät ennallaan
  Future<void> addHikePlan(HikePlan plan) async {
    String? userId = getUserId();
    if (userId == null) {
      throw Exception(
          "Ei kirjautunutta käyttäjää. Vaellussuunnitelmaa ei voida lisätä.");
    }
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('plans')
        .doc(plan.id) // Käytetään plan.id:tä, jonka Uuid luo mallissa
        .set(plan.toFirestore());
  }

  Future<void> updateHikePlan(HikePlan plan) async {
    String? userId = getUserId();
    if (userId == null) {
      throw Exception(
          "Ei kirjautunutta käyttäjää. Vaellussuunnitelmaa ei voida päivittää.");
    }
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('plans')
        .doc(plan.id)
        .update(plan.toFirestore());
  }

  Future<void> deleteHikePlan(String planId) async {
    String? userId = getUserId();
    if (userId == null) {
      throw Exception(
          "Ei kirjautunutta käyttäjää. Vaellussuunnitelmaa ei voida poistaa.");
    }
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('plans')
        .doc(planId)
        .delete();
  }
}
