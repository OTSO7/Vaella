// lib/widgets/complete_hike_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hike_plan_model.dart';

class CompleteHikeDialog extends StatefulWidget {
  final HikePlan plan;
  const CompleteHikeDialog({super.key, required this.plan});

  @override
  State<CompleteHikeDialog> createState() => _CompleteHikeDialogState();
}

class _CompleteHikeDialogState extends State<CompleteHikeDialog> {
  final _notesController = TextEditingController();
  int _rating = 0;

  @override
  void initState() {
    super.initState();
    // Lisätään suunnitelman vanhat muistiinpanot pohjaksi, jos niitä on
    _notesController.text = widget.plan.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop({
      'notes': _notesController.text.trim(),
      'rating': _rating,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Complete Your Hike!',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How was your adventure on "${widget.plan.hikeName}"?'),
            const SizedBox(height: 24),
            Text('Rate your experience', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 24),
            Text('Summary & Notes', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Add a summary of your experience...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _rating > 0
              ? _submit
              : null, // Nappi aktiivinen vasta kun arvosana on annettu
          child: const Text('Complete Hike'),
        ),
      ],
    );
  }
}
