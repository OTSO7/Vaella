import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

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

  DateTime? _startDate;
  DateTime? _endDate;
  double? _latitude;
  double? _longitude;

  List<Map<String, dynamic>> _locationSuggestions = [];
  Timer? _debounce;
  final ValueNotifier<bool> _isSearchingLocation = ValueNotifier(false);
  final FocusNode _locationFocusNode = FocusNode();
  String _currentSearchQuery = '';

  final List<Map<String, dynamic>> _popularDestinations = const [
    {
      'name': 'Karhunkierros Trail',
      'area': 'Kuusamo',
      'isPopular': true,
      'keywords': ['karhunkierros', 'karhu', 'bears ring'],
      'lat': 66.37162668137469,
      'lon': 29.30838567629724,
    },
    {
      'name': 'Urho Kekkonen National Park',
      'area': 'Saariselkä',
      'isPopular': true,
      'keywords': ['urho', 'urho kekkonen', 'ukk', 'uk-puisto', 'saariselkä'],
      'lat': 68.1666654499649,
      'lon': 28.25000050929616,
    },
    {
      'name': 'Pallas-Yllästunturi National Park',
      'area': 'Enontekiö, Kittilä',
      'isPopular': true,
      'keywords': ['pallas', 'ylläs', 'pallas-ylläs', 'hetta'],
      'lat': 67.96666545447972,
      'lon': 24.133333365079718,
    },
    {
      'name': 'Nuuksio National Park',
      'area': 'Espoo',
      'isPopular': true,
      'keywords': ['nuuksio', 'nuuk'],
      'lat': 60.29272641885399,
      'lon': 24.55651004451601,
    },
    {
      'name': 'Koli National Park',
      'area': 'Lieksa',
      'isPopular': true,
      'keywords': ['kol', 'koli', 'kolin'],
      'lat': 63.096856314964896,
      'lon': 29.806231767971884,
    },
    {
      'name': 'Repovesi National Park',
      'area': 'Kouvola',
      'isPopular': true,
      'keywords': ['repovesi', 'repo'],
      'lat': 61.1879941764923,
      'lon': 26.902363366617525,
    },
    {
      'name': 'Kilpisjärvi & Saana Fell',
      'area': 'Enontekiö',
      'isPopular': true,
      'keywords': ['kilpis', 'kilpisjärvi', 'saana', 'halti'],
      'lat': 69.04428710574022,
      'lon': 20.803299621352853,
    },
  ];

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
    _locationController.addListener(_onLocationChanged);
    _locationFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.removeListener(_onLocationChanged);
    _locationController.dispose();
    _lengthController.dispose();
    _isSearchingLocation.dispose();
    _debounce?.cancel();
    _locationFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_locationFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _locationSuggestions = []);
      });
    }
  }

  void _onLocationChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _locationController.text.trim();
      if (query.length > 2 && query != _currentSearchQuery) {
        _isSearchingLocation.value = true;
        _currentSearchQuery = query;
        _searchLocations(query);
      } else if (query.isEmpty) {
        if (mounted) setState(() => _locationSuggestions = []);
      }
    });
  }

  Future<void> _searchLocations(String query) async {
    final normalizedQuery = query.toLowerCase();

    final popularResults = _popularDestinations.where((dest) {
      final nameMatch =
          dest['name'].toString().toLowerCase().contains(normalizedQuery);
      final keywordMatch = (dest['keywords'] as List<String>)
          .any((k) => k.contains(normalizedQuery));
      return nameMatch || keywordMatch;
    }).toList();

    final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=fi&accept-language=en');
    List<Map<String, dynamic>> apiResults = [];
    try {
      final response =
          await http.get(uri, headers: {'User-Agent': 'TrekNote/1.0'});
      if (mounted && response.statusCode == 200) {
        apiResults =
            List<Map<String, dynamic>>.from(json.decode(response.body));
      }
    } catch (e) {
      debugPrint("Location search failed: $e");
    }

    final combinedResults = <String, Map<String, dynamic>>{};

    // **KORJAUS TÄSSÄ:** Luodaan muokattava kopio, jotta 'score_bonus' voidaan lisätä.
    for (var result in [...popularResults, ...apiResults]) {
      final mutableResult = Map<String, dynamic>.from(result);
      final formattedName = _formatLocationSuggestion(mutableResult);

      if (popularResults.any((p) => p['name'] == mutableResult['name'])) {
        mutableResult['score_bonus'] = true;
      }

      final score = _getRelevanceScore(mutableResult, query);
      mutableResult['relevance_score'] = score;

      if (!combinedResults.containsKey(formattedName)) {
        combinedResults[formattedName] = mutableResult;
      }
    }

    final sortedResults = combinedResults.values.toList();
    sortedResults.sort((a, b) =>
        (b['relevance_score'] as int).compareTo(a['relevance_score'] as int));

    if (mounted) {
      setState(() {
        _locationSuggestions = sortedResults;
        _isSearchingLocation.value = false;
      });
    }
  }

  int _getRelevanceScore(Map<String, dynamic> suggestion, String query) {
    int score = 0;
    String? category = suggestion['category'];
    String? type = suggestion['type'];
    final address = suggestion['address'] as Map<String, dynamic>? ?? {};
    final featureName = (address['tourism'] ??
                address['natural'] ??
                address['leisure'] ??
                address['historic'] ??
                suggestion['name'])
            ?.toString()
            .toLowerCase() ??
        '';

    if (suggestion['score_bonus'] == true) score += 1000;

    if (category == 'tourism' || category == 'natural' || category == 'leisure')
      score += 100;
    if (category == 'boundary') score += 10;
    if (category == 'highway') score -= 50;

    if (featureName.contains(query.toLowerCase())) {
      score += 50;
    }

    return score;
  }

  String _formatLocationSuggestion(Map<String, dynamic> suggestion) {
    if (suggestion['isPopular'] ?? false) {
      return '${suggestion['name']}, ${suggestion['area']}';
    }

    final address = suggestion['address'] as Map<String, dynamic>?;
    if (address == null) {
      return suggestion['display_name'] ?? 'Unknown location';
    }

    final feature = address['tourism'] ??
        address['natural'] ??
        address['historic'] ??
        address['leisure'] ??
        address['shop'] ??
        address['amenity'] ??
        address['road'] ??
        address['neighbourhood'];
    final locality = address['city'] ??
        address['town'] ??
        address['village'] ??
        address['municipality'] ??
        address['county'];

    if (feature != null && locality != null) {
      if (feature.toString().toLowerCase() !=
          locality.toString().toLowerCase()) {
        return '$feature, $locality';
      }
      return feature;
    }
    if (feature != null) return feature;
    if (locality != null) return locality;

    return suggestion['display_name']?.split(',').take(2).join(', ') ??
        'Unknown';
  }

  void _selectLocationSuggestion(Map<String, dynamic> suggestion) {
    final displayName = _formatLocationSuggestion(suggestion);
    final lat = double.tryParse(suggestion['lat'].toString()) ?? 0.0;
    final lon = double.tryParse(suggestion['lon'].toString()) ?? 0.0;

    setState(() {
      _locationController.text = displayName;
      _latitude = lat;
      _longitude = lon;
      _locationSuggestions = [];
      _currentSearchQuery = displayName;
    });
    FocusScope.of(context).unfocus();
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
          suffixIcon: ValueListenableBuilder<bool>(
            valueListenable: _isSearchingLocation,
            builder: (context, isSearching, child) {
              return isSearching
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
                      onPressed: () {
                        /* Map picker not implemented in this snippet */
                      },
                    );
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
        if (_locationSuggestions.isNotEmpty && _locationFocusNode.hasFocus)
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
              itemCount: _locationSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _locationSuggestions[index];
                final isPopular = suggestion['isPopular'] ?? false;
                final formattedName = _formatLocationSuggestion(suggestion);

                return ListTile(
                  leading: Icon(
                    isPopular ? Icons.star_rounded : Icons.pin_drop_outlined,
                    color: isPopular
                        ? Colors.amber.shade600
                        : theme.colorScheme.secondary,
                    size: 24,
                  ),
                  title: Text(formattedName,
                      style: TextStyle(
                          fontWeight:
                              isPopular ? FontWeight.bold : FontWeight.normal)),
                  subtitle: isPopular
                      ? null
                      : Text(suggestion['display_name'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                  dense: !isPopular,
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
