import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/hike_plan_model.dart';
// Lisää tämä
// Lisää tämä

class HikePlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Haetaan käyttäjän ID suoraan FirebaseAuthista.
  // Tämä olettaa, että FirebaseAuth on jo kuunneltuna AuthProviderissa
  // ja sen tila on ajan tasalla.
  String? getUserId() {
    return _auth.currentUser?.uid;
  }

  Stream<List<HikePlan>> getHikePlans() async* {
    String? userId = getUserId();
    if (userId == null) {
      print("Ei kirjautunutta käyttäjää, ei voida hakea vaellussuunnitelmia.");
      yield [];
      return;
    }

    yield* _firestore
        .collection('users')
        .doc(userId)
        .collection('plans')
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => HikePlan.fromFirestore(doc)).toList();
    });
  }

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
        .doc(plan.id)
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
