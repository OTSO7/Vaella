// lib/pages/create_post_page.dart
import 'dart:io'; // Tarvitaan File-objektin käsittelyyn
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Kuvan valintaan
import 'package:firebase_storage/firebase_storage.dart'; // Kuvan tallennukseen
import 'package:cloud_firestore/cloud_firestore.dart'; // Postauksen tallennukseen
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Päivämäärämuotoiluun
import 'package:path/path.dart' as p; // Tiedostopolkujen käsittelyyn

import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../models/user_profile_model.dart'; // Varmista että tämä on tuotu

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

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
  String? _postImageUrl; // Ladatun kuvan URL
  DateTime? _startDate;
  DateTime? _endDate;
  PostVisibility _selectedVisibility = PostVisibility.public;
  final List<String> _selectedSharedData = [];

  bool _isLoading = false;

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

  // Kuvan valinta galleriasta/kamerasta
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = image;
    });
  }

  // Päivämäärän valinta
  Future<void> _selectDate(BuildContext context,
      {required bool isStart}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate; // End date cannot be before start date
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate; // Start date cannot be after end date
          }
        }
      });
    }
  }

  // Kuvan lataus Firebase Storageen
  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    try {
      final String fileName = p.basename(_imageFile!.path);
      final Reference storageRef =
          FirebaseStorage.instance.ref().child('post_images/$fileName');
      await storageRef.putFile(File(_imageFile!.path));
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kuvan lataus epäonnistui: $e')),
      );
      return null;
    }
  }

  // Postauksen luominen ja tallennus Firestoreen
  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Tarkista, että päivämäärät on valittu
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Valitse vaelluksen aloitus- ja päättymispäivämäärät.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final UserProfile? currentUserProfile = authProvider.userProfile;

    if (currentUserProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Käyttäjäprofiilia ei löytynyt. Kirjaudu sisään.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      _postImageUrl = await _uploadImage(); // Lataa kuva ensin

      final newPostRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(); // Luo uusi dokumentti-ID
      final newPost = Post(
        id: newPostRef.id, // Käytä luotua ID:tä
        userId: currentUserProfile.uid,
        username:
            currentUserProfile.displayName, // Käytä displayNamea postauksessa
        userAvatarUrl: currentUserProfile.photoURL ??
            'https://i.pravatar.cc/150?img=0', // Oletuskuva
        postImageUrl: _postImageUrl,
        title: _titleController.text.trim(),
        caption: _captionController.text.trim(),
        timestamp: DateTime.now(), // Postauksen luontiaika
        location: _locationController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        distanceKm: double.tryParse(_distanceController.text.trim()) ?? 0.0,
        nights: int.tryParse(_nightsController.text.trim()) ?? 0,
        weightKg: double.tryParse(_weightController.text.trim()),
        caloriesPerDay: double.tryParse(_caloriesController.text.trim()),
        planId: null, // Tässä vaiheessa emme linkkaa suunnitelmaan
        visibility: _selectedVisibility,
        likes: [],
        commentCount: 0,
        sharedData: _selectedSharedData,
      );

      await newPostRef
          .set(newPost.toFirestore()); // Tallenna postaus Firestoreen

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postaus luotu onnistuneesti!')),
      );
      Navigator.pop(context); // Palaa edelliselle sivulle (HomePage)
    } catch (e) {
      print('Error creating post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Postauksen luominen epäonnistui: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luo uusi postaus'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Kuvan valinta
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: _imageFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      size: 50, color: Colors.grey[600]),
                                  const SizedBox(height: 8),
                                  Text('Valitse kuva vaelluksesta',
                                      style:
                                          TextStyle(color: Colors.grey[700])),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_imageFile!.path),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Otsikko
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Otsikko (esim. Vaellus Lemmenjoella)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Otsikko on pakollinen.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Kuvaus/Kuvateksti ("Miten meni?")
                    TextFormField(
                      controller: _captionController,
                      decoration: const InputDecoration(
                        labelText: 'Miten vaellus meni? (Kuvateksti)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      minLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Kuvateksti on pakollinen.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Sijainti
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Sijainti (esim. Teijon kansallispuisto)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Päivämäärät
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, isStart: true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Aloituspäivä',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _startDate == null
                                    ? 'Valitse'
                                    : DateFormat('d.M.yyyy')
                                        .format(_startDate!),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
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
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _endDate == null
                                    ? 'Valitse'
                                    : DateFormat('d.M.yyyy').format(_endDate!),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Matka ja yöt
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _distanceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Matka (km)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  double.tryParse(value) == null) {
                                return 'Anna kelvollinen numero.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _nightsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Yöt (kpl)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  int.tryParse(value) == null) {
                                return 'Anna kelvollinen kokonaisluku.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Paino ja kalorit (valinnaiset)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Repun paino (kg, valinnainen)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  double.tryParse(value) == null) {
                                return 'Anna kelvollinen numero.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _caloriesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Kalorit/pv (valinnainen)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  double.tryParse(value) == null) {
                                return 'Anna kelvollinen numero.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Näkyvyysvalinta
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Näkyvyys',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PostVisibility>(
                          value: _selectedVisibility,
                          onChanged: (PostVisibility? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedVisibility = newValue;
                              });
                            }
                          },
                          items: PostVisibility.values
                              .map<DropdownMenuItem<PostVisibility>>(
                                  (PostVisibility value) {
                            String text;
                            switch (value) {
                              case PostVisibility.public:
                                text = 'Julkinen (näkyy kaikille)';
                                break;
                              case PostVisibility.friends:
                                text = 'Ystävät (näkyy vain ystäville)';
                                break;
                              case PostVisibility.private:
                                text = 'Yksityinen (näkyy vain minulle)';
                                break;
                            }
                            return DropdownMenuItem<PostVisibility>(
                              value: value,
                              child: Text(text),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Jaettavat tiedot (valintaruudut)
                    Text(
                        'Jaettavat suunnitelman tiedot (näkyvät postauksessa):',
                        style: Theme.of(context).textTheme.titleMedium),
                    CheckboxListTile(
                      title: const Text('Reittikartta (paikkamerkki)'),
                      value: _selectedSharedData.contains('route'),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedSharedData.add('route');
                          } else {
                            _selectedSharedData.remove('route');
                          }
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Pakkauslista (paino)'),
                      value: _selectedSharedData.contains('packing'),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedSharedData.add('packing');
                          } else {
                            _selectedSharedData.remove('packing');
                          }
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Ruokasuunnitelma (kalorit/pv)'),
                      value: _selectedSharedData.contains('food'),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedSharedData.add('food');
                          } else {
                            _selectedSharedData.remove('food');
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Luo postaus -nappi
                    ElevatedButton.icon(
                      onPressed: _createPost,
                      icon: const Icon(Icons.send),
                      label: const Text('Luo postaus'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
