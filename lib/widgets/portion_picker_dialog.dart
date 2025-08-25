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
    final allowedUnits = _allowedUnitList();

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text(
        widget.title,
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
            Text('Portion',
                style: GoogleFonts.lato(
                    fontSize: 13, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedUnit,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedUnit = v);
                  },
                  items: allowedUnits
                      .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(u),
                          ))
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.allowMacroBasisChoice)
              SwitchListTile.adaptive(
                title: const Text('Values are per 100 base units'),
                subtitle: Text('Base: ${widget.baseUnit}'),
                value: _isPer100,
                onChanged: (v) => setState(() => _isPer100 = v),
                contentPadding: EdgeInsets.zero,
              )
            else
              Text('Base: ${widget.baseUnit}',
                  style: GoogleFonts.lato(
                      fontSize: 13, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: const Text('Apply'),
          onPressed: _save,
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
