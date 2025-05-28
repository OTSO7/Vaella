// lib/pages/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart'; // Kuvan valintaan
import 'dart:io'; // Tiedostokäsittelyyn
import 'package:firebase_storage/firebase_storage.dart'; // Tallentaa kuvat Firebase Storageen
import 'package:firebase_auth/firebase_auth.dart'; // Päivittää Auth-profiilia
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore-tietokanta

import '../models/user_profile_model.dart';
import '../providers/auth_provider.dart' as local_auth;

class EditProfilePage extends StatefulWidget {
  final UserProfile initialProfile;

  const EditProfilePage({super.key, required this.initialProfile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _bannerImageUrlController;

  String? _profileImageUrl; // Paikallinen URL tai tiedostopolku
  File? _pickedProfileImage; // Valittu kuva tiedostona

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.initialProfile.username);
    _displayNameController =
        TextEditingController(text: widget.initialProfile.displayName);
    _bioController = TextEditingController(text: widget.initialProfile.bio);
    _bannerImageUrlController =
        TextEditingController(text: widget.initialProfile.bannerImageUrl);
    _profileImageUrl =
        widget.initialProfile.photoURL; // Aseta oletusarvo profiilikuvalle
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _bannerImageUrlController.dispose();
    super.dispose();
  }

