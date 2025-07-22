import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/post_model.dart';
import '../providers/auth_provider.dart';

class CreatePostPage extends StatefulWidget {
  final PostVisibility initialVisibility;

  const CreatePostPage({super.key, required this.initialVisibility});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  // --- STATE VARIABLES ---
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _nightsController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();

  XFile? _imageFile;
  DateTime? _startDate;
  DateTime? _endDate;
  late PostVisibility _selectedVisibility;
  final List<String> _selectedSharedData = [];
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;

  // --- LOCATION SEARCH STATE ---
  List<Map<String, dynamic>> _locationSuggestions = [];
  Timer? _debounce;
  final ValueNotifier<bool> _isSearchingLocation = ValueNotifier(false);
  final FocusNode _locationFocusNode = FocusNode();
  String _currentSearchQuery = '';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _selectedVisibility = widget.initialVisibility;
    _locationController.addListener(_onLocationChanged);
    _locationFocusNode.addListener(_onFocusChanged);
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _locationController.removeListener(_onLocationChanged);
    _locationController.dispose();
    _distanceController.dispose();
    _nightsController.dispose();
    _weightController.dispose();
    _caloriesController.dispose();
    _debounce?.cancel();
    _isSearchingLocation.dispose();
    _locationFocusNode.removeListener(_onFocusChanged);
    _locationFocusNode.dispose();
    super.dispose();
  }

  // --- LOCATION SEARCH LOGIC ---

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print("Could not get location: $e");
    }
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (!_locationFocusNode.hasFocus && _locationSuggestions.isNotEmpty) {
      setState(() => _locationSuggestions = []);
    }
  }

  void _onLocationChanged() {
    final query = _locationController.text.trim();
    if (query == _currentSearchQuery) return;

    if (_latitude != null) {
      setState(() {
        _latitude = null;
        _longitude = null;
      });
    }
    _currentSearchQuery = query;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query == _locationController.text.trim() && query.length > 2) {
        _searchLocationSuggestions(query);
      } else if (query.isEmpty) {
        if (mounted) setState(() => _locationSuggestions = []);
      }
    });
  }

  Future<void> _searchLocationSuggestions(String query) async {
    if (!mounted) return;
    _isSearchingLocation.value = true;

    try {
      final natureQuery = '$query hiking national park luontokohde';
      final priorityUrl = _buildSearchUrl(natureQuery, limit: 7);
      final priorityResponse = await http
          .get(priorityUrl, headers: {'User-Agent': 'TrekNoteApp/1.0'});

      final generalUrl = _buildSearchUrl(query, limit: 3);
      final generalResponse = await http
          .get(generalUrl, headers: {'User-Agent': 'TrekNoteApp/1.0'});

      if (!mounted) return;

      List<Map<String, dynamic>> priorityResults = (priorityResponse
                  .statusCode ==
              200)
          ? List<Map<String, dynamic>>.from(json.decode(priorityResponse.body))
          : [];

      List<Map<String, dynamic>> generalResults = (generalResponse.statusCode ==
              200)
          ? List<Map<String, dynamic>>.from(json.decode(generalResponse.body))
          : [];

      final combinedResults = <int, Map<String, dynamic>>{};
      for (var result in [...priorityResults, ...generalResults]) {
        if (priorityResults.any((p) => p['osm_id'] == result['osm_id'])) {
          result['score_bonus'] = true;
        }
        combinedResults[result['osm_id']] = result;
      }

      final sortedResults = combinedResults.values.toList();
      sortedResults.sort((a, b) =>
          _getRelevanceScore(b, query).compareTo(_getRelevanceScore(a, query)));

      setState(() => _locationSuggestions = sortedResults);
    } catch (e) {
      print("Location search error: $e");
    } finally {
      if (mounted) _isSearchingLocation.value = false;
    }
  }

  Uri _buildSearchUrl(String query, {int limit = 5}) {
    String url =
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=$limit&addressdetails=1&extratags=1&namedetails=1&accept-language=fi,en';
    if (_currentPosition != null) {
      url +=
          '&viewbox=${_currentPosition!.longitude - 1},${_currentPosition!.latitude - 1},${_currentPosition!.longitude + 1},${_currentPosition!.latitude + 1}&bounded=1';
    }
    return Uri.parse(url);
  }

  int _getRelevanceScore(Map<String, dynamic> suggestion, String query) {
    int score = 0;
    String? category = suggestion['category'];
    String? type = suggestion['type'];
    String displayName = (suggestion['display_name'] ?? '').toLowerCase();

    if (suggestion['score_bonus'] == true) {
      score += 200;
    }

    if (category == 'tourism' ||
        category == 'natural' ||
        category == 'leisure' ||
        category == 'historic') {
      score += 100;
    } else if (category == 'boundary' && type == 'administrative') {
      score += 10;
    } else if (category == 'highway') {
      score -= 50;
    }

    if (displayName.contains(query.toLowerCase())) {
      score += 20;
    }

    return score;
  }

  void _selectLocationSuggestion(Map<String, dynamic> suggestion) {
    if (!mounted) return;
    setState(() {
      _locationController.text = _formatSuggestionName(suggestion);
      _latitude = double.tryParse(suggestion['lat'].toString());
      _longitude = double.tryParse(suggestion['lon'].toString());
      _locationSuggestions = [];
      _currentSearchQuery = _locationController.text.trim();
    });
    _locationFocusNode.unfocus();
  }

  String _formatSuggestionName(Map<String, dynamic> suggestion) {
    final address = suggestion['address'] as Map<String, dynamic>? ?? {};
    final namedetails =
        suggestion['namedetails'] as Map<String, dynamic>? ?? {};

    String? primaryName = namedetails['name'] ??
        address['tourism'] ??
        address['natural'] ??
        address['historic'] ??
        address['leisure'] ??
        address['amenity'] ??
        address['shop'];

    primaryName ??= address['road'] ?? address['neighbourhood'];

    String? contextName = address['city'] ??
        address['town'] ??
        address['village'] ??
        address['municipality'];

    if (primaryName != null &&
        contextName != null &&
        primaryName.toLowerCase() != contextName.toLowerCase()) {
      return '$primaryName, $contextName';
    } else if (primaryName != null) {
      return (address['country'] != null &&
              primaryName.toLowerCase() == contextName?.toLowerCase())
          ? '$primaryName, ${address['country']}'
          : primaryName;
    } else if (contextName != null) {
      return contextName;
    }

    return suggestion['display_name']?.toString().split(',').first ??
        'Unknown Location';
  }

  IconData _getIconForSuggestionType(Map<String, dynamic> suggestion) {
    String? category = suggestion['category'];
    String? type = suggestion['type'];

    switch (category) {
      case 'natural':
        return Icons.eco_outlined;
      case 'tourism':
        return Icons.attractions_outlined;
      case 'boundary':
        return Icons.public_outlined;
      case 'highway':
        return Icons.signpost_outlined;
      case 'amenity':
        return Icons.local_cafe_outlined;
      case 'leisure':
        return Icons.hiking_outlined;
      case 'historic':
        return Icons.museum_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  // --- POST CREATION & SAVING LOGIC ---

  Future<void> _createPost() async {
    final theme = Theme.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select the start and end dates for the hike.',
            style: GoogleFonts.lato()),
        backgroundColor: theme.colorScheme.error,
      ));
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a valid location from the suggestions.',
            style: GoogleFonts.lato()),
        backgroundColor: theme.colorScheme.error,
      ));
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userProfile == null) {
      _showErrorDialog('User profile not found.');
      return;
    }

    try {
      String? uploadedImageUrl;
      if (_imageFile != null) {
        uploadedImageUrl = await _uploadImageInternal(_imageFile!);
      }

      final newPostRef = FirebaseFirestore.instance.collection('posts').doc();
      final newPost = Post(
        id: newPostRef.id,
        userId: authProvider.userProfile!.uid,
        username: authProvider.userProfile!.username.isNotEmpty
            ? authProvider.userProfile!.username
            : authProvider.userProfile!.displayName,
        userAvatarUrl: authProvider.userProfile!.photoURL ?? '',
        postImageUrl: uploadedImageUrl,
        title: _titleController.text.trim(),
        caption: _captionController.text.trim(),
        timestamp: DateTime.now(),
        location: _locationController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        startDate: _startDate!,
        endDate: _endDate!,
        distanceKm: double.tryParse(
                _distanceController.text.trim().replaceAll(',', '.')) ??
            0.0,
        nights: int.tryParse(_nightsController.text.trim()) ?? 0,
        weightKg:
            double.tryParse(_weightController.text.trim().replaceAll(',', '.')),
        caloriesPerDay: double.tryParse(_caloriesController.text.trim()),
        planId: null,
        visibility: _selectedVisibility,
        likes: [],
        commentCount: 0,
        sharedData: _selectedSharedData,
      );

      await newPostRef.set(newPost.toFirestore());
      await authProvider.handlePostCreationSuccess();
      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI & WIDGETS ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Hike Post',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0.5,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 120.0),
          child: Form(
            key: _formKey,
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: Opacity(
                opacity: _isLoading ? 0.7 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _imageFile == null
                                  ? theme.dividerColor.withOpacity(0.7)
                                  : Colors.transparent,
                              width: 1.5),
                          image: _imageFile != null
                              ? DecorationImage(
                                  image: FileImage(File(_imageFile!.path)),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: _imageFile == null
                            ? Center(
                                child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      size: 50,
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.8)),
                                  const SizedBox(height: 12),
                                  Text('Add a cover photo (optional)',
                                      style: GoogleFonts.lato(
                                          fontSize: 16,
                                          color: theme
                                              .colorScheme.onSurfaceVariant)),
                                ],
                              ))
                            : null,
                      ),
                    ),
                    _buildSectionTitle(
                        'Basic Information', Icons.notes_rounded),
                    TextFormField(
                      controller: _titleController,
                      style: GoogleFonts.lato(fontSize: 16),
                      decoration: _customInputDecoration(
                          labelText: 'Hike Title',
                          hintText: 'e.g. Koli National Park Adventure',
                          prefixIcon: Icons.flag_outlined,
                          theme: theme),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Title is required.'
                              : value.trim().length < 5
                                  ? 'Title too short (min 5 chars).'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _captionController,
                      style: GoogleFonts.lato(fontSize: 16),
                      decoration: _customInputDecoration(
                              labelText: 'Description / Story',
                              hintText:
                                  'Share your experience, tips, feelings...',
                              prefixIcon: Icons.article_outlined,
                              theme: theme)
                          .copyWith(alignLabelWithHint: true),
                      maxLines: 5,
                      minLines: 3,
                      maxLength: 1000,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Description is required.'
                              : value.trim().length < 20
                                  ? 'Description too short (min 20 chars).'
                                  : null,
                    ),
                    _buildSectionTitle('Hike Details', Icons.hiking_rounded),
                    Column(
                      children: [
                        TextFormField(
                          controller: _locationController,
                          focusNode: _locationFocusNode,
                          style: GoogleFonts.lato(fontSize: 16),
                          decoration: _customInputDecoration(
                            labelText: 'Location / Area',
                            hintText: 'e.g. Karhunkierros, Kuusamo',
                            prefixIcon: Icons.location_on_outlined,
                            theme: theme,
                            suffixIcon: ValueListenableBuilder<bool>(
                              valueListenable: _isSearchingLocation,
                              builder: (context, isSearching, child) =>
                                  isSearching
                                      ? const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2.0)))
                                      : const SizedBox.shrink(),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty)
                              return 'Location is required';
                            if (_latitude == null)
                              return 'Please select a location from suggestions';
                            return null;
                          },
                        ),
                        if (_locationSuggestions.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(12)),
                                border: Border.all(color: theme.dividerColor)),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: _locationSuggestions.length,
                              itemBuilder: (context, index) {
                                final suggestion = _locationSuggestions[index];
                                return ListTile(
                                  leading: Icon(
                                      _getIconForSuggestionType(suggestion),
                                      color: theme.colorScheme.secondary),
                                  title:
                                      Text(_formatSuggestionName(suggestion)),
                                  dense: true,
                                  onTap: () =>
                                      _selectLocationSuggestion(suggestion),
                                );
                              },
                            ),
                          )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, isStart: true),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: _customInputDecoration(
                                labelText: 'Start Date',
                                prefixIcon: Icons.calendar_month_outlined,
                                theme: theme,
                              ).copyWith(
                                hintText: '',
                                contentPadding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              ),
                              child: Text(
                                _startDate == null
                                    ? 'Select'
                                    : DateFormat('dd.MM.yyyy')
                                        .format(_startDate!),
                                style: GoogleFonts.lato(
                                  fontSize: 16,
                                  color: _startDate == null
                                      ? theme.hintColor
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, isStart: false),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: _customInputDecoration(
                                labelText: 'End Date',
                                prefixIcon: Icons.event_available_outlined,
                                theme: theme,
                              ).copyWith(
                                hintText: '',
                                contentPadding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              ),
                              child: Text(
                                _endDate == null
                                    ? 'Select'
                                    : DateFormat('dd.MM.yyyy')
                                        .format(_endDate!),
                                style: GoogleFonts.lato(
                                  fontSize: 16,
                                  color: _endDate == null
                                      ? theme.hintColor
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _distanceController,
                            style: GoogleFonts.lato(fontSize: 16),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: _customInputDecoration(
                                labelText: 'Distance (km)',
                                prefixIcon: Icons.timeline_rounded,
                                theme: theme),
                            validator: (v) => (v != null &&
                                    v.isNotEmpty &&
                                    double.tryParse(v.replaceAll(',', '.')) ==
                                        null)
                                ? 'Invalid number'
                                : null,
                            onChanged: (v) => _distanceController.text =
                                v.replaceAll(',', '.'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _nightsController,
                            style: GoogleFonts.lato(fontSize: 16),
                            keyboardType: TextInputType.number,
                            decoration: _customInputDecoration(
                                labelText: 'Nights',
                                prefixIcon: Icons.night_shelter_outlined,
                                theme: theme),
                            validator: (v) => (v != null &&
                                    v.isNotEmpty &&
                                    int.tryParse(v) == null)
                                ? 'Invalid number'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    _buildSectionTitle('Additional Details (Optional)',
                        Icons.more_horiz_rounded),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            style: GoogleFonts.lato(fontSize: 16),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: _customInputDecoration(
                                labelText: 'Pack Weight (kg)',
                                prefixIcon: Icons.backpack_outlined,
                                theme: theme),
                            validator: (v) => (v != null &&
                                    v.isNotEmpty &&
                                    double.tryParse(v.replaceAll(',', '.')) ==
                                        null)
                                ? 'Invalid number'
                                : null,
                            onChanged: (v) =>
                                _weightController.text = v.replaceAll(',', '.'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _caloriesController,
                            style: GoogleFonts.lato(fontSize: 16),
                            keyboardType: TextInputType.number,
                            decoration: _customInputDecoration(
                                labelText: 'Avg. Calories/day',
                                prefixIcon:
                                    Icons.local_fire_department_outlined,
                                theme: theme),
                            validator: (v) => (v != null &&
                                    v.isNotEmpty &&
                                    int.tryParse(v) == null)
                                ? 'Invalid number'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    _buildSectionTitle('Post Settings',
                        Icons.settings_input_component_outlined),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Text(
                            "Visibility:",
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          _buildVisibilityIndicator(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'What details do you want to share in this post?',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _buildShareOption('Route (shows location pin on map)',
                        'route', Icons.map_outlined),
                    _buildShareOption('Packing list details (pack weight)',
                        'packing', Icons.inventory_2_outlined),
                    _buildShareOption('Meal plan details (calories/day)',
                        'food', Icons.restaurant_menu_outlined),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.6),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.secondary)),
                  const SizedBox(height: 20),
                  Text("Publishing your adventure...",
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500))
                ],
              ),
            ),
          ),
      ]),
      bottomNavigationBar: Material(
        elevation: 8.0,
        color: theme.scaffoldBackgroundColor,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 12.0,
            bottom: MediaQuery.of(context).padding.bottom + 12.0,
          ),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _createPost,
            icon: const Icon(Icons.publish_rounded, size: 22),
            label: Text('Publish Hike Post',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 17)),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor:
                  theme.colorScheme.primary.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER METHODS ---

  void _showErrorDialog(String message) {
    if (mounted) {
      _showOutcomeDialog(
        isSuccess: false,
        title: 'Error',
        message: message.replaceFirst("Exception: ", ""),
        onDismissed: () {},
      );
    }
  }

  void _showSuccessDialog() {
    if (mounted) {
      _showOutcomeDialog(
        isSuccess: true,
        title: 'Success!',
        message: 'New hike post created.',
        onDismissed: () {
          if (mounted) Navigator.of(context).pop();
        },
      );
    }
  }

  Future<void> _pickImage() async {
    if (_isLoading) return;
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
          maxWidth: 1920,
          maxHeight: 1080);
      if (image != null) {
        setState(() => _imageFile = image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to pick image: ${e.toString()}',
                  style: GoogleFonts.lato())),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isStart}) async {
    if (_isLoading) return;
    final theme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime(DateTime.now().year - 10),
      lastDate: DateTime(DateTime.now().year + 10),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.cardColor,
              onSurface: theme.colorScheme.onSurface,
            ),
            dialogTheme: DialogThemeData(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<String?> _uploadImageInternal(XFile imageFile) async {
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(imageFile.path)}';
      final Reference storageRef =
          FirebaseStorage.instance.ref().child('post_images/$fileName');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await storageRef.putFile(File(imageFile.path), metadata);
      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image. Please try again.');
    }
  }

  InputDecoration _customInputDecoration({
    required String labelText,
    String? hintText,
    required IconData prefixIcon,
    required ThemeData theme,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: GoogleFonts.lato(
          color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
      hintStyle: GoogleFonts.lato(color: theme.hintColor, fontSize: 15),
      prefixIcon: Icon(prefixIcon, color: theme.colorScheme.primary, size: 22),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.7))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.7))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.8)),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLowest.withOpacity(0.8),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
    );
  }

  Widget _buildAnimatedIcon(bool isSuccess) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: isSuccess
          ? Icon(Icons.check_circle_outline_rounded,
              key: const ValueKey('success_icon'),
              color: Colors.green.shade500,
              size: 64)
          : Icon(Icons.error_outline_rounded,
              key: const ValueKey('error_icon'),
              color: Colors.red.shade500,
              size: 64),
    );
  }

  Future<void> _showOutcomeDialog({
    required bool isSuccess,
    required String title,
    required String message,
    required VoidCallback onDismissed,
  }) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: theme.cardColor,
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildAnimatedIcon(isSuccess),
            const SizedBox(height: 20),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                    fontSize: 15, color: theme.colorScheme.onSurfaceVariant)),
          ]),
        );
      },
    );
    await Future.delayed(const Duration(seconds: 2, milliseconds: 500));
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    onDismissed();
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28.0, bottom: 12.0),
      child: Row(children: [
        Icon(icon, color: theme.colorScheme.secondary, size: 22),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface)),
      ]),
    );
  }

  Widget _buildVisibilityIndicator() {
    final theme = Theme.of(context);
    IconData icon;
    String text;
    Color color;
    switch (_selectedVisibility) {
      case PostVisibility.public:
        icon = Icons.public_rounded;
        text = 'Public';
        color = theme.colorScheme.primary;
        break;
      case PostVisibility.friends:
        icon = Icons.group_outlined;
        text = 'Friends';
        color = theme.colorScheme.secondary;
        break;
      case PostVisibility.private:
        icon = Icons.lock_outline_rounded;
        text = 'Private';
        color = Colors.grey.shade600;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 8),
        Text(text,
            style: GoogleFonts.lato(
                color: color, fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    );
  }

  Widget _buildShareOption(String title, String key, IconData icon) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      title: Text(title, style: GoogleFonts.lato(fontSize: 15.5)),
      value: _selectedSharedData.contains(key),
      onChanged: _isLoading
          ? null
          : (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedSharedData.add(key);
                } else {
                  _selectedSharedData.remove(key);
                }
              });
            },
      secondary:
          Icon(icon, color: theme.colorScheme.secondary.withOpacity(0.9)),
      activeColor: theme.colorScheme.primary,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 0),
      dense: true,
      checkboxShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }
}
