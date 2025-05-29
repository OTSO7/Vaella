import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hike_plan_model.dart';

class AddHikePlanForm extends StatefulWidget {
  final HikePlan? existingPlan;

  const AddHikePlanForm({super.key, this.existingPlan});

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

  @override
  void initState() {
    super.initState();
    if (widget.existingPlan != null) {
      _nameController.text = widget.existingPlan!.hikeName;
      _locationController.text = widget.existingPlan!.location;
      if (widget.existingPlan!.lengthKm != null) {
        _lengthController.text =
            widget.existingPlan!.lengthKm!.toStringAsFixed(1);
      }
      _notesController.text = widget.existingPlan!.notes ?? '';
      _startDate = widget.existingPlan!.startDate;
      _endDate = widget.existingPlan!.endDate;
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

  Future<void> _pickDate(BuildContext context, bool isStartDate) async {
    final initialDate = (isStartDate ? _startDate : _endDate) ?? DateTime.now();
    final firstDate = isStartDate
        ? DateTime.now().subtract(const Duration(days: 365 * 2))
        : (_startDate ?? DateTime.now());

    if (!mounted) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: isStartDate ? 'VALITSE ALKUPÄIVÄ' : 'VALITSE LOPPUPÄIVÄ',
      confirmText: 'VALITSE',
      cancelText: 'PERUUTA',
      locale: const Locale('fi', 'FI'),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).cardColor,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          child: child!,
        );
      },
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
      HikePlan resultPlan;
      if (widget.existingPlan != null) {
        resultPlan = widget.existingPlan!.copyWith(
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
        );
      } else {
        resultPlan = HikePlan(
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
        );
      }

      if (mounted) {
        Navigator.of(context).pop(resultPlan);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    late DateFormat dateFormat;
    try {
      dateFormat = DateFormat('d.M.yyyy', 'fi_FI');
    } catch (e) {
      print(
          "DateFormat('fi_FI') epäonnistui AddHikePlanFormissa: $e. Käytetään oletuslokaalia.");
      dateFormat = DateFormat('d.M.yyyy');
    }

    final TextStyle? inputTextStyle = textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurface,
      fontSize: 16,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        Text(
          widget.existingPlan == null
              ? 'Luo uusi vaellussuunnitelma'
              : 'Muokkaa vaellussuunnitelmaa',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            fontSize: 26,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Vaelluksen nimi*',
                      hintText: 'Esim. Pääsiäisvaellus Kevolla',
                      prefixIcon: Icon(Icons.flag_outlined,
                          color: theme.colorScheme.primary),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                    ),
                    keyboardType: TextInputType.text,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Syötä vaelluksen nimi'
                            : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _locationController,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Sijainti*',
                      hintText: 'Esim. Helvetinjärven kansallispuisto',
                      prefixIcon: Icon(Icons.location_on_outlined,
                          color: theme.colorScheme.primary),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                    ),
                    keyboardType: TextInputType.text,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Syötä vaelluksen sijainti'
                            : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _lengthController,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Pituus (km)',
                      hintText: 'Esim. 25.5',
                      prefixIcon: Icon(Icons.directions_walk_outlined,
                          color: theme.colorScheme.primary),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final val = value.trim().replaceAll(',', '.');
                        if (double.tryParse(val) == null) {
                          return 'Syötä validi numero';
                        }
                        if (double.parse(val) < 0) {
                          return 'Pituuden on oltava positiivinen';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
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
                                _buildDateField(context, theme, dateFormat,
                                    true, 'Aloituspäivä*'),
                                const SizedBox(height: 18),
                                _buildDateField(context, theme, dateFormat,
                                    false, 'Lopetuspäivä'),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _notesController,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Muistiinpanot (valinnainen)',
                      hintText: 'Esim. Varusteet, reitti, pakkauslista...',
                      prefixIcon: Icon(Icons.notes_outlined,
                          color: theme.colorScheme.primary),
                      alignLabelWithHint: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                    ),
                    keyboardType: TextInputType.multiline,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 20,
            right: 20,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: TextButton(
                  onPressed: () {
                    if (mounted) Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Peruuta'),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt_outlined, size: 20),
                  label: Text(
                      widget.existingPlan == null ? 'Tallenna' : 'Päivitä',
                      style: const TextStyle(fontSize: 16)),
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(BuildContext context, ThemeData theme,
      DateFormat dateFormat, bool isStartDate, String labelText) {
    BorderRadius fieldBorderRadius = BorderRadius.circular(12.0);
    BorderSide fieldBorderSide =
        BorderSide(color: theme.colorScheme.outline, width: 1.5);

    if (theme.inputDecorationTheme.enabledBorder is OutlineInputBorder) {
      final outlineEnabledBorder =
          theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
      fieldBorderRadius = outlineEnabledBorder.borderRadius;
      fieldBorderSide = outlineEnabledBorder.borderSide;
    } else if (theme.inputDecorationTheme.border is OutlineInputBorder) {
      final outlineBorder =
          theme.inputDecorationTheme.border as OutlineInputBorder;
      fieldBorderRadius = outlineBorder.borderRadius;
      fieldBorderSide = outlineBorder.borderSide;
    }

    final TextStyle? buttonTextStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.9),
      fontWeight: FontWeight.w500,
      fontSize: 16,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(labelText,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontSize: 14,
            )),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: Icon(Icons.calendar_today_outlined,
              color: theme.colorScheme.secondary, size: 20),
          label: Text(
            (isStartDate ? _startDate : _endDate) == null
                ? 'Valitse päivä'
                : dateFormat.format((isStartDate ? _startDate : _endDate)!),
            style: buttonTextStyle,
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            side: fieldBorderSide,
            shape: RoundedRectangleBorder(borderRadius: fieldBorderRadius),
            foregroundColor: theme.colorScheme.onSurface,
          ),
          onPressed: () => _pickDate(context, isStartDate),
        ),
      ],
    );
  }
}
