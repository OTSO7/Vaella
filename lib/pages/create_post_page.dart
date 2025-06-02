// lib/pages/create_post_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../models/user_profile_model.dart'; // Varmista, että UserProfile-malli on tuotu

class CreatePostPage extends StatefulWidget {
  final PostVisibility initialVisibility;

  const CreatePostPage({super.key, required this.initialVisibility});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
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

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedVisibility = widget.initialVisibility;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _locationController.dispose();
    _distanceController.dispose();
    _nightsController.dispose();
    _weightController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isLoading) return;
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() {
          _imageFile = image;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Kuvan valinta epäonnistui: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isStart}) async {
    // ... (koodi ennallaan)
    if (_isLoading) return;
    final theme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.scaffoldBackgroundColor,
              onSurface: theme.colorScheme.onSurface,
            ),
            dialogBackgroundColor: theme.cardColor,
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
    // ... (koodi ennallaan)
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(imageFile.path)}';
      final Reference storageRef =
          FirebaseStorage.instance.ref().child('post_images/$fileName');
      await storageRef.putFile(File(imageFile.path));
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Error uploading image internally: $e');
      throw Exception('Kuvan lataus epäonnistui: $e');
    }
  }

  Widget _buildAnimatedIcon(bool isSuccess) {
    // ... (koodi ennallaan)
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: isSuccess
          ? Icon(
              Icons.check_circle_outline,
              key: const ValueKey('success_icon'),
              color: Colors.green.shade600,
              size: 70,
            )
          : Icon(
              Icons.error_outline,
              key: const ValueKey('error_icon'),
              color: Colors.red.shade600,
              size: 70,
            ),
    );
  }

  Future<void> _showOutcomeDialog({
    required bool isSuccess,
    required String title,
    required String message,
    required VoidCallback onDismissed,
  }) async {
    // ... (koodi ennallaan)
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
          onDismissed();
        });

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Theme.of(context).cardColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAnimatedIcon(isSuccess),
              const SizedBox(height: 20),
              Text(title,
                  style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.8))),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                const Text('Täytä kaikki pakolliset kentät huolellisesti.'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text(
                'Valitse vaelluksen aloitus- ja päättymispäivämäärät.'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final UserProfile? currentUserProfile = authProvider.userProfile;

    if (currentUserProfile == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showOutcomeDialog(
          isSuccess: false,
          title: 'Virhe',
          message: 'Käyttäjäprofiilia ei löytynyt. Kirjaudu sisään uudelleen.',
          onDismissed: () {},
        );
      }
      return;
    }

    String? uploadedImageUrl;

    try {
      if (_imageFile != null) {
        uploadedImageUrl = await _uploadImageInternal(_imageFile!);
      }

      final newPostRef = FirebaseFirestore.instance.collection('posts').doc();
      final newPost = Post(
        id: newPostRef.id,
        userId: currentUserProfile.uid,
        // --- KORJATTU KOHTA ---
        username: currentUserProfile.username.isNotEmpty
            ? currentUserProfile.username
            : currentUserProfile
                .displayName, // Käytä ensisijaisesti usernamea, fallback displayName
        // --- KORJATTU KOHTA LOPPUU ---
        userAvatarUrl: currentUserProfile.photoURL ??
            'https://firebasestorage.googleapis.com/v0/b/vaellus-app.appspot.com/o/profile_images%2Fdefault_avatar.png?alt=media&token=0default1-0000-0000-0000-0default00000',
        postImageUrl: uploadedImageUrl,
        title: _titleController.text.trim(),
        caption: _captionController.text.trim(),
        timestamp: DateTime.now(),
        location: _locationController.text.trim(),
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

      if (mounted) {
        setState(() => _isLoading = false);
        _showOutcomeDialog(
          isSuccess: true,
          title: 'Onnistui!',
          message: 'Uusi vaelluspostaus luotu.',
          onDismissed: () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      }
    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showOutcomeDialog(
          isSuccess: false,
          title: 'Virhe',
          message:
              'Postauksen luominen epäonnistui:\n${e.toString().replaceFirst("Exception: ", "")}',
          onDismissed: () {},
        );
      }
    }
  }

  // ... (_buildSectionTitle, _buildVisibilityIndicator, build, _buildShareOption ennallaan)
  Widget _buildSectionTitle(String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.secondary, size: 22),
          const SizedBox(width: 8),
          Text(title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildVisibilityIndicator() {
    final theme = Theme.of(context);
    IconData icon;
    String text;
    Color color;
    switch (_selectedVisibility) {
      case PostVisibility.public:
        icon = Icons.public;
        text = 'Julkinen';
        color = theme.colorScheme.primary;
        break;
      case PostVisibility.friends:
        icon = Icons.group_outlined;
        text = 'Ystävät';
        color = theme.colorScheme.secondary;
        break;
      case PostVisibility.private:
        icon = Icons.lock_outline;
        text = 'Yksityinen';
        color = Colors.grey.shade500;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(text,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lisää uusi vaellus'),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 100.0),
            child: Form(
              key: _formKey,
              child: AbsorbPointer(
                absorbing: _isLoading,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _imageFile == null
                                ? theme.colorScheme.outline.withOpacity(0.5)
                                : Colors.transparent,
                            width: 1.5,
                          ),
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
                                        size: 60,
                                        color: theme.colorScheme.secondary
                                            .withOpacity(0.8)),
                                    const SizedBox(height: 12),
                                    Text(
                                        'Lisää kuva vaelluksesta (valinnainen)',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withOpacity(0.7))),
                                  ],
                                ),
                              )
                            : null,
                      ),
                    ),
                    _buildSectionTitle('Perustiedot', Icons.article_outlined),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                          labelText: 'Otsikko',
                          hintText: 'esim. Upea viikonloppu Kolilla',
                          prefixIcon: Icon(Icons.title)),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Otsikko on pakollinen.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _captionController,
                      decoration: const InputDecoration(
                          labelText: 'Miten reissu meni?',
                          hintText: 'Kerro tarinasi, fiilikset ja vinkit...',
                          prefixIcon: Icon(Icons.description_outlined),
                          alignLabelWithHint: true),
                      maxLines: 5,
                      minLines: 3,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Kuvaus on pakollinen.'
                          : null,
                    ),
                    _buildSectionTitle(
                        'Vaelluksen Yksityiskohdat', Icons.hiking_outlined),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                          labelText: 'Sijainti',
                          hintText: 'esim. Patvinsuon kansallispuisto',
                          prefixIcon: Icon(Icons.location_on_outlined)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, isStart: true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Aloituspäivä',
                                  prefixIcon:
                                      Icon(Icons.calendar_today_outlined)),
                              child: Text(
                                  _startDate == null
                                      ? 'Valitse'
                                      : DateFormat('d.M.yyyy')
                                          .format(_startDate!),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      color: _startDate == null
                                          ? theme.hintColor
                                          : theme.colorScheme.onSurface,
                                      fontSize: 16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, isStart: false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Päättymispäivä',
                                  prefixIcon:
                                      Icon(Icons.event_available_outlined)),
                              child: Text(
                                  _endDate == null
                                      ? 'Valitse'
                                      : DateFormat('d.M.yyyy')
                                          .format(_endDate!),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      color: _endDate == null
                                          ? theme.hintColor
                                          : theme.colorScheme.onSurface,
                                      fontSize: 16)),
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
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Matka (km)',
                                prefixIcon:
                                    Icon(Icons.directions_walk_outlined)),
                            validator: (v) => (v != null &&
                                    v.isNotEmpty &&
                                    double.tryParse(v.replaceAll(',', '.')) ==
                                        null)
                                ? 'Virheellinen numero'
                                : null,
                            onChanged: (v) => _distanceController.text =
                                v.replaceAll(',', '.'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _nightsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Yöt (kpl)',
                                prefixIcon: Icon(Icons.night_shelter_outlined)),
                            validator: (v) => (v != null &&
                                    v.isNotEmpty &&
                                    int.tryParse(v) == null)
                                ? 'Virheellinen numero'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    _buildSectionTitle('Lisätiedot (Valinnainen)',
                        Icons.add_circle_outline_outlined),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Repun paino (kg)',
                                prefixIcon: Icon(Icons.backpack_outlined)),
                            validator: (v) => (v != null &&
                                    v.isNotEmpty &&
                                    double.tryParse(v.replaceAll(',', '.')) ==
                                        null)
                                ? 'Virheellinen numero'
                                : null,
                            onChanged: (v) =>
                                _weightController.text = v.replaceAll(',', '.'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _caloriesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Kalorit/pv',
                                prefixIcon:
                                    Icon(Icons.local_fire_department_outlined)),
                            validator: (v) => (v != null &&
                                    v.isNotEmpty &&
                                    int.tryParse(v) == null)
                                ? 'Virheellinen numero'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    _buildSectionTitle(
                        'Postauksen Asetukset', Icons.settings_outlined),
                    Row(
                      children: [
                        Text("Näkyvyys: ", style: theme.textTheme.titleMedium),
                        const SizedBox(width: 8),
                        _buildVisibilityIndicator(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Mitä tietoja jaetaan postauksessa?',
                        style: theme.textTheme.titleMedium),
                    _buildShareOption('Reittikartta (paikkamerkki)', 'route',
                        Icons.map_outlined),
                    _buildShareOption('Pakkauslista (repun paino)', 'packing',
                        Icons.inventory_2_outlined),
                    _buildShareOption('Ruokasuunnitelma (kalorit/pv)', 'food',
                        Icons.restaurant_menu_outlined),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.65),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.secondary)),
                    const SizedBox(height: 20),
                    Text("Tallennetaan vaellusta...",
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: Colors.white70))
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 8.0,
            bottom: MediaQuery.of(context).padding.bottom + 12.0),
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _createPost,
          icon: const Icon(Icons.send_outlined, size: 20),
          label: const Text('Julkaise vaellus'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            disabledBackgroundColor: theme.colorScheme.primary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildShareOption(String title, String key, IconData icon) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      title: Text(title, style: theme.textTheme.bodyLarge),
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
      secondary: Icon(icon, color: theme.colorScheme.secondary),
      activeColor: theme.colorScheme.primary,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      checkboxShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }
}
