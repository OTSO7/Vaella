// (Oletetaan sijainti: lib/models/packing_list_models.dart)
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// Kategoria-malli
class PackingListCategory {
  final String id;
  final String name;
  final IconData icon;
  final int order; // Järjestystä varten

  PackingListCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.order = 0,
  });
}

// Yksittäisen pakattavan tavaran malli
class PackingListItem {
  String id;
  String name;
  String categoryId; // Mihin kategoriaan kuuluu
  bool isPacked;
  int quantity;
  String? notes;
  // int? weightInGrams; // Valinnainen paino, voidaan lisätä myöhemmin
  // bool addedByUser; // Oletuksena käyttäjän lisäämä

  PackingListItem({
    String? id,
    required this.name,
    required this.categoryId,
    this.isPacked = false,
    this.quantity = 1,
    this.notes,
    // this.weightInGrams,
    // this.addedByUser = true,
  }) : this.id = id ?? const Uuid().v4();

  PackingListItem copyWith({
    String? id,
    String? name,
    String? categoryId,
    bool? isPacked,
    int? quantity,
    String? notes,
    bool setNotesToNull = false,
  }) {
    return PackingListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      isPacked: isPacked ?? this.isPacked,
      quantity: quantity ?? this.quantity,
      notes: setNotesToNull ? null : (notes ?? this.notes),
    );
  }
}

// Oletuskategoriat (nämä voisi ladata myös esim. Firebasesta tai asetuksista)
List<PackingListCategory> defaultCategories = [
  PackingListCategory(
      id: 'essentials',
      name: 'Essentials & Safety',
      icon: Icons.health_and_safety_rounded,
      order: 0),
  PackingListCategory(
      id: 'gear',
      name: 'Gear & Equipment',
      icon: Icons.backpack_rounded,
      order: 1),
  PackingListCategory(
      id: 'clothes', name: 'Clothing', icon: Icons.checkroom_rounded, order: 2),
  PackingListCategory(
      id: 'sleeping',
      name: 'Sleep System',
      icon: Icons.king_bed_rounded,
      order: 3),
  PackingListCategory(
      id: 'cooking',
      name: 'Cooking & Kitchen',
      icon: Icons.outdoor_grill_rounded,
      order: 4),
  PackingListCategory(
      id: 'food',
      name: 'Food & Hydration',
      icon: Icons.restaurant_rounded,
      order: 5),
  PackingListCategory(
      id: 'hygiene',
      name: 'Hygiene & First Aid',
      icon: Icons.medical_services_rounded,
      order: 6),
  PackingListCategory(
      id: 'tools',
      name: 'Tools & Navigation',
      icon: Icons.explore_rounded,
      order: 7),
  PackingListCategory(
      id: 'personal',
      name: 'Personal Items',
      icon: Icons.person_search_rounded,
      order: 8),
  PackingListCategory(
      id: 'misc', name: 'Miscellaneous', icon: Icons.widgets_rounded, order: 9),
];
