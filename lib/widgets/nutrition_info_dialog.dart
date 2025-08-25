import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NutritionInfoDialog extends StatefulWidget {
  final String foodName;
  final Map<String, double>? initialMacros;
  final Function(Map<String, double>) onSave;
  final String? subtitle; // Optional hint like "Enter values per 100 g/ml"

  const NutritionInfoDialog({
    super.key,
    required this.foodName,
    this.initialMacros,
    required this.onSave,
    this.subtitle,
  });

  @override
  State<NutritionInfoDialog> createState() => _NutritionInfoDialogState();
}

class _NutritionInfoDialogState extends State<NutritionInfoDialog> {
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatsController;

  @override
  void initState() {
    super.initState();
    _caloriesController = TextEditingController(
      text: widget.initialMacros?['calories']?.toStringAsFixed(1) ?? '',
    );
    _proteinController = TextEditingController(
      text: widget.initialMacros?['protein']?.toStringAsFixed(1) ?? '',
    );
    _carbsController = TextEditingController(
      text: widget.initialMacros?['carbs']?.toStringAsFixed(1) ?? '',
    );
    _fatsController = TextEditingController(
      text: widget.initialMacros?['fats']?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text(
        'Nutrition Info',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.foodName,
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.subtitle!,
              style: GoogleFonts.lato(
                fontSize: 12,
                color: theme.hintColor,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildNutritionInput('Calories (kcal)', _caloriesController,
              Icons.local_fire_department),
          const SizedBox(height: 12),
          _buildNutritionInput(
              'Protein (g)', _proteinController, Icons.fitness_center),
          const SizedBox(height: 12),
          _buildNutritionInput('Carbs (g)', _carbsController, Icons.grain),
          const SizedBox(height: 12),
          _buildNutritionInput('Fats (g)', _fatsController, Icons.water_drop),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveNutritionInfo,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildNutritionInput(
      String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _saveNutritionInfo() {
    String c = _caloriesController.text.replaceAll(',', '.');
    String p = _proteinController.text.replaceAll(',', '.');
    String cb = _carbsController.text.replaceAll(',', '.');
    String f = _fatsController.text.replaceAll(',', '.');
    final macros = {
      'calories': double.tryParse(c) ?? 0.0,
      'protein': double.tryParse(p) ?? 0.0,
      'carbs': double.tryParse(cb) ?? 0.0,
      'fats': double.tryParse(f) ?? 0.0,
    };
    widget.onSave(macros);
    Navigator.pop(context);
  }
}
