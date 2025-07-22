import 'package:flutter/material.dart';

class RouteToolbar extends StatelessWidget {
  final VoidCallback onUndo;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final double distanceMeters;

  const RouteToolbar({
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('Pituus: $km km', style: TextStyle(fontSize: 16)),
          Spacer(),
          IconButton(onPressed: onUndo, icon: Icon(Icons.undo)),
          ElevatedButton(onPressed: onCancel, child: Text('Peruuta')),
          SizedBox(width: 8),
          ElevatedButton(onPressed: onSave, child: Text('Tallenna')),
        ],
      ),
    );
  }
}
