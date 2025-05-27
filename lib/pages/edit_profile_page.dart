// lib/pages/edit_profile_page.dart
import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
// import 'package:image_picker/image_picker.dart'; // Myöhempää kuvavalintaa varten

class EditProfilePage extends StatefulWidget {
  final UserProfile initialProfile;

  const EditProfilePage({super.key, required this.initialProfile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late String? _currentPhotoUrl; // Säilyttää nykyisen tai valitun kuvan URL:n

  // Esimerkki placeholder-avatar-URL:ista, joita voi selata
  final List<String> _dummyAvatarUrls = [
    'https://i.pravatar.cc/300?u=avatar1',
    'https://i.pravatar.cc/300?u=avatar2',
    'https://i.pravatar.cc/300?u=avatar3',
    'https://i.pravatar.cc/300?u=avatar4',
    'https://i.pravatar.cc/300?u=avatar5',
    'https://i.pravatar.cc/300?u=newuser', // Lisää tämä, jos haluat testata uutta
  ];
  int _currentAvatarIndex = 0;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialProfile.displayName);
    _bioController =
        TextEditingController(text: widget.initialProfile.bio ?? '');
    _currentPhotoUrl = widget.initialProfile.photoURL;

    // Etsi nykyisen avatarin indeksi dummy-listasta (jos löytyy)
    if (_currentPhotoUrl != null) {
      final index = _dummyAvatarUrls.indexOf(_currentPhotoUrl!);
      if (index != -1) {
        _currentAvatarIndex = index;
      } else {
        // Jos nykyistä URL:ää ei löydy, lisätään se listan alkuun ja valitaan se
        // (tämä on vain dummy-datan käsittelyä varten)
        // _dummyAvatarUrls.insert(0, _currentPhotoUrl!);
        // _currentAvatarIndex = 0;
        // Tai käytä oletusindeksiä 0, jolloin ensimmäinen dummy-kuva tulee valituksi
      }
    }
  }

  // Simuloi kuvan vaihtoa selaamalla dummy-URL:eja
  void _changeProfilePicture() {
    setState(() {
      _currentAvatarIndex = (_currentAvatarIndex + 1) % _dummyAvatarUrls.length;
      _currentPhotoUrl = _dummyAvatarUrls[_currentAvatarIndex];
    });
  }

  // TODO: Myöhemmin toteuta oikea kuvanvalinta ImagePickerillä
  // Future<void> _pickImage() async {
  //   final ImagePicker picker = ImagePicker();
  //   final XFile? image = await picker.pickImage(source: ImageSource.gallery);
  //   if (image != null && mounted) {
  //     // Tässä vaiheessa kuva pitäisi ladata palvelimelle ja saada URL
  //     // Nyt simuloidaan vain asettamalla paikallinen polku (ei toimi NetworkImagella)
  //     // tai päivittämällä _currentPhotoUrl uudella dummy-URL:lla
  //     setState(() {
  //       _currentPhotoUrl = image.path; // TÄMÄ EI TOIMI SUORAAN NetworkImagella
  //       // Korvaa tämä oikealla URL:lla, kun kuvanlataus on toteutettu
  //     });
  //   }
  // }

  void _saveProfile() {
    if (!mounted) return;

    // Luo päivitetty UserProfile-objekti
    final updatedProfile = UserProfile(
      uid: widget.initialProfile.uid,
      displayName: _nameController.text.trim(),
      email: widget
          .initialProfile.email, // Sähköpostia ei yleensä anneta muokata tässä
      photoURL: _currentPhotoUrl,
      bio: _bioController.text.trim(),
      stats: widget.initialProfile.stats, // Tilastoja ei muokata tässä
      achievements:
          widget.initialProfile.achievements, // Saavutuksia ei muokata tässä
      stickers: widget.initialProfile.stickers,
    );

    // Palauta päivitetty profiili edelliselle sivulle
    Navigator.of(context).pop(updatedProfile);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Muokkaa profiilia'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Tallenna muutokset',
            onPressed: _saveProfile,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    backgroundImage: _currentPhotoUrl != null &&
                            _currentPhotoUrl!.isNotEmpty
                        ? NetworkImage(_currentPhotoUrl!)
                        : const AssetImage('assets/images/default_avatar.png')
                            as ImageProvider,
                    onBackgroundImageError: (_, __) {}, // Käsittele virhe
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Material(
                      // Lisätään Material, jotta InkWellin ripple näkyy
                      color: theme.colorScheme.secondary,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap:
                            _changeProfilePicture, // Vaihdettu _pickImage -> _changeProfilePicture
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            color: theme.colorScheme.onSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed:
                    _changeProfilePicture, // Vaihdettu _pickImage -> _changeProfilePicture
                child: const Text('Vaihda profiilikuva'),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nimi',
                prefixIcon: Icon(Icons.person_outline),
              ),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Kuvaus (bio)',
                hintText: 'Kerro jotain itsestäsi...',
                prefixIcon: Icon(Icons.info_outline),
              ),
              maxLines: 3,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text('Tallenna muutokset'),
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
