// lib/pages/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart'
    as fb_auth; // Alias to avoid conflict
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

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

  String?
      _profileImageDisplayUrl; // For displaying existing network or asset image
  File? _pickedProfileImageFile; // New image picked by user

  String? _bannerImageDisplayUrl; // For displaying existing network banner
  File? _pickedBannerImageFile; // New banner image picked by user

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.initialProfile.username);
    _displayNameController =
        TextEditingController(text: widget.initialProfile.displayName);
    _bioController =
        TextEditingController(text: widget.initialProfile.bio ?? '');

    // Initialize profile image display
    _profileImageDisplayUrl = widget.initialProfile.photoURL;

    // Initialize banner image display
    // The controller will hold the URL string if it's from network,
    // or an internal marker/path if it's a picked file to be uploaded.
    _bannerImageUrlController =
        TextEditingController(text: widget.initialProfile.bannerImageUrl ?? '');
    _bannerImageDisplayUrl = widget.initialProfile.bannerImageUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _bannerImageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source,
      {required bool isProfileImage}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: source, imageQuality: 70, maxWidth: 1024, maxHeight: 1024);

    if (pickedFile != null) {
      setState(() {
        if (isProfileImage) {
          _pickedProfileImageFile = File(pickedFile.path);
          _profileImageDisplayUrl =
              null; // Clear network URL, FileImage will be used
        } else {
          _pickedBannerImageFile = File(pickedFile.path);
          _bannerImageUrlController.text =
              pickedFile.path; // Store path to indicate new file
          _bannerImageDisplayUrl = null; // Clear network URL
        }
      });
    }
  }

  Future<String?> _uploadImage(File imageFile, String firebasePath) async {
    setState(() => _isLoading = true);
    try {
      final ref = FirebaseStorage.instance.ref().child(firebasePath).child(
          '${fb_auth.FirebaseAuth.instance.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Image upload failed: ${e.toString()}');
      }
      return null;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final authProvider =
        Provider.of<local_auth.AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser == null) {
      _showErrorSnackBar('You must be logged in to edit your profile.');
      setState(() => _isLoading = false);
      return;
    }

    String? finalProfilePhotoUrl = widget.initialProfile.photoURL;
    String? finalBannerImageUrl = widget.initialProfile.bannerImageUrl;

    try {
      // Username uniqueness check (if changed)
      final newUsername = _usernameController.text.trim().toLowerCase();
      if (newUsername != widget.initialProfile.username.toLowerCase()) {
        final existingUsernameDocs = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: newUsername)
            .limit(1)
            .get();

        if (existingUsernameDocs.docs.isNotEmpty) {
          _showErrorSnackBar('Username is already taken.');
          setState(() => _isLoading = false);
          return;
        }
      }

      // Upload new profile image if one was picked
      if (_pickedProfileImageFile != null) {
        finalProfilePhotoUrl =
            await _uploadImage(_pickedProfileImageFile!, 'profile_photos');
        if (finalProfilePhotoUrl == null) {
          // Upload failed
          setState(() => _isLoading = false);
          return;
        }
      }

      // Upload new banner image if one was picked
      if (_pickedBannerImageFile != null) {
        finalBannerImageUrl =
            await _uploadImage(_pickedBannerImageFile!, 'banner_images');
        if (finalBannerImageUrl == null) {
          // Upload failed
          setState(() => _isLoading = false);
          return;
        }
      } else if (_bannerImageUrlController.text.trim().isEmpty) {
        finalBannerImageUrl = null; // User cleared the banner URL
      } else {
        // If controller text is not a local path and not empty, assume it's a network URL
        if (!_bannerImageUrlController.text.contains('/') &&
            !_bannerImageUrlController.text.contains('file:')) {
          finalBannerImageUrl = _bannerImageUrlController.text.trim();
        }
      }

      final updatedProfile = widget.initialProfile.copyWith(
        username: newUsername,
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        photoURL: finalProfilePhotoUrl,
        bannerImageUrl: finalBannerImageUrl,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update(updatedProfile.toFirestore());

      // Update Firebase Auth user display name and photo URL (optional but good practice)
      if (fb_auth.FirebaseAuth.instance.currentUser != null) {
        if (fb_auth.FirebaseAuth.instance.currentUser!.displayName !=
            updatedProfile.displayName) {
          await fb_auth.FirebaseAuth.instance.currentUser!
              .updateDisplayName(updatedProfile.displayName);
        }
        if (fb_auth.FirebaseAuth.instance.currentUser!.photoURL !=
            updatedProfile.photoURL) {
          await fb_auth.FirebaseAuth.instance.currentUser!
              .updatePhotoURL(updatedProfile.photoURL);
        }
      }

      await authProvider.updateLocalUserProfile(updatedProfile);

      if (mounted) {
        _showSuccessSnackBar('Profile updated successfully!');
        context.pop(updatedProfile);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
            'Profile update failed: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lato()),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        margin: const EdgeInsets.all(10.0),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lato()),
        backgroundColor: Colors.redAccent[400],
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        margin: const EdgeInsets.all(10.0),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildProfileImagePicker(ThemeData theme) {
    ImageProvider<Object>? backgroundImage;
    if (_pickedProfileImageFile != null) {
      backgroundImage = FileImage(_pickedProfileImageFile!);
    } else if (_profileImageDisplayUrl != null &&
        _profileImageDisplayUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(_profileImageDisplayUrl!);
    } else {
      backgroundImage = const AssetImage('assets/images/default_avatar.png');
    }

    return Center(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.5), width: 3),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: CircleAvatar(
              radius: 70,
              backgroundColor: theme.colorScheme.surface,
              backgroundImage: backgroundImage,
              onBackgroundImageError: (_, __) {
                // This can happen if NetworkImage fails
                if (mounted) {
                  setState(() =>
                      _profileImageDisplayUrl = 'use_default_placeholder');
                }
              },
              child: (_pickedProfileImageFile == null &&
                      (_profileImageDisplayUrl == null ||
                          _profileImageDisplayUrl!.isEmpty ||
                          _profileImageDisplayUrl == 'use_default_placeholder'))
                  ? Icon(Icons.person_outline_rounded,
                      size: 80, color: theme.hintColor)
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              // Added Material for InkWell splash effect
              color: theme.colorScheme.secondary,
              shape: const CircleBorder(),
              elevation: 2.0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isLoading
                    ? null
                    : () =>
                        _pickImage(ImageSource.gallery, isProfileImage: true),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Icon(Icons.camera_alt_rounded,
                      color: theme.colorScheme.onSecondary, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerImagePicker(ThemeData theme) {
    ImageProvider<Object>? bannerPreviewImage;
    bool showPlaceholder = true;

    if (_pickedBannerImageFile != null) {
      bannerPreviewImage = FileImage(_pickedBannerImageFile!);
      showPlaceholder = false;
    } else if (_bannerImageDisplayUrl != null &&
        _bannerImageDisplayUrl!.isNotEmpty) {
      bannerPreviewImage = NetworkImage(_bannerImageDisplayUrl!);
      showPlaceholder = false;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Banner Image",
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isLoading
              ? null
              : () => _pickImage(ImageSource.gallery, isProfileImage: false),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
              image: showPlaceholder
                  ? null
                  : DecorationImage(
                      image: bannerPreviewImage!,
                      fit: BoxFit.cover,
                      onError: (err, stack) {
                        // Handle NetworkImage load error for banner
                        if (mounted) {
                          setState(() => _bannerImageDisplayUrl =
                              'use_default_placeholder_banner');
                        }
                      }),
            ),
            child: showPlaceholder ||
                    _bannerImageDisplayUrl == 'use_default_placeholder_banner'
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 40, color: theme.hintColor),
                        const SizedBox(height: 8),
                        Text("Tap to select banner",
                            style: GoogleFonts.lato(color: theme.hintColor)),
                      ],
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bannerImageUrlController,
          style: GoogleFonts.lato(color: theme.colorScheme.onSurface),
          decoration: _customInputDecoration(
            labelText: 'Or enter Banner URL',
            hintText: 'https://example.com/banner.jpg',
            prefixIcon: Icons.link_rounded,
            theme: theme,
          ).copyWith(
            suffixIcon: _bannerImageUrlController.text.isNotEmpty &&
                    !_bannerImageUrlController.text.startsWith('/') &&
                    !_bannerImageUrlController.text.startsWith('file:')
                ? IconButton(
                    icon: Icon(Icons.clear, color: theme.hintColor),
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _bannerImageUrlController.clear();
                              _pickedBannerImageFile = null;
                              _bannerImageDisplayUrl = null;
                            });
                          },
                  )
                : null,
          ),
          keyboardType: TextInputType.url,
          enabled: !_isLoading,
          onChanged: (value) {
            // If user types a URL, update the display URL and clear picked file
            if (value.isNotEmpty &&
                (value.startsWith('http') || value.startsWith('https'))) {
              setState(() {
                _bannerImageDisplayUrl = value;
                _pickedBannerImageFile = null;
              });
            } else if (value.isEmpty) {
              setState(() {
                _pickedBannerImageFile = null;
                _bannerImageDisplayUrl = null;
              });
            }
          },
          validator: (value) {
            if (value != null &&
                value.isNotEmpty &&
                !_pickedBannerImageFile_isValidUrl(value)) {
              if (!_pickedBannerImageFile_isValidFilePath(value)) {
                // Check if it's not a picked file path
                return 'Enter a valid URL or pick an image';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  bool _pickedBannerImageFile_isValidUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  bool _pickedBannerImageFile_isValidFilePath(String value) {
    // This is a simple check, assumes picked file paths will be absolute
    return value.startsWith('/') || value.startsWith('file:');
  }

  InputDecoration _customInputDecoration({
    required String labelText,
    String? hintText,
    required IconData prefixIcon,
    required ThemeData theme,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: GoogleFonts.lato(color: theme.colorScheme.onSurfaceVariant),
      hintStyle: GoogleFonts.lato(color: theme.hintColor),
      prefixIcon: Icon(prefixIcon, color: theme.colorScheme.primary, size: 22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0.5, // Subtle elevation
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileImagePicker(theme),
              const SizedBox(height: 32),
              TextFormField(
                controller: _usernameController,
                style: GoogleFonts.lato(
                    color: theme.colorScheme.onSurface, fontSize: 16),
                decoration: _customInputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icons.alternate_email_rounded,
                  theme: theme,
                ),
                enabled: !_isLoading,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  if (value.trim().length > 20) {
                    return 'Username too long (max 20 chars)';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value)) {
                    return 'Letters, numbers, dots, underscores only';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _displayNameController,
                style: GoogleFonts.lato(
                    color: theme.colorScheme.onSurface, fontSize: 16),
                decoration: _customInputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icons.person_rounded,
                  theme: theme,
                ),
                enabled: !_isLoading,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }
                  if (value.trim().length > 30) {
                    return 'Display name too long (max 30 chars)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _bioController,
                style: GoogleFonts.lato(
                    color: theme.colorScheme.onSurface, fontSize: 16),
                decoration: _customInputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell us about yourself...',
                  prefixIcon: Icons.info_outline_rounded,
                  theme: theme,
                ).copyWith(alignLabelWithHint: true),
                maxLines: 3,
                maxLength: 150,
                keyboardType: TextInputType.multiline,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
              _buildBannerImagePicker(theme),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0)),
                  minimumSize:
                      const Size(double.infinity, 50), // Full width button
                ),
                onPressed: _isLoading ? null : _updateProfile,
                icon: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: theme.colorScheme.onPrimary,
                            strokeWidth: 2.5))
                    : const Icon(Icons.save_alt_rounded, size: 22),
                label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
