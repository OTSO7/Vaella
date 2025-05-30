// lib/pages/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart'; // For picking images
import 'dart:io'; // For file handling
import 'package:firebase_storage/firebase_storage.dart'; // For uploading images to Firebase Storage
import 'package:firebase_auth/firebase_auth.dart'; // For updating Auth profile
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore database

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

  String? _profileImageUrl; // Local URL or file path
  File? _pickedProfileImage; // Picked image as file

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
        widget.initialProfile.photoURL; // Set default profile image
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _bannerImageUrlController.dispose();
    super.dispose();
  }

  // Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source, bool isProfileImage) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: source, imageQuality: 70); // Lower quality
    if (pickedFile != null) {
      setState(() {
        if (isProfileImage) {
          _pickedProfileImage = File(pickedFile.path);
          _profileImageUrl = null; // Reset old URL if a new file is picked
        } else {
          _bannerImageUrlController.text =
              pickedFile.path; // Temporarily local path
        }
      });
    }
  }

  // Upload image to Firebase Storage
  Future<String?> _uploadImage(File imageFile, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path).child(
          '${FirebaseAuth.instance.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Image upload failed: $e');
      _showSnackBar('Image upload failed.', Colors.redAccent);
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
          'You must be logged in to edit your profile.', Colors.redAccent);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    String? newProfilePhotoUrl =
        _profileImageUrl; // Keep old URL if no new image picked
    String? newBannerImageUrl =
        _bannerImageUrlController.text; // Keep old URL if no new image picked

    try {
      // Check username uniqueness if changed
      if (_usernameController.text.trim().toLowerCase() !=
          widget.initialProfile.username.toLowerCase()) {
        final existingUsernameDocs = await FirebaseFirestore.instance
            .collection('users')
            .where('username',
                isEqualTo: _usernameController.text.trim().toLowerCase())
            .limit(1)
            .get();

        if (existingUsernameDocs.docs.isNotEmpty) {
          _showSnackBar('Username is already taken.', Colors.redAccent);
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Upload new profile image to Firebase Storage if picked
      if (_pickedProfileImage != null) {
        newProfilePhotoUrl =
            await _uploadImage(_pickedProfileImage!, 'profile_photos');
        if (newProfilePhotoUrl == null) {
          setState(() {
            _isLoading = false;
          });
          return; // Image upload failed
        }
      }

      // Upload new banner image to Firebase Storage if picked from local file
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

      // Create updated UserProfile object
      final updatedProfile = widget.initialProfile.copyWith(
        username: _usernameController.text.trim().toLowerCase(),
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        photoURL: newProfilePhotoUrl,
        bannerImageUrl: newBannerImageUrl,
      );

      // Update Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update(updatedProfile.toFirestore());

      // Update AuthProvider state
      await auth.updateLocalUserProfile(updatedProfile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile updated!'), backgroundColor: Colors.green),
      );
      context.pop(updatedProfile); // Return to profile page
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
          'Profile update failed: ${e.toString().replaceFirst('Exception: ', '')}',
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
        title: const Text('Edit profile'),
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
              // Profile image picker
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
                          _profileImageUrl = null; // Use default on error
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
                        onPressed: () => _pickImage(
                            ImageSource.gallery, true), // Open image picker
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Username
              TextFormField(
                controller: _usernameController,
                style: textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.alternate_email),
                  enabled: !_isLoading, // Not editable while loading
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a username';
                  }
                  if (value.trim().length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Display name
              TextFormField(
                controller: _displayNameController,
                style: textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: const Icon(Icons.person_outline),
                  enabled: !_isLoading,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a display name';
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
                  hintText: 'Tell something about yourself...',
                  prefixIcon: const Icon(Icons.info_outline),
                  alignLabelWithHint: true,
                  enabled: !_isLoading,
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 20),

              // Banner image URL (optional)
              TextFormField(
                controller: _bannerImageUrlController,
                style: textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Banner image URL (optional)',
                  hintText: 'Use a URL or pick from gallery',
                  prefixIcon: const Icon(Icons.image_outlined),
                  enabled: !_isLoading,
                  suffixIcon: _isLoading
                      ? null
                      : IconButton(
                          // Picker button
                          icon: Icon(Icons.photo_library_outlined,
                              color: theme.colorScheme.secondary),
                          onPressed: () => _pickImage(
                              ImageSource.gallery, false), // Banner image
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
                      return 'Enter a valid URL or pick an image';
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
                label: Text(_isLoading ? 'Saving...' : 'Save changes'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
