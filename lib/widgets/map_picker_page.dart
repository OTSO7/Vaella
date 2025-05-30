// lib/widgets/map_picker_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async'; // Tarvitaan Timerille

class MapPickerPage extends StatefulWidget {
  final LatLng initialLocation;

  const MapPickerPage({super.key, required this.initialLocation});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng? _pickedLocation;
  String _pickedAddress = 'Liikuta karttaa valitaksesi sijainnin...';
  bool _isLoadingAddress = false;
  final MapController _mapController = MapController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
    // Hae osoite heti alussa, jos initialLocation on annettu
    _reverseGeocodeLocation(_pickedLocation!);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _handleMapMoved(MapCamera camera, bool hasGesture) {
    // Jos karttaa liikutetaan (ei vain "initial build"), päivitä _pickedLocation
    // ja käynnistä viivästetty geokoodaus.
    if (hasGesture) {
      setState(() {
        _pickedLocation = camera.center;
        _pickedAddress = 'Haetaan osoitetta...'; // Päivitä teksti heti
        _isLoadingAddress = true;
      });

      // Debounce-ajastin, jotta geokoodausta ei tehdä jokaisella pienen liikkeen jälkeen
      if (_debounce?.isActive ?? false) _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (_pickedLocation != null) {
          _reverseGeocodeLocation(_pickedLocation!);
        }
      });
    }
  }

  // Käänteisgeokoodaa sijainti ja päivitä osoite
  Future<void> _reverseGeocodeLocation(LatLng location) async {
    if (!mounted) return;
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
        localeIdentifier: 'fi_FI', // Oikea parametri
      );

      String displayAddress = 'Tuntematon sijainti';
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        // Kootaan osoite osista
        List<String?> addressParts = [
          placemark.thoroughfare, // Katuosoite
          placemark.name, // Mahdollinen paikan nimi
          placemark.locality, // Kaupunki/kunta
          placemark.administrativeArea, // Maakunta/osavaltio
          placemark.country, // Maa
        ];
        // Siivotaan tyhjät tai null-arvot ja yhdistetään
        displayAddress = addressParts
            .where((element) => element != null && element.isNotEmpty)
            .join(', ');

        // Jos osoite on todella pitkä, yritetään lyhyempää muotoa
        if (displayAddress.length > 50) {
          if (placemark.locality != null && placemark.country != null) {
            displayAddress = '${placemark.locality}, ${placemark.country}';
          } else if (placemark.name != null && placemark.locality != null) {
            displayAddress = '${placemark.name}, ${placemark.locality}';
          }
        }
      }

      if (mounted) {
        setState(() {
          _pickedAddress = displayAddress;
        });
      }
    } catch (e) {
      print('Käänteisgeokoodaus epäonnistui: $e');
      if (mounted) {
        setState(() {
          _pickedAddress = 'Osoitteen haku epäonnistui.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Valitse sijainti kartalta'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickedLocation ??
                  const LatLng(60.4518, 22.2666), // Default Turku
              initialZoom: 10.0,
              minZoom: 2.0, // Sallittu minimizoom
              maxZoom: 18.0, // Sallittu maksimizoom
              onTap: (tapPosition, latlng) {
                // Kun käyttäjä napauttaa, keskitä kartta siihen kohtaan
                _mapController.move(latlng, _mapController.camera.zoom);
                _handleMapMoved(
                    _mapController.camera, true); // Simuloi liikettä
              },
              onPositionChanged:
                  _handleMapMoved, // Käsittele kartan liikuttelua
              keepAlive: true,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.treknote', // VAIHDA TÄMÄ SOVELLUKSESI PAKETIN NIMEEN
                // Voit harkita cacheManageria (esim. `flutter_map_tile_caching` -paketti)
                // jos haluat parempaa offline-tukea tai vielä sulavampaa selausta.
              ),
              // MarkerLayer poistettu, koska käytetään keskipisteen tähtäintä
              // if (_pickedLocation != null)
              //   MarkerLayer(
              //     markers: [
              //       Marker(
              //         point: _pickedLocation!,
              //         width: 80,
              //         height: 80,
              //         child: const Icon(
              //           Icons.location_on,
              //           color: Colors.red,
              //           size: 40,
              //         ),
              //       ),
              //     ],
              //   ),
            ],
          ),
          // Tähtäin kartan keskellä
          Center(
            child: Icon(
              Icons.location_on, // Tai Icons.add_location_alt
              color: Theme.of(context)
                  .colorScheme
                  .primary, // Käytä teeman pääväriä
              size: 48,
              shadows: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          // Osoite- ja vahvistuspainike-laatikko
          Positioned(
            bottom: 0, // Aseta ihan alaosaan
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface, // Käytä teeman pintaväriä
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24.0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                // Varmista, ettei mene navigaatiopalkin alle
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _pickedAddress,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_isLoadingAddress)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child:
                            LinearProgressIndicator(), // Hieno latausindikaattori
                      )
                    else if (_pickedLocation != null)
                      Text(
                        'Lat: ${_pickedLocation!.latitude.toStringAsFixed(4)}, Lon: ${_pickedLocation!.longitude.toStringAsFixed(4)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Vahvista sijainti'),
                        onPressed: _pickedLocation != null && !_isLoadingAddress
                            ? () {
                                Navigator.pop(context,
                                    _pickedLocation); // Palauta valittu sijainti
                              }
                            : null, // Poista käytöstä, jos ei sijaintia tai ladataan
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: theme
                              .colorScheme.primary, // Käytä teeman pääväriä
                          foregroundColor: theme.colorScheme
                              .onPrimary, // Tekstin väri päävärin päällä
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Floating Action Button kartan keskittämiseen käyttäjän nykyiseen sijaintiin?
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // Tähän voisi lisätä logiikan nykyisen sijainnin hakemiseksi ja kartan keskittämiseksi
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(content: Text('Sijainnin haku ei vielä toteutettu.')),
      //     );
      //   },
      //   child: const Icon(Icons.my_location),
      // ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
