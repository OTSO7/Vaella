import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PortionPickerDialog extends StatefulWidget {
  final String title;
  final String baseUnit; // 'g' or 'ml'
  final double initialAmount;
  final String initialUnit; // e.g., 'g', 'ml', 'tsp', 'tbsp', 'dl', 'cup'
  final bool allowMacroBasisChoice; // whether to show the "per 100" toggle
  final bool initialIsPer100; // default state for the toggle
  final List<String>? allowedUnits; // optional restriction list

  const PortionPickerDialog({
    super.key,
    required this.title,
    required this.baseUnit,
    this.initialAmount = 100,
    this.initialUnit = 'g',
    this.allowMacroBasisChoice = true,
    this.initialIsPer100 = false,
    this.allowedUnits,
  });

  @override
  State<PortionPickerDialog> createState() => _PortionPickerDialogState();
}

class _PortionPickerDialogState extends State<PortionPickerDialog> {
  late final TextEditingController _amountController;
  late String _selectedUnit;
  late bool _isPer100;

  static const List<String> _units = ['g', 'ml', 'tsp', 'tbsp', 'dl', 'cup'];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: _fmt(widget.initialAmount));
    _selectedUnit = widget.initialUnit;
    _isPer100 = widget.initialIsPer100;
    // Ensure selected unit is allowed
    final allowed = _allowedUnitList();
    if (!allowed.contains(_selectedUnit)) {
      _selectedUnit = allowed.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text(
        widget.title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: const Icon(Icons.scale_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: _allowedUnitList()
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedUnit = v ?? _selectedUnit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.allowMacroBasisChoice) ...[
            Row(
              children: [
                Switch(
                  value: _isPer100,
                  onChanged: (v) => setState(() => _isPer100 = v),
                ),
                Expanded(
                  child: Text(
                    'Nutrition values are per 100 ${_selectedUnit == 'g' ? 'g' : 'ml'}',
                    style: GoogleFonts.lato(
                      color: theme.colorScheme.onSurface.withOpacity(0.85),
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4.0),
            ),
          ] else ...[
            Text(
              'Scaling against 100 ${widget.baseUnit}',
              style: GoogleFonts.lato(
                fontSize: 12,
                color: theme.hintColor,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _save() {
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    Navigator.pop<Map<String, dynamic>>(context, {
      'amount': amount,
      'unit': _selectedUnit,
      'isPer100': _isPer100,
      'baseUnit': (_selectedUnit == 'g' ? 'g' : 'ml'),
    });
  }

  List<String> _allowedUnitList() {
    if (widget.allowedUnits != null && widget.allowedUnits!.isNotEmpty) {
      return widget.allowedUnits!;
    }
    if (widget.baseUnit == 'g') {
      return ['g'];
    }
    return ['ml', 'tsp', 'tbsp', 'dl', 'cup'];
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
