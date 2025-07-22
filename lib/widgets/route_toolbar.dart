import 'package:flutter/material.dart';

class RouteToolbar extends StatelessWidget {
  final VoidCallback onUndo;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final double distanceMeters;

  const RouteToolbar({
    super.key,
    required this.onUndo,
    required this.onCancel,
    required this.onSave,
    required this.distanceMeters,
  });

  @override
  Widget build(BuildContext context) {
    final km = (distanceMeters / 1000).toStringAsFixed(2);
    return Container(
      color: Colors.white70,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('Pituus: $km km', style: const TextStyle(fontSize: 16)),
          const Spacer(),
          IconButton(onPressed: onUndo, icon: const Icon(Icons.undo)),
          ElevatedButton(onPressed: onCancel, child: const Text('Peruuta')),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: onSave, child: const Text('Tallenna')),
        ],
      ),
    );
  }
}
