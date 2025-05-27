// lib/widgets/add_hike_plan_form.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hike_plan_model.dart';

class AddHikePlanForm extends StatefulWidget {
  const AddHikePlanForm({super.key});

  @override
  State<AddHikePlanForm> createState() => _AddHikePlanFormState();
}

class _AddHikePlanFormState extends State<AddHikePlanForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _lengthController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _pickDate(BuildContext context, bool isStartDate) async {
    final initialDate = (isStartDate ? _startDate : _endDate) ?? DateTime.now();
    final firstDate =
        isStartDate ? DateTime.now() : (_startDate ?? DateTime.now());

    if (!mounted) return; // Varmistus ennen async-kutsua

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate.subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: isStartDate ? 'VALITSE ALKUPÄIVÄ' : 'VALITSE LOPPUPÄIVÄ',
      confirmText: 'VALITSE',
      cancelText: 'PERUUTA',
      locale: const Locale('fi', 'FI'),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _submitForm() {
    if (!mounted) return;

    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valitse vaelluksen aloituspäivämäärä.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final newPlan = HikePlan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        hikeName: _nameController.text.trim(),
        location: _locationController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate,
        lengthKm: _lengthController.text.trim().isNotEmpty
            ? double.tryParse(
                _lengthController.text.trim().replaceAll(',', '.'))
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        status: HikeStatus.planned,
      );
      if (mounted) {
        Navigator.of(context).pop(newPlan);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _lengthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    late DateFormat dateFormat;
    try {
      dateFormat = DateFormat('d.M.yyyy', 'fi_FI');
    } catch (e) {
      print(
          "DateFormat('fi_FI') epäonnistui AddHikePlanFormissa: $e. Käytetään oletuslokaalia.");
      dateFormat = DateFormat('d.M.yyyy');
    }

    // Haetaan tekstikentille sopiva tyyli teemasta
    final TextStyle? inputTextStyle = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.onSurface, // Varmistetaan tekstin väri
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Luo uusi vaellussuunnitelma',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Vaelluksen nimi
              TextFormField(
                controller: _nameController,
                style: inputTextStyle,
                decoration: InputDecoration(
                  labelText: 'Vaelluksen nimi*',
                  hintText: 'Esim. Pääsiäisvaellus Kevolla',
                  prefixIcon: Icon(Icons.flag_outlined,
                      color: theme.colorScheme.primary),
                ),
                keyboardType: TextInputType.text, // <-- tämä sallii äöå
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Syötä vaelluksen nimi'
                    : null,
              ),
              const SizedBox(height: 16),

              // Sijainti
              TextFormField(
                controller: _locationController,
                style: inputTextStyle,
                decoration: InputDecoration(
                  labelText: 'Sijainti*',
                  hintText: 'Esim. Helvetinjärven kansallispuisto',
                  prefixIcon: Icon(Icons.location_on_outlined,
                      color: theme.colorScheme.primary),
                ),
                keyboardType: TextInputType.text, // <-- tämä sallii äöå
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Syötä vaelluksen sijainti'
                    : null,
              ),
              const SizedBox(height: 16),

              // Pituus
              TextFormField(
                controller: _lengthController,
                style: inputTextStyle,
                decoration: InputDecoration(
                  labelText: 'Pituus (km)',
                  hintText: 'Esim. 25.5',
                  prefixIcon: Icon(Icons.directions_walk_outlined,
                      color: theme.colorScheme.primary),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final val = value.trim().replaceAll(',', '.');
                    if (double.tryParse(val) == null)
                      return 'Syötä validi numero';
                    if (double.parse(val) < 0)
                      return 'Pituuden on oltava positiivinen';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              LayoutBuilder(
                builder: (context, constraints) {
                  bool useRow = constraints.maxWidth > 400;
                  return useRow
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: _buildDateField(context, theme,
                                    dateFormat, true, 'Aloituspäivä*')),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildDateField(context, theme,
                                    dateFormat, false, 'Lopetuspäivä')),
                          ],
                        )
                      : Column(
                          children: [
                            _buildDateField(context, theme, dateFormat, true,
                                'Aloituspäivä*'),
                            const SizedBox(height: 16),
                            _buildDateField(context, theme, dateFormat, false,
                                'Lopetuspäivä'),
                          ],
                        );
                },
              ),
              const SizedBox(height: 16),

              // Muistiinpanot
              TextFormField(
                controller: _notesController,
                style: inputTextStyle,
                decoration: InputDecoration(
                  labelText: 'Muistiinpanot',
                  hintText: 'Esim. Varusteet, reitti...',
                  prefixIcon: Icon(Icons.notes_outlined,
                      color: theme.colorScheme.primary),
                ),
                keyboardType: TextInputType.multiline, // <-- tämä sallii äöå
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Peruuta'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save_alt_outlined),
                    label: const Text('Tallenna'),
                    onPressed: _submitForm,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(BuildContext context, ThemeData theme,
      DateFormat dateFormat, bool isStartDate, String labelText) {
    final InputDecorationTheme inputTheme = theme.inputDecorationTheme;
    BorderRadius fieldBorderRadius = BorderRadius.circular(8.0);

    if (inputTheme.enabledBorder is OutlineInputBorder) {
      final outlineEnabledBorder =
          inputTheme.enabledBorder as OutlineInputBorder;
      fieldBorderRadius = outlineEnabledBorder.borderRadius;
    } else if (inputTheme.border is OutlineInputBorder) {
      final outlineBorder = inputTheme.border as OutlineInputBorder;
      fieldBorderRadius = outlineBorder.borderRadius;
    }

    final TextStyle? buttonTextStyle = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.normal,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(labelText,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.normal)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: Icon(Icons.calendar_today_outlined,
              color: theme.colorScheme.secondary),
          label: Text(
            (isStartDate ? _startDate : _endDate) == null
                ? 'Valitse päivä'
                : dateFormat.format((isStartDate ? _startDate : _endDate)!),
            style: buttonTextStyle,
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            side: theme.outlinedButtonTheme.style?.side?.resolve({}) ??
                BorderSide(
                    color: inputTheme.enabledBorder?.borderSide.color ??
                        theme.colorScheme.outline),
            shape: theme.outlinedButtonTheme.style?.shape?.resolve({}) ??
                RoundedRectangleBorder(borderRadius: fieldBorderRadius),
          ),
          onPressed: () => _pickDate(context, isStartDate),
        ),
      ],
    );
  }
}