  // Kuvan valinta galleriasta tai kamerasta
  Future<void> _pickImage(ImageSource source, bool isProfileImage) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: source, imageQuality: 70); // Vähennä laatua
    if (pickedFile != null) {
      setState(() {
        if (isProfileImage) {
          _pickedProfileImage = File(pickedFile.path);
          _profileImageUrl =
              null; // Nollaa vanha URL, jos uusi tiedosto on valittu
        } else {
          _bannerImageUrlController.text =
              pickedFile.path; // Tilapäisesti paikallinen polku
        }
      });
    }
  }

  // Kuvan lataus Firebase Storageen
  Future<String?> _uploadImage(File imageFile, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path).child(
          '${FirebaseAuth.instance.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Kuvan lataus epäonnistui: $e');
      _showSnackBar('Kuvan lataus epäonnistui.', Colors.redAccent);
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final auth = Provider.of<local_auth.AuthProvider>(context, listen: false);
    final currentUser = auth.user;
    if (currentUser == null) {
      _showSnackBar(
          'Kirjautuminen vaaditaan profiilin muokkaukseen.', Colors.redAccent);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    String? newProfilePhotoUrl =
        _profileImageUrl; // Säilytä vanha URL, jos ei uutta kuvaa valittu
    String? newBannerImageUrl = _bannerImageUrlController
        .text; // Säilytä vanha URL, jos ei uutta kuvaa valittu

    try {
      // Tarkista käyttäjätunnuksen uniikkius, jos sitä muutetaan
      if (_usernameController.text.trim().toLowerCase() !=
          widget.initialProfile.username.toLowerCase()) {
        final existingUsernameDocs = await FirebaseFirestore.instance
            .collection('users')
            .where('username',
                isEqualTo: _usernameController.text.trim().toLowerCase())
            .limit(1)
            .get();

        if (existingUsernameDocs.docs.isNotEmpty) {
          _showSnackBar('Käyttäjätunnus on jo varattu.', Colors.redAccent);
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Lataa uusi profiilikuva Firebase Storageen, jos valittu
      if (_pickedProfileImage != null) {
        newProfilePhotoUrl =
            await _uploadImage(_pickedProfileImage!, 'profile_photos');
        if (newProfilePhotoUrl == null) {
          setState(() {
            _isLoading = false;
          });
          return; // Kuvan lataus epäonnistui
        }
      }

      // Lataa uusi bannerikuva Firebase Storageen, jos valittu paikallisesta tiedostosta
      if (_bannerImageUrlController.text.startsWith('file://') ||
          _bannerImageUrlController.text.startsWith('/data/')) {
        final bannerFile = File(_bannerImageUrlController.text);
        newBannerImageUrl = await _uploadImage(bannerFile, 'banner_images');
        if (newBannerImageUrl == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Luo päivitetty UserProfile-objekti
      final updatedProfile = widget.initialProfile.copyWith(
        username: _usernameController.text.trim().toLowerCase(),
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        photoURL: newProfilePhotoUrl,
        bannerImageUrl: newBannerImageUrl,
      );

      // Päivitä Firestore-dokumentti
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update(updatedProfile.toFirestore());

      // Päivitä AuthProviderin tila
      await auth.updateLocalUserProfile(updatedProfile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profiili päivitetty!'),
            backgroundColor: Colors.green),
      );
      context.pop(updatedProfile); // Palaa takaisin profiilisivulle
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
          'Profiilin päivitys epäonnistui: ${e.toString().replaceFirst('Exception: ', '')}',
          Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Muokkaa profiilia'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profiilikuvan valitsin
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 80,
                      backgroundColor: theme.colorScheme.surface,
                      backgroundImage: _pickedProfileImage != null
                          ? FileImage(_pickedProfileImage!)
                          : (_profileImageUrl != null &&
                                  _profileImageUrl!.isNotEmpty
                              ? NetworkImage(_profileImageUrl!)
                              : const AssetImage(
                                      'assets/images/default_avatar.png')
                                  as ImageProvider),
                      onBackgroundImageError: (_, __) {
                        setState(() {
                          _profileImageUrl = null; // Virhekuva, käytä oletusta
                        });
                      },
                      child: (_pickedProfileImage == null &&
                              (_profileImageUrl == null ||
                                  _profileImageUrl!.isEmpty))
                          ? Icon(Icons.person,
                              size: 90, color: Colors.grey[500])
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.camera_alt,
                            color: theme.colorScheme.onSecondary),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(10),
                        ),
                        onPressed: () => _pickImage(ImageSource.gallery,
                            true), // Kutsutaan kuvavalitsinta
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Käyttäjätunnus
              TextFormField(
                controller: _usernameController,
                style: textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Käyttäjätunnus',
                  prefixIcon: const Icon(Icons.alternate_email),
                  enabled: !_isLoading, // Ei muokattavissa latauksen aikana
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Syötä käyttäjätunnus';
                  }
                  if (value.trim().length < 3) {
                    return 'Käyttäjätunnuksen tulee olla vähintään 3 merkkiä';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Näyttönimi
              TextFormField(
                controller: _displayNameController,
                style: textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Näyttönimi',
                  prefixIcon: const Icon(Icons.person_outline),
                  enabled: !_isLoading,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Syötä näyttönimi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Bio
              TextFormField(
                controller: _bioController,
                style: textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Kerro itsestäsi lyhyesti...',
                  prefixIcon: const Icon(Icons.info_outline),
                  alignLabelWithHint: true,
                  enabled: !_isLoading,
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 20),

              // Bannerikuvan URL (valinnainen)
              TextFormField(
                controller: _bannerImageUrlController,
                style: textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Bannerikuvan URL (valinnainen)',
                  hintText: 'Käytä URL:ia tai valitse galleriasta',
                  prefixIcon: const Icon(Icons.image_outlined),
                  enabled: !_isLoading,
                  suffixIcon: _isLoading
                      ? null
                      : IconButton(
                          // Valintanappi
                          icon: Icon(Icons.photo_library_outlined,
                              color: theme.colorScheme.secondary),
                          onPressed: () => _pickImage(
                              ImageSource.gallery, false), // Bannerikuva
                        ),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final uri = Uri.tryParse(value);
                    if (uri == null ||
                        (!uri.hasAbsolutePath &&
                            !uri.isScheme('http') &&
                            !uri.isScheme('https') &&
                            !value.startsWith('file://') &&
                            !value.startsWith('/data/'))) {
                      return 'Syötä validi URL tai valitse kuva';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateProfile,
                icon: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_alt_outlined),
                label:
                    Text(_isLoading ? 'Tallennetaan...' : 'Tallenna muutokset'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
