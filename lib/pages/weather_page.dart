import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/hike_plan_model.dart';

class WeatherPage extends StatefulWidget {
  final HikePlan hikePlan;
  const WeatherPage({super.key, required this.hikePlan});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final Dio _dio = Dio();
  Map<String, dynamic>? _weatherData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _weatherData = null;
    });

    if (widget.hikePlan.latitude == null || widget.hikePlan.longitude == null) {
      setState(() {
        _errorMessage = 'Sijaintitietoja ei saatavilla vaellussuunnitelmalle.';
        _isLoading = false;
      });
      return;
    }

    final lat = widget.hikePlan.latitude!;
    final lon = widget.hikePlan.longitude!;
    final url =
        'https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$lat&lon=$lon';

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'TrekNoteFlutter/1.0 (your@email.com)', // vaihda oma sähköposti
          },
        ),
      );
      if (mounted) {
        setState(() {
          _weatherData = response.data;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Säätietojen haku epäonnistui: ${e.message}. Tarkista internet-yhteys.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Odottamaton virhe säätietojen haussa: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Hakee nykyisen sään ja seuraavien päivien klo 12 ennusteet
  List<Map<String, dynamic>> _parseForecasts() {
    if (_weatherData == null) return [];
    final timeseries = _weatherData!['properties']?['timeseries'] as List?;
    if (timeseries == null || timeseries.isEmpty) return [];

    final now = DateTime.now();
    final start = widget.hikePlan.startDate.subtract(const Duration(days: 1));
    final end = (widget.hikePlan.endDate ?? widget.hikePlan.startDate)
        .add(const Duration(days: 2));

    // Nykyinen sää (lähin aikaleima)
    Map<String, dynamic>? current;
    int minDiff = 99999999;
    for (final item in timeseries) {
      final dt = DateTime.parse(item['time']);
      final diff = (dt.difference(now)).abs().inMinutes;
      if (diff < minDiff) {
        minDiff = diff;
        current = item;
      }
    }

    // Päiväennusteet klo 12
    final forecasts = <Map<String, dynamic>>[];
    for (final item in timeseries) {
      final dt = DateTime.parse(item['time']);
      if (dt.isAfter(start) && dt.isBefore(end) && dt.hour == 12) {
        forecasts.add(item);
      }
    }

    // Palautetaan nykyinen sää ja ennusteet
    final result = <Map<String, dynamic>>[];
    if (current != null) result.add(current);
    result.addAll(forecasts.where((f) => f != current));
    return result;
  }

  IconData _getWeatherIcon(String symbolCode) {
    // symbolCode esim. "clearsky_day", "partlycloudy_night", "rain"
    if (symbolCode.contains('clearsky')) {
      return FontAwesomeIcons.sun;
    } else if (symbolCode.contains('cloudy')) {
      return FontAwesomeIcons.cloud;
    } else if (symbolCode.contains('fair')) {
      return FontAwesomeIcons.cloudSun;
    } else if (symbolCode.contains('rainshowers') ||
        symbolCode.contains('rain')) {
      return FontAwesomeIcons.cloudShowersHeavy;
    } else if (symbolCode.contains('snow')) {
      return FontAwesomeIcons.snowflake;
    } else if (symbolCode.contains('fog')) {
      return FontAwesomeIcons.smog;
    } else if (symbolCode.contains('thunderstorm')) {
      return FontAwesomeIcons.cloudBolt;
    }
    return FontAwesomeIcons.question;
  }

  Color _getTempColor(double temp) {
    if (temp >= 25) return Colors.redAccent.shade200;
    if (temp >= 15) return Colors.orange.shade300;
    if (temp >= 0) return Colors.tealAccent.shade400;
    if (temp >= -10) return Colors.lightBlueAccent.shade100;
    return Colors.indigoAccent.shade100;
  }

  Widget _buildWeatherCard(Map<String, dynamic> weatherItem,
      {bool isCurrent = false}) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final DateTime dateTime = DateTime.parse(weatherItem['time']);
    final String dayOfWeek = DateFormat('EEE', 'fi_FI').format(dateTime);
    final String timeOfDay = DateFormat('HH:mm').format(dateTime);
    final String date = DateFormat('d.M.').format(dateTime);

    final details = weatherItem['data']['instant']['details'];
    final next1h = weatherItem['data']['next_1_hours']?['summary'];
    final next6h = weatherItem['data']['next_6_hours']?['summary'];

    double temp = details['air_temperature']?.toDouble() ?? 0.0;
    double windSpeed = details['wind_speed']?.toDouble() ?? 0.0;
    double windDeg = details['wind_from_direction']?.toDouble() ?? 0.0;
    int humidity = details['relative_humidity']?.toInt() ?? 0;
    double pressure = details['air_pressure_at_sea_level']?.toDouble() ?? 0.0;

    // Sääkuvake ja kuvaus
    String symbolCode =
        next1h?['symbol_code'] ?? next6h?['symbol_code'] ?? 'clearsky_day';
    String description = _symbolCodeToDescription(symbolCode);

    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 600),
      child: SlideAnimation(
        verticalOffset: 40.0,
        child: FadeInAnimation(
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 2),
            color: theme.colorScheme.surface.withOpacity(0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.18)),
            ),
            elevation: 6,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 24.0, horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    isCurrent
                        ? 'NYKYINEN SÄÄ'
                        : '$dayOfWeek $date${timeOfDay != '00:00' ? ' $timeOfDay' : ''}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 18,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FaIcon(
                    _getWeatherIcon(symbolCode),
                    size: 64,
                    color: _getTempColor(temp),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${temp.round()}°C',
                    style: textTheme.headlineMedium?.copyWith(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: _getTempColor(temp),
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black.withOpacity(0.18),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    description,
                    style: textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.85),
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Divider(color: theme.colorScheme.outline.withOpacity(0.18)),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                      Icons.thermostat, 'Lämpötila', '${temp.round()}°C'),
                  _buildDetailRow(Icons.wind_power, 'Tuuli',
                      '${windSpeed.toStringAsFixed(1)} m/s',
                      icon2: _getWindDirectionIcon(windDeg)),
                  _buildDetailRow(Icons.water_drop, 'Kosteus', '$humidity%'),
                  _buildDetailRow(
                      Icons.speed, 'Ilmanpaine', '${pressure.round()} hPa'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _symbolCodeToDescription(String code) {
    // Yksinkertainen suomennos yleisimmille koodeille
    if (code.contains('clearsky')) return 'Selkeää';
    if (code.contains('cloudy')) return 'Pilvistä';
    if (code.contains('fair')) return 'Puolipilvistä';
    if (code.contains('rainshowers')) return 'Sadekuuroja';
    if (code.contains('rain')) return 'Sateista';
    if (code.contains('snow')) return 'Lumisadetta';
    if (code.contains('fog')) return 'Sumua';
    if (code.contains('thunderstorm')) return 'Ukkosta';
    return 'Säätila tuntematon';
  }

  IconData _getWindDirectionIcon(double deg) {
    if (deg >= 337.5 || deg < 22.5) return Icons.arrow_upward; // N
    if (deg >= 22.5 && deg < 67.5) return Icons.north_east; // NE
    if (deg >= 67.5 && deg < 112.5) return Icons.arrow_forward; // E
    if (deg >= 112.5 && deg < 157.5) return Icons.south_east; // SE
    if (deg >= 157.5 && deg < 202.5) return Icons.arrow_downward; // S
    if (deg >= 202.5 && deg < 247.5) return Icons.south_west; // SW
    if (deg >= 247.5 && deg < 292.5) return Icons.arrow_back; // W
    if (deg >= 292.5 && deg < 337.5) return Icons.north_west; // NW
    return Icons.help_outline;
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {IconData? icon2}) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: theme.colorScheme.secondary.withOpacity(0.85)),
              const SizedBox(width: 10),
              Text(
                label,
                style: textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                value,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (icon2 != null &&
                  icon2.codePoint != Icons.help_outline.codePoint)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child:
                      Icon(icon2, size: 18, color: theme.colorScheme.secondary),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final forecasts = _parseForecasts();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Sää: ${widget.hikePlan.location}',
            style: textTheme.titleLarge),
        backgroundColor: theme.colorScheme.surfaceContainer,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Haetaan säätietoja...', style: textTheme.bodyMedium),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            color: theme.colorScheme.error, size: 60),
                        const SizedBox(height: 20),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchWeatherData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Yritä uudelleen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : forecasts.isEmpty
                  ? Center(
                      child: Text(
                        'Säätietoja ei löytynyt valitulle vaellukselle.',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium,
                      ),
                    )
                  : AnimationLimiter(
                      child: RefreshIndicator(
                        onRefresh: _fetchWeatherData,
                        color: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surface,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 24.0),
                          itemCount: forecasts.length,
                          itemBuilder: (context, idx) => _buildWeatherCard(
                              forecasts[idx],
                              isCurrent: idx == 0),
                        ),
                      ),
                    ),
    );
  }
}
