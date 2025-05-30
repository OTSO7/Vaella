import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import '../models/hike_plan_model.dart';
import '../widgets/map_picker_page.dart';

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
  double? _latitude;
  double? _longitude;

  List<Map<String, dynamic>> _locationSuggestions = [];
  Timer? _debounce;
  ValueNotifier<bool> _isSearchingLocation = ValueNotifier(false);

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
      _latitude = widget.existingPlan!.latitude;
      _longitude = widget.existingPlan!.longitude;
    }

    _locationController.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.removeListener(_onLocationChanged);
    _locationController.dispose();
    _lengthController.dispose();
    _notesController.dispose();
    _isSearchingLocation.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onLocationChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      _searchLocationSuggestions(_locationController.text.trim());
    });
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
      helpText: isStartDate ? 'SELECT START DATE' : 'SELECT END DATE',
      confirmText: 'SELECT',
      cancelText: 'CANCEL',
      locale: const Locale('en', 'US'),
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

  Future<void> _searchLocationSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _locationSuggestions = [];
        _isSearchingLocation.value = false;
      });
      return;
    }

    _isSearchingLocation.value = true;

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=7&addressdetails=1&extratags=1');

    try {
      final response = await http.get(url, headers: {
        'User-Agent':
            'TrekNoteApp/1.0 (contact@treknote.com)' // CHANGE THIS TO YOUR OWN EMAIL/NAME!
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _locationSuggestions =
                data.map((item) => item as Map<String, dynamic>).toList();
          });
        }
      } else {
        print('Nominatim API error: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Location search failed (error code: ${response.statusCode})'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      print('Location search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location search failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _isSearchingLocation.value = false;
    }
  }

  void _selectLocationSuggestion(Map<String, dynamic> suggestion) {
    String shortLocationName = suggestion['display_name'] as String;
    if (suggestion.containsKey('address')) {
      final address = suggestion['address'];
      List<String> parts = [];
      if (address.containsKey('name'))
        parts.add(address['name']);
      else if (address.containsKey('road')) parts.add(address['road']);

      if (address.containsKey('city'))
        parts.add(address['city']);
      else if (address.containsKey('town'))
        parts.add(address['town']);
      else if (address.containsKey('village')) parts.add(address['village']);

      if (address.containsKey('county')) parts.add(address['county']);
      if (address.containsKey('state')) parts.add(address['state']);
      if (address.containsKey('country')) parts.add(address['country']);

      if (parts.isNotEmpty) {
        shortLocationName = parts.take(3).join(', ');
        if (shortLocationName.length > 50 && parts.length > 2) {
          shortLocationName = parts.take(2).join(', ');
        }
      }
    }
    if (shortLocationName.length > 50 &&
        suggestion['display_name'].length > 50) {
      final rawParts =
          suggestion['display_name'].split(',').map((e) => e.trim()).toList();
      shortLocationName = rawParts.take(3).join(', ');
      if (shortLocationName.length > 50 && rawParts.length > 2) {
        shortLocationName = rawParts.take(2).join(', ');
      }
    }

    setState(() {
      _locationController.text = shortLocationName;
      _latitude = double.tryParse(suggestion['lat'] ?? '');
      _longitude = double.tryParse(suggestion['lon'] ?? '');
      _locationSuggestions = [];
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Location "$shortLocationName" selected. Coordinates: ${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)}'),
          backgroundColor: Colors.green[700],
        ),
      );
    }
  }

  Future<void> _pickLocationFromMap() async {
    final LatLng? pickedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerPage(
          initialLocation: LatLng(_latitude ?? 60.4518, _longitude ?? 22.2666),
        ),
      ),
    );

    if (pickedLocation != null && mounted) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          pickedLocation.latitude,
          pickedLocation.longitude,
          localeIdentifier: 'en_US',
        );

        String displayAddress = 'Unknown location';
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          List<String?> addressParts = [
            placemark.name,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country,
          ];
          displayAddress = addressParts
              .where((element) => element != null && element.isNotEmpty)
              .join(', ');

          if (placemark.locality != null && placemark.country != null) {
            displayAddress = '${placemark.locality}, ${placemark.country}';
          } else if (placemark.name != null && placemark.locality != null) {
            displayAddress = '${placemark.name}, ${placemark.locality}';
          } else if (placemark.thoroughfare != null &&
              placemark.locality != null) {
            displayAddress = '${placemark.thoroughfare}, ${placemark.locality}';
          }
        }

        setState(() {
          _locationController.text = displayAddress;
          _latitude = pickedLocation.latitude;
          _longitude = pickedLocation.longitude;
          _locationSuggestions = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Location "$displayAddress" selected from map. Coordinates: ${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)}'),
            backgroundColor: Colors.green[700],
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Geocoding failed: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _submitForm() {
    if (!mounted) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the hike start date.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_locationController.text.trim().isNotEmpty &&
        (_latitude == null || _longitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Select a valid location using autocomplete or the map.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Hike location is required and must be selected from the map or suggestions.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

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
        latitude: _latitude,
        longitude: _longitude,
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
        latitude: _latitude,
        longitude: _longitude,
      );
    }

    if (mounted) {
      Navigator.of(context).pop(resultPlan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    late DateFormat dateFormat;
    try {
      dateFormat = DateFormat('d.M.yyyy', 'en_US');
    } catch (e) {
      print(
          "DateFormat('en_US') failed in AddHikePlanForm: $e. Using default locale.");
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
              ? 'Create new hike plan'
              : 'Edit hike plan',
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
                      labelText: 'Hike name*',
                      hintText: 'E.g. Easter hike in Kevo',
                      prefixIcon: Icon(Icons.flag_outlined,
                          color: theme.colorScheme.primary),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                    ),
                    keyboardType: TextInputType.text,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Enter hike name'
                            : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _locationController,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Location*',
                      hintText: 'Start typing a location or pick from map...',
                      prefixIcon: Icon(Icons.location_on_outlined,
                          color: theme.colorScheme.primary),
                      suffixIcon: ValueListenableBuilder<bool>(
                        valueListenable: _isSearchingLocation,
                        builder: (context, isSearching, child) {
                          if (isSearching) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          } else {
                            return IconButton(
                              icon: const Icon(Icons.map_outlined),
                              tooltip: 'Pick location from map',
                              onPressed: _pickLocationFromMap,
                            );
                          }
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Hike location is required';
                      }
                      return null;
                    },
                  ),
                  if (_locationSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _locationSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _locationSuggestions[index];
                          String displayCandidate =
                              suggestion['display_name'] as String;

                          if (suggestion.containsKey('address')) {
                            final address = suggestion['address'];
                            List<String> parts = [];
                            if (address.containsKey('name')) {
                              parts.add(address['name']);
                            } else if (address.containsKey('road')) {
                              parts.add(address['road']);
                            }

                            if (address.containsKey('city')) {
                              parts.add(address['city']);
                            } else if (address.containsKey('town')) {
                              parts.add(address['town']);
                            } else if (address.containsKey('village')) {
                              parts.add(address['village']);
                            }

                            if (address.containsKey('county') &&
                                !parts.contains(address['county'])) {
                              parts.add(address['county']);
                            }
                            if (address.containsKey('state') &&
                                !parts.contains(address['state'])) {
                              parts.add(address['state']);
                            }
                            if (address.containsKey('country') &&
                                !parts.contains(address['country'])) {
                              parts.add(address['country']);
                            }

                            if (parts.isNotEmpty) {
                              displayCandidate = parts.take(3).join(', ');
                              if (displayCandidate.length > 50 &&
                                  parts.length > 2) {
                                displayCandidate = parts.take(2).join(', ');
                              }
                            }
                          }
                          if (displayCandidate.length > 50 &&
                              suggestion['display_name'].length > 50) {
                            final rawParts = suggestion['display_name']
                                .split(',')
                                .map((e) => e.trim())
                                .toList();
                            displayCandidate = rawParts.take(3).join(', ');
                            if (displayCandidate.length > 50 &&
                                rawParts.length > 2) {
                              displayCandidate = rawParts.take(2).join(', ');
                            }
                          }

                          return ListTile(
                            leading: const Icon(Icons.place),
                            title: Text(displayCandidate),
                            onTap: () => _selectLocationSuggestion(suggestion),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _lengthController,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Length (km)',
                      hintText: 'E.g. 25.5',
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
                        if (double.tryParse(val) == null)
                          return 'Enter a valid number';
                        if (double.parse(val) < 0)
                          return 'Length must be positive';
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
                                        dateFormat, true, 'Start date*')),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: _buildDateField(context, theme,
                                        dateFormat, false, 'End date')),
                              ],
                            )
                          : Column(
                              children: [
                                _buildDateField(context, theme, dateFormat,
                                    true, 'Start date*'),
                                const SizedBox(height: 18),
                                _buildDateField(context, theme, dateFormat,
                                    false, 'End date'),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _notesController,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'E.g. gear, route, packing list...',
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
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt_outlined, size: 20),
                  label: Text(widget.existingPlan == null ? 'Save' : 'Update',
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
        BorderSide(color: theme.colorScheme.outline!, width: 1.5);

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
              color: theme.colorScheme.onBackground.withOpacity(0.8),
              fontSize: 14,
            )),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: Icon(Icons.calendar_today_outlined,
              color: theme.colorScheme.secondary, size: 20),
          label: Text(
            (isStartDate ? _startDate : _endDate) == null
                ? 'Select date'
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
