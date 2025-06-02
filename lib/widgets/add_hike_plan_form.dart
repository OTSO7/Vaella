// lib/widgets/add_hike_plan_form.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart'; // Varmista, että tämä on oikea importti LatLng-luokalle
import '../models/hike_plan_model.dart';
import '../widgets/map_picker_page.dart'; // Varmista, että polku on oikein

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
  final _notesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  double? _latitude;
  double? _longitude;

  List<Map<String, dynamic>> _locationSuggestions = [];
  Timer? _debounce;
  final ValueNotifier<bool> _isSearchingLocation =
      ValueNotifier(false); // Ei tarvitse final, jos alustetaan suoraan
  final FocusNode _locationFocusNode = FocusNode();

  static const _searchDelay = Duration(milliseconds: 400);
  String _currentSearchQuery = '';

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
      _notesController.text = widget.existingPlan!.notes ?? '';
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
    _notesController.dispose();
    _isSearchingLocation.dispose();
    _debounce?.cancel();
    _locationFocusNode.removeListener(_onFocusChanged);
    _locationFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return; // KORJATTU: Lisätty mounted-tarkistus
    if (!_locationFocusNode.hasFocus && _locationSuggestions.isNotEmpty) {
      setState(() {
        _locationSuggestions = [];
      });
    }
  }

  void _onLocationChanged() {
    final query = _locationController.text.trim();
    if (query == _currentSearchQuery && _locationSuggestions.isNotEmpty) {
      // Älä hae uudelleen, jos query sama ja ehdotuksia on jo
      return;
    }
    _currentSearchQuery = query;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(_searchDelay, () {
      if (query == _locationController.text.trim() && query.isNotEmpty) {
        // Hae vain jos query ei ole tyhjä
        _searchLocationSuggestions(query);
      } else if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _locationSuggestions = [];
          });
        }
      }
    });
  }

  Future<void> _pickDate(BuildContext context, bool isStartDate) async {
    // ... (koodi ennallaan)
    final initialDate = (isStartDate ? _startDate : _endDate) ?? DateTime.now();
    final firstDate = isStartDate
        ? DateTime.now().subtract(const Duration(days: 365 * 2))
        : (_startDate ?? DateTime.now());

    if (!mounted) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: isStartDate ? 'Valitse aloituspäivä' : 'Valitse päättymispäivä',
      confirmText: 'Valitse',
      cancelText: 'Peruuta',
      locale: const Locale('fi', 'FI'), // Muutettu suomeksi
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  // Käytä olemassa olevaa colorSchemea pohjana
                  primary: Theme.of(context).colorScheme.primary,
                  onPrimary: Theme.of(context).colorScheme.onPrimary,
                  surface: Theme.of(context).cardColor, // Dialogin tausta
                  onSurface: Theme.of(context)
                      .colorScheme
                      .onSurface, // Tekstit dialogissa
                ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.secondary, // Nappien teksti
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      // mounted-tarkistus on hyvä tässä
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _searchLocationSuggestions(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _locationSuggestions = [];
        });
      }
      _isSearchingLocation.value = false;
      return;
    }

    _isSearchingLocation.value = true;

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1&countrycodes=fi&accept-language=fi'); // Lisätty accept-language

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'VaellusApp/1.0 (sovelluksesi.email@example.com)'
      }); // Geneerisempi User-Agent

      if (!mounted) return; // Tärkeä tarkistus await-kutsun jälkeen

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _locationSuggestions =
              data.map((item) => item as Map<String, dynamic>).toList();
        });
      } else {
        print('Nominatim API error: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Sijaintihaku epäonnistui (virhekoodi: ${response.statusCode})'),
              backgroundColor: Colors.redAccent),
        );
        setState(() =>
            _locationSuggestions = []); // Tyhjennä ehdotukset virheen sattuessa
      }
    } catch (e) {
      print('Location search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sijaintihaku epäonnistui: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
      if (mounted) {
        setState(() =>
            _locationSuggestions = []); // Tyhjennä ehdotukset virheen sattuessa
      }
    } finally {
      if (mounted) {
        // Varmista, että widget on yhä olemassa
        _isSearchingLocation.value = false;
      }
    }
  }

  void _selectLocationSuggestion(Map<String, dynamic> suggestion) {
    if (!mounted) return;

    String displayCandidate = _formatLocationSuggestionName(suggestion);

    setState(() {
      _locationController.text = displayCandidate;
      _latitude = double.tryParse(suggestion['lat'].toString());
      _longitude = double.tryParse(suggestion['lon'].toString());
      _locationSuggestions = []; // Tyhjennä ehdotukset valinnan jälkeen
    });

    _locationFocusNode.unfocus(); // Sulje näppäimistö

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sijainti "$displayCandidate" valittu.'),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickLocationFromMap() async {
    _locationFocusNode.unfocus();
    if (!mounted) return;

    final LatLng? pickedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerPage(
          initialLocation: LatLng(_latitude ?? 60.1699,
              _longitude ?? 24.9384), // Oletus Helsinki, jos ei koordinaatteja
        ),
      ),
    );

    if (pickedLocation != null && mounted) {
      // mounted-tarkistus on jo tässä
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          pickedLocation.latitude,
          pickedLocation.longitude,
          localeIdentifier: 'fi_FI', // Käytetään suomea geokoodauksessa
        );

        if (!mounted) return; // KRIITTINEN TARKISTUS await-kutsun jälkeen

        String displayAddress = 'Tuntematon sijainti';
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          // Yksinkertaistettu osoitteenmuodostus
          displayAddress = [
            placemark.street,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country
          ]
              .where(
                  (s) => s != null && s.isNotEmpty) // Suodata tyhjät ja nullit
              .join(', ');
          if (displayAddress.isEmpty) {
            // Jos kaikki ylläolevat tyhjiä
            displayAddress = placemark.name ?? 'Nimetön paikka kartalla';
          }
        }

        setState(() {
          _locationController.text = displayAddress;
          _latitude = pickedLocation.latitude;
          _longitude = pickedLocation.longitude;
          _locationSuggestions = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sijainti "$displayAddress" valittu kartalta.'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        print("Error in _pickLocationFromMap after placemark: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Sijainnin nimen haku epäonnistui: $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _submitForm() {
    if (!mounted) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Valitse vaelluksen aloituspäivä.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    // Poistettu vaatimus koordinaateille, jos sijainti voidaan syöttää myös vapaasti
    // Jos koordinaatit ovat pakolliset, tämä tarkistus tulee palauttaa:
    // if (_latitude == null || _longitude == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Sijainti tulee valita ehdotuksista tai kartalta.'), backgroundColor: Colors.redAccent),
    //   );
    //   return;
    // }

    HikePlan resultPlan;
    final now = DateTime.now();
    HikeStatus statusToSave = HikeStatus.planned; // Oletus
    if (widget.existingPlan?.status == HikeStatus.cancelled) {
      statusToSave = HikeStatus.cancelled; // Säilytä peruutettu tila
    } else if (_endDate != null &&
        DateTime(_endDate!.year, _endDate!.month, _endDate!.day)
            .isBefore(DateTime(now.year, now.month, now.day))) {
      statusToSave = HikeStatus.completed;
    } else if (_startDate!.isBefore(now.add(const Duration(days: 1)))) {
      // Jos alkaa tänään tai on jo alkanut
      statusToSave = HikeStatus.upcoming;
    }

    if (widget.existingPlan != null) {
      resultPlan = widget.existingPlan!.copyWith(
        hikeName: _nameController.text.trim(),
        location: _locationController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate,
        setEndDateToNull:
            _endDate == null, // Varmista, että null arvo välittyy oikein
        lengthKm: _lengthController.text.trim().isNotEmpty
            ? double.tryParse(
                _lengthController.text.trim().replaceAll(',', '.'))
            : null,
        setLengthKmToNull: _lengthController.text.trim().isEmpty,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        setNotesToNull: _notesController.text.trim().isEmpty,
        latitude: _latitude,
        setLatitudeToNull: _latitude == null,
        longitude: _longitude,
        setLongitudeToNull: _longitude == null,
        status: statusToSave, // Päivitä status tallennettaessa
        // preparationItems ei muuteta tässä formissa suoraan, se hoidetaan erillisessä modaalissa
      );
    } else {
      resultPlan = HikePlan(
        hikeName: _nameController.text.trim(),
        location: _locationController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate,
        lengthKm: _lengthController.text.trim().isNotEmpty
            ? double.tryParse(
                _lengthController.text.trim().replaceAll(',', '.'))
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        latitude: _latitude,
        longitude: _longitude,
        status: statusToSave, // Aseta status uutta suunnitelmaa luotaessa
        // preparationItems alustetaan HikePlan-konstruktorissa
      );
    }

    if (mounted) {
      Navigator.of(context)
          .pop(resultPlan); // Palauta luotu/päivitetty suunnitelma
    }
  }

  // build-metodi ja _buildDateField ennallaan, mutta varmista, että ne ovat täydellisiä
  // ... (aiemmin annettu build-metodi ja _buildDateField-metodi)
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    late DateFormat dateFormat;
    try {
      dateFormat =
          DateFormat('d.M.yyyy', 'fi_FI'); // Käytetään suomalaista muotoilua
    } catch (e) {
      print(
          "DateFormat('fi_FI') failed in AddHikePlanForm: $e. Using default.");
      dateFormat = DateFormat('d.M.yyyy');
    }

    final TextStyle? inputTextStyle = textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurface,
      fontSize: 16,
    );

    return Column(
      // Ei enää mainAxisSize.min, jotta ListView ehdotuksille toimii paremmin
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          // Lisätty yläosaan padding ja kahva
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
          padding: const EdgeInsets.only(
              top: 12.0, bottom: 16.0), // Säädetty padding
          child: Text(
            widget.existingPlan == null
                ? 'Luo uusi vaellussuunnitelma'
                : 'Muokkaa suunnitelmaa',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              fontSize: 22, // Hieman pienempi
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          // Formi vie nyt saatavilla olevan tilan
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Vaelluksen nimi*',
                      hintText: 'Esim. Pääsiäisvaellus Kevolla',
                      prefixIcon: Icon(Icons.flag_outlined,
                          color: theme.colorScheme.primary),
                    ),
                    keyboardType: TextInputType.text,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Anna vaelluksen nimi'
                            : null,
                  ),
                  const SizedBox(height: 18),
                  // Sijaintikenttä ja ehdotukset
                  TextFormField(
                    controller: _locationController,
                    focusNode: _locationFocusNode,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Sijainti*',
                      hintText: 'Kirjoita sijainti tai valitse kartalta...',
                      prefixIcon: Icon(Icons.location_on_outlined,
                          color: theme.colorScheme.primary),
                      suffixIcon: ValueListenableBuilder<bool>(
                        valueListenable: _isSearchingLocation,
                        builder: (context, isSearching, child) {
                          if (isSearching) {
                            return const Padding(
                              padding: EdgeInsets.all(12.0), // Lisätty padding
                              child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.0)),
                            );
                          } else {
                            return IconButton(
                              icon: const Icon(Icons.map_outlined),
                              tooltip: 'Valitse sijainti kartalta',
                              onPressed: _pickLocationFromMap,
                            );
                          }
                        },
                      ),
                    ),
                    onChanged: (value) =>
                        _onLocationChanged(), // Kutsu listeneriä
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Sijainti vaaditaan';
                      }
                      // if (_latitude == null || _longitude == null) return 'Valitse sijainti ehdotuksista tai kartalta'; // Palauta, jos koordinaatit pakollisia
                      return null;
                    },
                  ),
                  if (_locationSuggestions.isNotEmpty &&
                      _locationFocusNode.hasFocus)
                    Container(
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height *
                              0.25), // Rajoita korkeutta
                      margin: const EdgeInsets.only(
                          top: 4, bottom: 8), // Hieman vähemmän marginaalia
                      decoration: BoxDecoration(
                        color: theme.cardColor
                            .withOpacity(0.95), // Hieman läpikuultava
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap:
                            true, // Tärkeä, jotta toimii Columnin sisällä oikein rajoitetulla korkeudella
                        itemCount: _locationSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _locationSuggestions[index];
                          String displayCandidate =
                              _formatLocationSuggestionName(suggestion);
                          return ListTile(
                            leading: Icon(Icons.place_outlined,
                                color: theme.colorScheme.secondary),
                            title: Text(displayCandidate,
                                style: textTheme.bodyMedium),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 0),
                            onTap: () => _selectLocationSuggestion(suggestion),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _lengthController,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Pituus (km)',
                      hintText: 'Esim. 25.5',
                      prefixIcon: Icon(Icons.directions_walk_outlined,
                          color: theme.colorScheme.primary),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final val = value.trim().replaceAll(',', '.');
                        if (double.tryParse(val) == null) {
                          return 'Anna kelvollinen numero';
                        }
                        if (double.parse(val) < 0) {
                          return 'Pituuden tulee olla positiivinen';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18), // Yhdenmukainen väli
                  // Päivämääräkentät
                  Row(
                    crossAxisAlignment: CrossAxisAlignment
                        .start, // Tasaus ylös, jos labelit eri korkeudella
                    children: [
                      Expanded(
                          child: _buildDateField(context, theme, dateFormat,
                              true, 'Aloituspäivä*')),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildDateField(context, theme, dateFormat,
                              false, 'Päättymispäivä')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _notesController,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Muistiinpanot',
                      hintText: 'Esim. varusteet, reitti, pakkauslista...',
                      prefixIcon: Icon(Icons.notes_outlined,
                          color: theme.colorScheme.primary),
                      alignLabelWithHint: true, // Parempi moniriviselle
                    ),
                    keyboardType: TextInputType.multiline,
                    maxLines: 4, // Enemmän tilaa muistiinpanoille
                    minLines: 2,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 28), // Tilaa ennen nappeja
                ],
              ),
            ),
          ),
        ),
        // Nappirivi alhaalla
        Padding(
          padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.of(context).padding.bottom +
                  16), // Ottaa huomioon safe arean
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    if (mounted) Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Peruuta'),
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
                      widget.existingPlan == null
                          ? 'Luo suunnitelma'
                          : 'Tallenna muutokset',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(BuildContext context, ThemeData theme,
      DateFormat dateFormat, bool isStartDate, String labelText) {
    BorderRadius fieldBorderRadius = BorderRadius.circular(12.0); // Oletusarvo
    BorderSide fieldBorderSide =
        theme.inputDecorationTheme.enabledBorder?.borderSide ??
            BorderSide(color: theme.colorScheme.outline, width: 1.0);

    // Tarkista, onko border tyyppiä OutlineInputBorder ennen borderRadiusin käyttöä
    final border = theme.inputDecorationTheme.border;
    if (border is OutlineInputBorder) {
      fieldBorderRadius = border.borderRadius;
    }

    if (theme.inputDecorationTheme.enabledBorder is OutlineInputBorder) {
      final outlineEnabledBorder =
          theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
      fieldBorderRadius = outlineEnabledBorder.borderRadius;
      fieldBorderSide = outlineEnabledBorder.borderSide;
    } else if (theme.inputDecorationTheme.border is OutlineInputBorder) {
      final outlineBorder =
          theme.inputDecorationTheme.border as OutlineInputBorder;
      fieldBorderRadius = outlineBorder.borderRadius;
      fieldBorderSide = outlineBorder.borderSide;
    }

    final TextStyle? buttonTextStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurface,
      fontSize: 16,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(labelText,
            style: theme.textTheme.labelMedium?.copyWith(
              // Käytä labelMedium tai vastaavaa
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontWeight: FontWeight.w500, // Hieman kevyempi kuin bold
            )),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: Icon(Icons.calendar_today_outlined,
              color: theme.colorScheme.secondary, size: 20),
          label: Text(
            (isStartDate ? _startDate : _endDate) == null
                ? 'Valitse päivä'
                : dateFormat.format((isStartDate ? _startDate : _endDate)!),
            style: buttonTextStyle,
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0), // Säädetty padding
            side: fieldBorderSide,
            shape: RoundedRectangleBorder(borderRadius: fieldBorderRadius),
            foregroundColor: theme.colorScheme
                .onSurface, // Tekstin ja ikonin väri, kun ei aktiivinen
          ),
          onPressed: () => _pickDate(context, isStartDate),
        ),
      ],
    );
  }

  String _formatLocationSuggestionName(Map<String, dynamic> suggestion) {
    // ... (koodi ennallaan)
    final displayName = suggestion['display_name'] as String?;
    final address = suggestion['address'] as Map<String, dynamic>?;

    if (displayName == null) return "Nimetön sijainti";
    if (address == null) return displayName;

    List<String?> parts = [];

    // Kokeile poimia merkityksellisimmät osat ensin
    parts.add(address['road'] ??
        address['name'] ??
        address['tourism'] ??
        address['amenity'] ??
        address['shop'] ??
        address['leisure'] ??
        address['natural']);
    parts.add(address['suburb'] ?? address['neighbourhood']);
    parts.add(address['city'] ??
        address['town'] ??
        address['village'] ??
        address['municipality']);
    parts.add(address['county']);
    // parts.add(address['country']); // Maa on usein tarpeeton, jos haetaan Suomesta

    String formattedName = parts
        .where((p) => p != null && p.isNotEmpty)
        .toSet()
        .take(3)
        .join(', '); // Ota max 3 osaa

    return formattedName.isNotEmpty
        ? formattedName
        : displayName.split(',').take(2).join(','); // Fallback
  }
}
