// lib/models/packing_list_item.dart
import 'package:uuid/uuid.dart';

class PackingListItem {
  final String id;
  String name;
  bool isPacked;
  String category; // E.g., 'Clothing', 'Shelter', 'Food', 'Navigation'
  int quantity;
  String notes; // For specific details about the item

  PackingListItem({
    String? id,
    required this.name,
    this.isPacked = false,
    this.category = 'General',
    this.quantity = 1,
    this.notes = '',
  }) : id = id ?? const Uuid().v4();

  factory PackingListItem.fromMap(Map<String, dynamic> data) {
    return PackingListItem(
      id: data['id'],
      name: data['name'] ?? '',
      isPacked: data['isPacked'] ?? false,
      category: data['category'] ?? 'General',
      quantity: data['quantity'] ?? 1,
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isPacked': isPacked,
      'category': category,
      'quantity': quantity,
      'notes': notes,
    };
  }

  PackingListItem copyWith({
    String? id,
    String? name,
    bool? isPacked,
    String? category,
    int? quantity,
    String? notes,
  }) {
    return PackingListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      isPacked: isPacked ?? this.isPacked,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }
}
