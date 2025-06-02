// lib/models/hike_plan_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

enum HikeStatus { planned, upcoming, completed, cancelled }

// UUSI: Avaimet valmistautumisen kohteille
class PrepItemKeys {
  static const String weather = 'weather';
  static const String dayPlanner = 'day_planner';
  static const String foodPlanner = 'food_planner';
  static const String packingList = 'packing_list';

  static List<String> get allKeys =>
      [weather, dayPlanner, foodPlanner, packingList];

  static String getDisplayName(String key) {
    switch (key) {
      case weather:
        return 'Sää tarkistettu';
      case dayPlanner:
        return 'Päiväsuunnitelma tehty';
      case foodPlanner:
        return 'Ruokasuunnitelma valmis';
      case packingList:
        return 'Pakkauslista laadittu';
      default:
        return key;
    }
  }
}

class HikePlan {
  final String id;
  final String hikeName;
  final String location;
  final DateTime startDate;
  final DateTime? endDate;
  final double? lengthKm;
  final String? notes;
  final HikeStatus status;
  final double? latitude;
  final double? longitude;
  final Map<String, bool> preparationItems; // UUSI KENTTÄ

  HikePlan({
    String? id,
    required this.hikeName,
    required this.location,
    required this.startDate,
    this.endDate,
    this.lengthKm,
    this.notes,
    HikeStatus? status, // Status voidaan laskea tai asettaa
    this.latitude,
    this.longitude,
    Map<String, bool>? preparationItems, // UUSI PARAMETRI
  })  : id = id ?? const Uuid().v4(),
        status = status ?? // Lasketaan status, jos sitä ei ole annettu
            (HikeStatus.cancelled == status
                ? HikeStatus.cancelled
                : // Säilytä peruutettu tila
                (endDate != null &&
                        DateTime(endDate.year, endDate.month, endDate.day)
                            .isBefore(DateTime(DateTime.now().year,
                                DateTime.now().month, DateTime.now().day)))
                    ? HikeStatus.completed
                    : (startDate.isBefore(
                            DateTime.now().add(const Duration(days: 1))))
                        ? HikeStatus.upcoming
                        : HikeStatus.planned),
        preparationItems =
            preparationItems ?? // Alustetaan kaikki falseksi, jos ei annettu
                {
                  PrepItemKeys.weather: false,
                  PrepItemKeys.dayPlanner: false,
                  PrepItemKeys.foodPlanner: false,
                  PrepItemKeys.packingList: false,
                };

  int get completedPreparationItems {
    return preparationItems.values.where((done) => done == true).length;
  }

  int get totalPreparationItems {
    return PrepItemKeys.allKeys.length;
  }

  factory HikePlan.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Alustetaan preparationItems Firestore-datasta tai oletusarvoilla
    Map<String, bool> prepItemsFromDb = {
      PrepItemKeys.weather: false,
      PrepItemKeys.dayPlanner: false,
      PrepItemKeys.foodPlanner: false,
      PrepItemKeys.packingList: false,
    };
    if (data['preparationItems'] != null && data['preparationItems'] is Map) {
      final Map<String, dynamic> itemsMap =
          data['preparationItems'] as Map<String, dynamic>;
      itemsMap.forEach((key, value) {
        if (value is bool && prepItemsFromDb.containsKey(key)) {
          prepItemsFromDb[key] = value;
        }
      });
    }

    return HikePlan(
      id: doc.id,
      hikeName: data['hikeName'] ?? '',
      location: data['location'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      lengthKm: (data['lengthKm'] as num?)?.toDouble(),
      notes: data['notes'],
      status: HikeStatus.values.firstWhere(
          // Käytetään toString().split('.').last, jotta vältetään enum-nimen muuttumisen aiheuttamat ongelmat
          (e) => e.toString().split('.').last == data['status'], orElse: () {
        // Turvallisempi oletusarvo
        DateTime startDate = (data['startDate'] as Timestamp).toDate();
        DateTime? endDate = (data['endDate'] as Timestamp?)?.toDate();
        if (endDate != null &&
            DateTime(endDate.year, endDate.month, endDate.day).isBefore(
                DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day))) return HikeStatus.completed;
        if (startDate.isBefore(DateTime.now().add(const Duration(days: 1))))
          return HikeStatus.upcoming;
        return HikeStatus.planned;
      }),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      preparationItems: prepItemsFromDb, // Käytetään alustettua karttaa
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hikeName': hikeName,
      'location': location,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'lengthKm': lengthKm,
      'notes': notes,
      'status': status
          .toString()
          .split('.')
          .last, // Tallenna enum-arvon nimi merkkijonona
      'latitude': latitude,
      'longitude': longitude,
      'preparationItems': preparationItems, // UUSI KENTTÄ
      // 'createdAt' ja 'updatedAt' voitaisiin lisätä automaattisesti FieldValue.serverTimestamp() avulla
      // Jos tämä on uusi dokumentti, 'createdAt'
      // Jos tämä on päivitys, 'updatedAt'
    };
  }

  HikePlan copyWith({
    String? id,
    String? hikeName,
    String? location,
    DateTime? startDate,
    DateTime? endDate, // Salli nullaus
    bool setEndDateToNull =
        false, // Lisätty tämä selkeyttämään nulliksi asettamista
    double? lengthKm, // Salli nullaus
    bool setLengthKmToNull = false,
    String? notes, // Salli nullaus
    bool setNotesToNull = false,
    HikeStatus? status,
    double? latitude, // Salli nullaus
    bool setLatitudeToNull = false,
    double? longitude, // Salli nullaus
    bool setLongitudeToNull = false,
    Map<String, bool>? preparationItems,
  }) {
    return HikePlan(
      id: id ?? this.id,
      hikeName: hikeName ?? this.hikeName,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: setEndDateToNull ? null : (endDate ?? this.endDate),
      lengthKm: setLengthKmToNull ? null : (lengthKm ?? this.lengthKm),
      notes: setNotesToNull ? null : (notes ?? this.notes),
      status: status ?? this.status,
      latitude: setLatitudeToNull ? null : (latitude ?? this.latitude),
      longitude: setLongitudeToNull ? null : (longitude ?? this.longitude),
      preparationItems: preparationItems ?? this.preparationItems,
    );
  }
}
