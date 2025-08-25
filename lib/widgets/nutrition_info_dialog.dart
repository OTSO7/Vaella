import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NutritionInfoDialog extends StatefulWidget {
  final String foodName;
  final Map<String, double>? initialMacros;
  final Function(Map<String, double>) onSave;
  final String? subtitle;

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
    _caloriesController =
        TextEditingController(text: _fmt(widget.initialMacros?['calories']));
    _proteinController =
        TextEditingController(text: _fmt(widget.initialMacros?['protein']));
    _carbsController =
        TextEditingController(text: _fmt(widget.initialMacros?['carbs']));
    _fatsController =
        TextEditingController(text: _fmt(widget.initialMacros?['fats']));
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
      content: SingleChildScrollView(
        child: Column(
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
            _buildNutritionInput(
              'Calories (kcal)',
              _caloriesController,
              Icons.local_fire_department,
              suffix: 'kcal',
            ),
            const SizedBox(height: 12),
            _buildNutritionInput(
              'Protein (g)',
              _proteinController,
              Icons.fitness_center,
              suffix: 'g',
            ),
            const SizedBox(height: 12),
            _buildNutritionInput('Carbs (g)', _carbsController, Icons.grain,
                suffix: 'g'),
            const SizedBox(height: 12),
            _buildNutritionInput('Fats (g)', _fatsController, Icons.water_drop,
                suffix: 'g'),
          ],
        ),
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
    String label,
    TextEditingController controller,
    IconData icon, {
    String? suffix,
  }) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixText: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ).applyDefaults(Theme.of(context).inputDecorationTheme).copyWith(
            labelStyle: GoogleFonts.lato(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
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
      'calories': _safeNum(c),
      'protein': _safeNum(p),
      'carbs': _safeNum(cb),
      'fats': _safeNum(f),
    };
    widget.onSave(macros);
    Navigator.pop(context);
  }

  double _safeNum(String v) {
    final n = double.tryParse(v.trim());
    if (n == null || !n.isFinite) return 0.0;
    return n < 0 ? 0.0 : n;
  }

  String _fmt(double? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
