// lib/pages/create_post_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../models/post_model.dart';
import '../providers/auth_provider.dart';

class CreatePostPage extends StatefulWidget {
  final PostVisibility initialVisibility;
  const CreatePostPage({super.key, required this.initialVisibility});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  // --- STATE-MUUTTUJAT ---
  int _currentStep = 0;
  final PageController _pageController = PageController();
  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>()
  ];

  // --- CONTROLLERIT ---
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final _distanceController = TextEditingController();
  final _nightsController = TextEditingController();
  final _weightController = TextEditingController();

  XFile? _imageFile;
  DateTime? _startDate;
  DateTime? _endDate;
  late PostVisibility _selectedVisibility;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;

  bool _showPackWeightField = false;

  double _weatherRating = 0.0;
  double _difficultyRating = 0.0;
  double _experienceRating = 0.0;

  // --- SIJAINNIN HAUN STATE ---
  List<Map<String, dynamic>> _locationSuggestions = [];
  Timer? _debounce;
  final ValueNotifier<bool> _isSearchingLocation = ValueNotifier(false);
  final FocusNode _locationFocusNode = FocusNode();
  String _currentSearchQuery = '';

  // lista suosituimmista paikoista
  final List<Map<String, dynamic>> _popularDestinations = const [
    {
      'name': 'Karhunkierros',
      'area': 'Kuusamo',
      'isPopular': true,
      'keywords': ['karhunkierros', 'karhu'],
      'lat': 66.37162668137469,
      'lon': 29.30838567629724,
    },
    {
      'name': 'Urho Kekkosen kansallispuisto',
      'area': 'Savukoski, Sodankylä, Inari',
      'isPopular': true,
      'keywords': ['urho', 'urho kekkonen', 'ukk', 'uk-puisto'],
      'lat': 68.1666654499649,
      'lon': 28.25000050929616,
    },
    {
      'name': 'Pallas-Yllästunturin kansallispuisto',
      'area': 'Enontekiö, Kittilä, Kolari',
      'isPopular': true,
      'keywords': ['palla', 'pallas', 'ylläs', 'pallas-ylläs', 'hetta'],
      'lat': 67.96666545447972,
      'lon': 24.133333365079718,
    },
    {
      'name': 'Nuuksion kansallispuisto',
      'area': 'Espoo, Kirkkonummi',
      'isPopular': true,
      'keywords': ['nuuksio', 'nuuk'],
      'lat': 60.29272641885399,
      'lon': 24.55651004451601,
    },
    {
      'name': 'Kolin kansallispuisto',
      'area': 'Lieksa, Joensuu',
      'isPopular': true,
      'keywords': ['kol', 'koli', 'kolin'],
      'lat': 63.096856314964896,
      'lon': 29.806231767971884,
    },
    {
      'name': 'Repoveden kansallispuisto',
      'area': 'Kouvola, Mäntyharju',
      'isPopular': true,
      'keywords': ['repovesi', 'repo'],
      'lat': 61.1879941764923,
      'lon': 26.902363366617525,
    },
    {
      'name': 'Kilpisjärvi',
      'area': 'Enontekiö',
      'isPopular': true,
      'keywords': ['kilpis', 'kilpisjärvi'],
      'lat': 69.04428710574022,
      'lon': 20.803299621352853,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedVisibility = widget.initialVisibility;
    _locationController.addListener(_onLocationChanged);
    _locationFocusNode.addListener(_onFocusChanged);
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
    _pageController.dispose();
    _debounce?.cancel();
    _isSearchingLocation.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_locationFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _locationSuggestions = []);
        }
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
        setState(() => _locationSuggestions = []);
      }
    });
  }

  // MUUTOS: Koko hakulogiikka on uusittu älykkäämmäksi
  Future<void> _searchLocations(String query) async {
    final normalizedQuery = query.toLowerCase();

    // 1. Suodata paikalliset suosikit
    final popularResults = _popularDestinations.where((dest) {
      final nameMatch = dest['name'].toLowerCase().contains(normalizedQuery);
      final keywordMatch = (dest['keywords'] as List<String>)
          .any((k) => k.contains(normalizedQuery));
      return nameMatch || keywordMatch;
    }).toList();

    // 2. Hae tulokset API:sta (keskittyen Suomeen)
    final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=fi');
    List<Map<String, dynamic>> apiResults = [];
    try {
      final response =
          await http.get(uri, headers: {'User-Agent': 'TrekNote/1.0'});
      if (mounted && response.statusCode == 200) {
        apiResults =
            List<Map<String, dynamic>>.from(json.decode(response.body));
      }
    } catch (e) {
      print("Location search failed: $e");
    }

    // 3. Yhdistä ja poista duplikaatit
    final combinedResults = <Map<String, dynamic>>[];
    final addedNames = <String>{};

    // Lisää suosikit ensin
    for (var dest in popularResults) {
      combinedResults.add(dest);
      addedNames.add(dest['name'].toLowerCase());
    }

    // Lisää API-tulokset, jos ne eivät ole jo listalla
    for (var result in apiResults) {
      final displayName =
          (result['display_name'] as String?)?.toLowerCase() ?? '';
      if (!addedNames.any((name) => displayName.contains(name))) {
        combinedResults.add(result);
      }
    }

    if (mounted) {
      setState(() {
        _locationSuggestions = combinedResults;
        _isSearchingLocation.value = false;
      });
    }
  }

  // MUUTOS: Päivitetty käsittelemään kahta erilaista tulostyyppiä (suosikki vs. API)
  void _selectLocationSuggestion(Map<String, dynamic> suggestion) {
    final bool isPopular = suggestion['isPopular'] ?? false;
    String displayName;
    double lat;
    double lon;

    if (isPopular) {
      displayName = '${suggestion['name']}, ${suggestion['area']}';
      lat = suggestion['lat'];
      lon = suggestion['lon'];
    } else {
      displayName = suggestion['display_name'] ?? 'Unknown location';
      lat = double.tryParse(suggestion['lat'].toString()) ?? 0.0;
      lon = double.tryParse(suggestion['lon'].toString()) ?? 0.0;
    }

    setState(() {
      _locationController.text = displayName;
      _latitude = lat;
      _longitude = lon;
      _locationSuggestions = [];
      _currentSearchQuery = displayName;
    });
    FocusScope.of(context).unfocus();
  }

  // --- BUILD-METODIT JA MUU UI-LOGIIKKA (pääosin ennallaan) ---

  // ... (Kaikki muu koodi, kuten _onNextPressed, _createPost, _buildStepOne, _buildStepTwo, _buildStepThree, jne. on ennallaan)
  // ... (Täydellisyyden vuoksi liitän ne alle, mutta muutokset ovat yllä olevissa funktioissa ja sijainnin `_buildLocationField`-widgetissä)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Post (${_currentStep + 1}/3)',
            style: GoogleFonts.poppins()),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: _onBackPressed)
            : null,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStepOne(context),
                _buildStepTwo(context),
                _buildStepThree(context),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  void _onNextPressed() {
    if (_formKeys[_currentStep].currentState!.validate()) {
      if (_currentStep == 1 && (_startDate == null || _endDate == null)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please select hike dates.")));
        }
        return;
      }
      if (_currentStep < 2) {
        setState(() => _currentStep++);
        _pageController.animateToPage(_currentStep,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
      } else {
        _createPost();
      }
    }
  }

  void _onBackPressed() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _createPost() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      String? uploadedImageUrl;
      if (_imageFile != null) {
        uploadedImageUrl = await _uploadImageInternal(_imageFile!);
      }
      final newPostRef = FirebaseFirestore.instance.collection('posts').doc();
      final newPost = Post(
        id: newPostRef.id,
        userId: authProvider.userProfile!.uid,
        username: authProvider.userProfile!.username,
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
        weightKg: _showPackWeightField
            ? double.tryParse(
                _weightController.text.trim().replaceAll(',', '.'))
            : null,
        visibility: _selectedVisibility,
        planId: null,
        ratings: {
          'weather': _weatherRating,
          'difficulty': _difficultyRating,
          'experience': _experienceRating,
        },
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

  Widget _buildProgressIndicator() {
    double beginValue = _currentStep / 3.0;
    double endValue = (_currentStep + 1) / 3.0;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      tween: Tween<double>(begin: beginValue, end: endValue),
      builder: (context, value, child) => LinearProgressIndicator(
        value: value,
        backgroundColor: Theme.of(context).colorScheme.surface,
        minHeight: 6,
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final isLastStep = _currentStep == 2;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onNextPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle:
              GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Colors.white))
              : Text(isLastStep ? 'Publish Post' : 'Next Step',
                  key: ValueKey(_currentStep)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) => Text(title,
      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to pick image: ${e.toString()}',
                style: GoogleFonts.lato())));
      }
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

  void _showErrorDialog(String message) {
    if (mounted) {
      _showOutcomeDialog(
          isSuccess: false,
          title: 'Error',
          message: message.replaceFirst("Exception: ", ""),
          onDismissed: () {});
    }
  }

  void _showSuccessDialog() {
    if (mounted) {
      _showOutcomeDialog(
        isSuccess: true,
        title: 'Success!',
        message: 'New hike post created. You earned 50 XP!',
        onDismissed: () {
          if (mounted) Navigator.of(context).pop();
        },
      );
    }
  }

  Widget _buildAnimatedIcon(bool isSuccess) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) =>
          ScaleTransition(scale: animation, child: child),
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

  Future<void> _showOutcomeDialog(
      {required bool isSuccess,
      required String title,
      required String message,
      required VoidCallback onDismissed}) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        Future.delayed(const Duration(seconds: 2, milliseconds: 500), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
          onDismissed();
        });
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
                    fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(fontSize: 15)),
          ]),
        );
      },
    );
  }

  Widget _buildStyledTextFormField({
    Key? key,
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      style: GoogleFonts.lato(fontSize: 16),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon,
            color: theme.colorScheme.primary.withOpacity(0.8), size: 20),
      ),
    );
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
                initialSelectedRange: _startDate != null && _endDate != null
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

  Widget _buildDateRangeField(BuildContext context) {
    final theme = Theme.of(context);
    String dateText = "Select start and end dates*";
    if (_startDate != null && _endDate != null) {
      if (_startDate == _endDate) {
        dateText = DateFormat.yMMMd().format(_startDate!);
      } else {
        dateText =
            '${DateFormat.yMMMd().format(_startDate!)} - ${DateFormat.yMMMd().format(_endDate!)}';
      }
    } else if (_startDate != null) {
      dateText = DateFormat.yMMMd().format(_startDate!);
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

  Widget _buildImagePicker(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _pickImage,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  _imageFile == null ? theme.dividerColor : Colors.transparent,
              width: 1.5,
            ),
            image: _imageFile != null
                ? DecorationImage(
                    image: FileImage(File(_imageFile!.path)), fit: BoxFit.cover)
                : null,
          ),
          child: _imageFile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          size: 40, color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text('Add a cover photo',
                          style: GoogleFonts.lato(fontSize: 16)),
                    ],
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildStepOne(BuildContext context) {
    return Form(
      key: _formKeys[0],
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildSectionHeader(context, "1. Your Story & Photo"),
          const SizedBox(height: 16),
          _buildImagePicker(context),
          const SizedBox(height: 24),
          _buildStyledTextFormField(
            controller: _titleController,
            labelText: "Hike Title*",
            hintText: "e.g., Autumn Adventure in Koli",
            icon: Icons.flag_outlined,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Title is required.'
                : null,
          ),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
            controller: _captionController,
            labelText: "Your Story",
            hintText: "Share your experience...",
            icon: Icons.article_outlined,
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildStepTwo(BuildContext context) {
    return Form(
      key: _formKeys[1],
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildSectionHeader(context, "2. Hike Details"),
          const SizedBox(height: 24),
          _buildLocationField(context),
          const SizedBox(height: 24),
          _buildDateRangeField(context),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _buildStyledTextFormField(
                controller: _distanceController,
                labelText: "Distance (km)*",
                hintText: "42.5",
                icon: Icons.hiking_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Required";
                  if (double.tryParse(v.replaceAll(',', '.')) == null) {
                    return 'Invalid';
                  }
                  return null;
                },
              )),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStyledTextFormField(
                controller: _nightsController,
                labelText: "Nights*",
                hintText: "3",
                icon: Icons.night_shelter_outlined,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Required";
                  if (int.tryParse(v) == null) return 'Invalid';
                  return null;
                },
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepThree(BuildContext context) {
    return Form(
      key: _formKeys[2],
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildSectionHeader(context, "3. Final Touches"),
          const SizedBox(height: 24),
          _buildOptionalFields(context),
          const SizedBox(height: 24),
          _buildRatingsSection(context),
        ],
      ),
    );
  }

  Widget _buildOptionalFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Optional Details",
            style: GoogleFonts.lato(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        FilterChip(
          label: const Text("Pack Weight"),
          selected: _showPackWeightField,
          onSelected: (selected) =>
              setState(() => _showPackWeightField = selected),
          avatar: const Icon(Icons.backpack_outlined, size: 18),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showPackWeightField
              ? _buildStyledTextFormField(
                  key: const ValueKey('weight_field'),
                  controller: _weightController,
                  labelText: "Pack Weight (kg)",
                  hintText: "e.g., 15.5",
                  icon: Icons.backpack_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                )
              : const SizedBox.shrink(key: ValueKey('weight_empty')),
        ),
      ],
    );
  }

  Widget _buildRatingsSection(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Rate Your Hike",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildRatingBar(
              title: "Weather Conditions",
              currentRating: _weatherRating,
              onRatingChanged: (rating) {
                setState(() => _weatherRating = rating);
              },
            ),
            const SizedBox(height: 16),
            _buildRatingBar(
              title: "Trail Difficulty",
              currentRating: _difficultyRating,
              onRatingChanged: (rating) {
                setState(() => _difficultyRating = rating);
              },
            ),
            const SizedBox(height: 16),
            _buildRatingBar(
              title: "Overall Experience",
              currentRating: _experienceRating,
              onRatingChanged: (rating) {
                setState(() => _experienceRating = rating);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar({
    required String title,
    required double currentRating,
    required ValueChanged<double> onRatingChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (index) {
            final starNumber = index + 1.0;
            return IconButton(
              onPressed: () => onRatingChanged(starNumber),
              icon: Icon(
                starNumber <= currentRating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: Colors.amber.shade600,
                size: 32,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            );
          }),
        ),
      ],
    );
  }

  // MUUTOS: Tämä on tärkein UI-muutos sijainnin haulle
  Widget _buildLocationField(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildStyledTextFormField(
          controller: _locationController,
          focusNode: _locationFocusNode,
          labelText: "Location*",
          hintText: "Search for a trail or area...",
          icon: Icons.location_on_outlined,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Location is required';
            }
            if (_latitude == null || _longitude == null) {
              return 'Please select a valid location from suggestions';
            }
            return null;
          },
        ),
        if (_locationSuggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              shrinkWrap: true,
              itemCount: _locationSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _locationSuggestions[index];
                final bool isPopular = suggestion['isPopular'] ?? false;

                if (isPopular) {
                  // Tyylitelty ListTile suosituille kohteille
                  return ListTile(
                    leading: Icon(Icons.star_rounded,
                        color: Colors.amber.shade600, size: 24),
                    title: Text(suggestion['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(suggestion['area']),
                    trailing: Chip(
                      label: const Text('POPULAR',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 0),
                      backgroundColor:
                          theme.colorScheme.primaryContainer.withOpacity(0.5),
                      side: BorderSide.none,
                    ),
                    onTap: () => _selectLocationSuggestion(suggestion),
                  );
                } else {
                  // Normaali ListTile API-tuloksille
                  return ListTile(
                    leading: Icon(Icons.pin_drop_outlined,
                        color: theme.colorScheme.secondary),
                    title: Text(
                      suggestion['display_name'] ?? 'N/A',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    dense: true,
                    onTap: () => _selectLocationSuggestion(suggestion),
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}
