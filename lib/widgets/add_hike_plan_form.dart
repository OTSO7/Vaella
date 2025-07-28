import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../models/hike_plan_model.dart';
import '../services/location_service.dart';
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

  DateTime? _startDate;
  DateTime? _endDate;
  double? _latitude;
  double? _longitude;

  // Sijainninhaun muuttujat
  final LocationService _locationService = LocationService();
  List<LocationSuggestion> _suggestions = [];
  List<LocationSuggestion> _popularSuggestionsCache = [];
  Timer? _debounce;
  final FocusNode _locationFocusNode = FocusNode();
  bool _isSearching = false;
  bool _isSelectingLocation = false;

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
      _startDate = widget.existingPlan!.startDate;
      _endDate = widget.existingPlan!.endDate;
      _latitude = widget.existingPlan!.latitude;
      _longitude = widget.existingPlan!.longitude;
    }
    _locationController.addListener(_onTextChanged);
    _locationFocusNode.addListener(_onLocationFocusChanged);
    _fetchInitialSuggestions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.removeListener(_onTextChanged);
    _locationController.dispose();
    _lengthController.dispose();
    _debounce?.cancel();
    _locationFocusNode.removeListener(_onLocationFocusChanged);
    _locationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialSuggestions() async {
    _popularSuggestionsCache = await _locationService.getPopularLocations();
    if (_locationFocusNode.hasFocus && _locationController.text.isEmpty) {
      setState(() => _suggestions = _popularSuggestionsCache);
    }
  }

  void _onLocationFocusChanged() {
    if (_locationFocusNode.hasFocus && _locationController.text.isEmpty) {
      setState(() => _suggestions = _popularSuggestionsCache);
    } else if (!_locationFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _suggestions = []);
      });
    }
  }

  void _onTextChanged() {
    if (_isSelectingLocation) return;

    final query = _locationController.text;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().length < 2) {
        setState(() {
          _isSearching = false;
          _suggestions =
              _locationController.text.isEmpty ? _popularSuggestionsCache : [];
        });
        return;
      }
      if (mounted) setState(() => _isSearching = true);
      final results = await _locationService.searchLocations(query.trim());
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectLocationSuggestion(LocationSuggestion suggestion) {
    setState(() {
      _isSelectingLocation = true;
      String subtitle =
          suggestion.subtitle.replaceAll(suggestion.title, '').trim();
      final locationText =
          '${suggestion.title}${subtitle.isEmpty ? '' : ', $subtitle'}';

      _locationController.text = locationText;
      _latitude = suggestion.latitude;
      _longitude = suggestion.longitude;
      _suggestions = [];
    });
    FocusScope.of(context).unfocus();

    Future.delayed(const Duration(milliseconds: 100), () {
      _isSelectingLocation = false;
    });
  }

  void _showDateRangePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Select Hike Dates",
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: SfDateRangePicker(
                onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                  if (args.value is PickerDateRange) {
                    final range = args.value as PickerDateRange;
                    if (range.startDate != null) {
                      setState(() {
                        _startDate = range.startDate;
                        _endDate = range.endDate ?? range.startDate;
                      });
                    }
                  }
                },
                selectionMode: DateRangePickerSelectionMode.range,
                initialSelectedRange: _startDate != null
                    ? PickerDateRange(_startDate, _endDate)
                    : null,
                monthViewSettings:
                    const DateRangePickerMonthViewSettings(firstDayOfWeek: 1),
                headerStyle: DateRangePickerHeaderStyle(
                    textStyle:
                        GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton(
                child: const Text("Confirm"),
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    if (!mounted || !_formKey.currentState!.validate()) {
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a start date for the hike.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a valid location from suggestions.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    final now = DateTime.now();
    HikeStatus statusToSave = HikeStatus.planned;
    if (widget.existingPlan?.status == HikeStatus.cancelled) {
      statusToSave = HikeStatus.cancelled;
    } else if (_endDate != null &&
        DateTime(_endDate!.year, _endDate!.month, _endDate!.day)
            .isBefore(DateTime(now.year, now.month, now.day))) {
      statusToSave = HikeStatus.completed;
    } else if (_startDate!.isBefore(now.add(const Duration(days: 1)))) {
      statusToSave = HikeStatus.upcoming;
    }

    final resultPlan = HikePlan(
      id: widget.existingPlan?.id,
      hikeName: _nameController.text.trim(),
      location: _locationController.text.trim(),
      startDate: _startDate!,
      endDate: _endDate,
      lengthKm: _lengthController.text.trim().isNotEmpty
          ? double.tryParse(_lengthController.text.trim().replaceAll(',', '.'))
          : null,
      latitude: _latitude,
      longitude: _longitude,
      status: statusToSave,
    );

    if (mounted) {
      Navigator.of(context).pop(resultPlan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
          child: Text(
            widget.existingPlan == null ? 'Create New Hike Plan' : 'Edit Plan',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStyledTextFormField(
                    controller: _nameController,
                    labelText: 'Hike Name*',
                    hintText: 'e.g., Easter Hike in Kevo',
                    icon: Icons.flag_outlined,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Please enter a name for the hike'
                            : null,
                  ),
                  const SizedBox(height: 18),
                  _buildLocationField(context),
                  const SizedBox(height: 18),
                  _buildStyledTextFormField(
                    controller: _lengthController,
                    labelText: 'Length (km)',
                    hintText: 'e.g., 25.5',
                    icon: Icons.directions_walk_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final val = value.trim().replaceAll(',', '.');
                        if (double.tryParse(val) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(val) < 0) {
                          return 'Length must be a positive number';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildDateRangeField(context),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
        _buildBottomButtons(context),
      ],
    );
  }

  Widget _buildLocationField(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildStyledTextFormField(
          controller: _locationController,
          focusNode: _locationFocusNode,
          labelText: 'Location*',
          hintText: 'Search location or pick from map...',
          icon: Icons.location_on_outlined,
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2.0)),
                )
              : IconButton(
                  icon: const Icon(Icons.map_outlined),
                  tooltip: 'Select location from map',
                  onPressed: () async {
                    // KORJATTU: Määritellään oletussijainti, jos nykyistä ei ole.
                    const LatLng defaultLocation =
                        LatLng(62.5, 26.0); // Suomen keskipiste

                    final LatLng? initialPoint =
                        (_latitude != null && _longitude != null)
                            ? LatLng(_latitude!, _longitude!)
                            : null;

                    final result =
                        await Navigator.of(context).push<Map<String, dynamic>>(
                      MaterialPageRoute(
                        builder: (context) => MapPickerPage(
                          // Käytetään oletusta, jos initialPoint on null.
                          initialLocation: initialPoint ?? defaultLocation,
                        ),
                      ),
                    );

                    if (result != null && result.containsKey('location')) {
                      final selectedPoint = result['location'] as LatLng;
                      final locationName = result['name'] as String?;
                      setState(() {
                        _latitude = selectedPoint.latitude;
                        _longitude = selectedPoint.longitude;
                        _locationController.text = locationName ??
                            '${selectedPoint.latitude.toStringAsFixed(4)}, ${selectedPoint.longitude.toStringAsFixed(4)}';
                      });
                    }
                  },
                ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Location is required';
            }
            if (_latitude == null || _longitude == null) {
              return 'Please select a valid location';
            }
            return null;
          },
        ),
        if (_suggestions.isNotEmpty && _locationFocusNode.hasFocus)
          Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.25),
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.98),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  leading: Icon(
                    suggestion.isPopular
                        ? Icons.star_rounded
                        : Icons.pin_drop_outlined,
                    color: suggestion.isPopular
                        ? Colors.amber.shade600
                        : theme.colorScheme.secondary,
                    size: 24,
                  ),
                  title: Text(suggestion.title,
                      style: TextStyle(
                          fontWeight: suggestion.isPopular
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  subtitle: Text(suggestion.subtitle),
                  dense: !suggestion.isPopular,
                  onTap: () => _selectLocationSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDateRangeField(BuildContext context) {
    final theme = Theme.of(context);
    String dateText = "Select start and end dates*";
    if (_startDate != null) {
      final start = DateFormat.yMMMd().format(_startDate!);
      final end =
          _endDate != null ? DateFormat.yMMMd().format(_endDate!) : null;
      dateText = (end != null && start != end) ? '$start - $end' : start;
    }
    return InkWell(
      onTap: _showDateRangePicker,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: "Hike Dates",
          prefixIcon: Icon(Icons.calendar_today_outlined,
              color: theme.colorScheme.primary.withOpacity(0.8), size: 20),
        ),
        child: Text(dateText,
            style: GoogleFonts.lato(
                fontSize: 16,
                color: _startDate != null
                    ? theme.colorScheme.onSurface
                    : theme.hintColor)),
      ),
    );
  }

  Widget _buildStyledTextFormField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      style: GoogleFonts.lato(fontSize: 16),
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon,
            color: theme.colorScheme.primary.withOpacity(0.8), size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(
                  widget.existingPlan == null
                      ? Icons.add_circle_outline
                      : Icons.save_alt_outlined,
                  size: 20),
              label: Text(
                widget.existingPlan == null ? 'Create Plan' : 'Save Changes',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
