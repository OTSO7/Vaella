import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // For ImageFilter
import '../models/hike_plan_model.dart'; // Ensure this path is correct

// App theme colors (remains the same, uses Theme.of(context))
class AppColors {
  static Color primaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color accentColor(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;
  static Color backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color cardColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface; // Used for card-like backgrounds
  static Color onCardColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface; // Text/icons on cards
  static Color textColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  static Color subtleTextColor(BuildContext context) =>
      Theme.of(context).hintColor;
  static Color errorColor(BuildContext context) =>
      Theme.of(context).colorScheme.error;

  static Color getTempColor(double temp) {
    if (temp >= 30) return Colors.red.shade700;
    if (temp >= 25) return Colors.redAccent.shade200;
    if (temp >= 20) return Colors.orange.shade600;
    if (temp >= 15) return Colors.amber.shade700;
    if (temp >= 10) return Colors.lightGreen.shade600;
    if (temp >= 5) return Colors.teal.shade400;
    if (temp >= 0) return Colors.cyan.shade600;
    if (temp >= -5) return Colors.blue.shade300;
    if (temp >= -10) return Colors.lightBlue.shade200;
    return Colors.indigo.shade200;
  }
}

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
  double? _avgTemp;
  double? _avgDayTemp;
  double? _avgNightTemp;
  bool _showAvg = false;

  // Parsed forecast lists
  Map<String, dynamic>? _currentWeatherHeroData;
  List<Map<String, dynamic>> _dailyForecastsList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchWeatherDataOrAverage();
      }
    });
  }

  Future<void> _fetchWeatherDataOrAverage() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _weatherData = null;
      _currentWeatherHeroData = null;
      _dailyForecastsList = [];
      _avgTemp = null;
      _avgDayTemp = null;
      _avgNightTemp = null;
      _showAvg = false;
    });

    if (widget.hikePlan.latitude == null || widget.hikePlan.longitude == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Location data is not available for this hike plan.';
        _isLoading = false;
      });
      return;
    }

    final lat = widget.hikePlan.latitude!;
    final lon = widget.hikePlan.longitude!;
    final now = DateTime.now();
    final start = widget.hikePlan.startDate;
    final diffDays = start.difference(now).inDays;

    if (diffDays > 10) {
      await _fetchAverageWeather(
          lat, lon, start, widget.hikePlan.endDate ?? start);
      return;
    }

    final url =
        'https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$lat&lon=$lon';

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'TrekNoteFlutter/1.0 (your@email.com)', // Your User-Agent
          },
        ),
      );
      if (mounted) {
        setState(() {
          _weatherData = response.data;
          _parseAndSetForecasts(); // New method to handle parsing
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to fetch weather data: ${e.message}. Please check your internet connection.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unexpected error while fetching weather data: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _parseAndSetForecasts() {
    if (_weatherData == null) return;
    final timeseries = _weatherData!['properties']?['timeseries'] as List?;
    if (timeseries == null || timeseries.isEmpty) return;

    final now = DateTime.now();
    final planStartDate = widget.hikePlan.startDate;

    Map<String, dynamic>? currentForecastItem;
    int minDiffToNow = Duration.microsecondsPerDay;

    for (final item in timeseries) {
      final dt = DateTime.parse(item['time']);
      final diff = dt.difference(now).abs().inMinutes;
      // Prefer forecasts that are not too far in the past or future for "current"
      if (diff < minDiffToNow &&
          dt.isBefore(now.add(const Duration(hours: 2))) &&
          dt.isAfter(now.subtract(const Duration(hours: 2)))) {
        minDiffToNow = diff;
        currentForecastItem = item;
      }
    }
    // If no ideal current found, take the absolute closest one
    if (currentForecastItem == null) {
      minDiffToNow = Duration.microsecondsPerDay;
      for (final item in timeseries) {
        final dt = DateTime.parse(item['time']);
        final diff = dt.difference(now).abs().inMinutes;
        if (diff < minDiffToNow) {
          minDiffToNow = diff;
          currentForecastItem = item;
        }
      }
    }

    final dailyForecasts = <Map<String, dynamic>>[];
    final uniqueDays = <String>{};

    // Korjattu: Ei enää rajoiteta kahteen päivään, vaan näytetään kaikki mahdolliset päivät
    // Otetaan forecast kaikilta päiviltä, jotka löytyvät timeseries-listasta
    for (final item in timeseries) {
      final dt = DateTime.parse(item['time']);
      final dayKey = DateFormat('yyyy-MM-dd', 'en_US').format(dt);

      // Näytetään kaikki tulevat päivät (tänään ja tästä eteenpäin)
      if (!dt.isBefore(DateTime(now.year, now.month, now.day))) {
        // Yritetään ottaa päivän "paras" (klo 11-14), muuten ensimmäinen kyseiseltä päivältä
        if ((dt.hour >= 11 && dt.hour <= 14 && !uniqueDays.contains(dayKey)) ||
            (!uniqueDays.contains(dayKey) &&
                !dailyForecasts.any((f) =>
                    DateFormat('yyyy-MM-dd', 'en_US')
                        .format(DateTime.parse(f['time'])) ==
                    dayKey))) {
          dailyForecasts.add(item);
          uniqueDays.add(dayKey);
        }
      }
    }
    dailyForecasts.sort((a, b) =>
        DateTime.parse(a['time']).compareTo(DateTime.parse(b['time'])));

    // Set current weather data for Hero section
    _currentWeatherHeroData = currentForecastItem;

    // Set daily forecasts, excluding the one already used for hero if it's very similar in time
    _dailyForecastsList = dailyForecasts.where((df) {
      if (_currentWeatherHeroData == null) return true;
      final heroTime = DateTime.parse(_currentWeatherHeroData!['time']);
      final dailyTime = DateTime.parse(df['time']);
      // If the daily forecast is on a different day than hero, include it.
      // Or if on the same day, but not too close to the hero time (e.g. hero is 10am, daily is 12pm).
      return !(heroTime.year == dailyTime.year &&
          heroTime.month == dailyTime.month &&
          heroTime.day == dailyTime.day &&
          (heroTime.hour - dailyTime.hour).abs() < 3);
    }).toList();

    // If _currentWeatherHeroData is null but daily forecasts exist, use the first daily as hero.
    if (_currentWeatherHeroData == null && _dailyForecastsList.isNotEmpty) {
      _currentWeatherHeroData = _dailyForecastsList.first;
    }
  }

  Future<void> _fetchAverageWeather(
      double lat, double lon, DateTime start, DateTime end) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _showAvg = true;
      _errorMessage = null;
      _avgTemp = null;
      _avgDayTemp = null;
      _avgNightTemp = null;
    });

    try {
      double total = 0;
      int count = 0;
      double dayTotal = 0;
      int dayCount = 0;
      double nightTotal = 0;
      int nightCount = 0;
      final years = [
        start.year - 1,
        start.year - 2,
        start.year - 3,
      ];

      for (final year in years) {
        final startStr = DateFormat('yyyy-MM-dd', 'en_US')
            .format(DateTime(year, start.month, start.day));
        final endStr = DateFormat('yyyy-MM-dd', 'en_US')
            .format(DateTime(year, end.month, end.day));
        final url =
            'https://archive-api.open-meteo.com/v1/archive?latitude=$lat&longitude=$lon&start_date=$startStr&end_date=$endStr&daily=temperature_2m_mean,temperature_2m_max,temperature_2m_min&timezone=Europe/Helsinki';
        final response = await _dio.get(url);
        final data = response.data;
        if (data?['daily']?['temperature_2m_mean'] != null) {
          final means = List<double>.from(data['daily']['temperature_2m_mean']
              .map((v) => v?.toDouble() ?? 0.0));
          final maxs = List<double>.from(data['daily']['temperature_2m_max']
              .map((v) => v?.toDouble() ?? 0.0));
          final mins = List<double>.from(data['daily']['temperature_2m_min']
              .map((v) => v?.toDouble() ?? 0.0));
          if (means.isNotEmpty) {
            total += means.reduce((a, b) => a + b);
            count += means.length;
          }
          if (maxs.isNotEmpty) {
            dayTotal += maxs.reduce((a, b) => a + b);
            dayCount += maxs.length;
          }
          if (mins.isNotEmpty) {
            nightTotal += mins.reduce((a, b) => a + b);
            nightCount += mins.length;
          }
        }
      }
      if (mounted) {
        if (count > 0) {
          setState(() {
            _avgTemp = total / count;
            _avgDayTemp = dayCount > 0 ? dayTotal / dayCount : null;
            _avgNightTemp = nightCount > 0 ? nightTotal / nightCount : null;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage =
                'No historical weather data available for this location and period.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to fetch historical weather data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Widget _getWeatherIconWidget(
      BuildContext context, String symbolCode, double temp,
      {double size = 56.0, Color? colorOverride}) {
    Color iconColor = colorOverride ?? AppColors.getTempColor(temp);
    IconData iconData = Icons.help_outline_rounded;

    if (symbolCode.contains('clearsky_day')) {
      iconData = Icons.wb_sunny_rounded;
      iconColor = colorOverride ?? Colors.orangeAccent;
    } else if (symbolCode.contains('clearsky_night')) {
      iconData = Icons.nightlight_round;
      iconColor = colorOverride ?? Colors.deepPurple.shade200;
    } else if (symbolCode.contains('clearsky_polartwilight')) {
      iconData = Icons.brightness_6_rounded;
      iconColor = colorOverride ?? Colors.blueGrey.shade300;
    } else if (symbolCode.contains('fair_day')) {
      iconData = Icons.wb_cloudy_rounded;
      iconColor = colorOverride ?? Colors.amber.shade400;
    } else if (symbolCode.contains('fair_night')) {
      iconData = Icons.cloud_queue_rounded;
      iconColor = colorOverride ?? Colors.blueGrey.shade400;
    } else if (symbolCode.contains('fair_polartwilight')) {
      iconData = Icons.filter_drama_rounded;
      iconColor = colorOverride ?? Colors.blueGrey.shade300;
    } else if (symbolCode.contains('cloudy')) {
      iconData = Icons.cloud_rounded;
      iconColor = colorOverride ?? Colors.blueGrey.shade400;
    } else if (symbolCode.contains('partlycloudy_day')) {
      iconData = Icons.wb_cloudy_outlined;
      iconColor = colorOverride ?? Colors.grey.shade500;
    } else if (symbolCode.contains('partlycloudy_night')) {
      iconData = Icons.cloud_outlined;
      iconColor = colorOverride ?? Colors.blueGrey.shade400;
    } else if (symbolCode.contains('lightrain') ||
        symbolCode.contains('rainshowers_day') ||
        symbolCode.contains('rainshowers_night') ||
        symbolCode.contains('rain')) {
      iconData = Icons.grain_rounded;
      iconColor = colorOverride ?? Colors.blue.shade300;
    } else if (symbolCode.contains('heavyrain')) {
      iconData = Icons.opacity_rounded;
      iconColor = colorOverride ?? Colors.blue.shade600;
    } else if (symbolCode.contains('snow')) {
      iconData = Icons.ac_unit_rounded;
      iconColor = colorOverride ?? Colors.lightBlueAccent.shade100;
    } else if (symbolCode.contains('sleet')) {
      iconData = Icons.cloudy_snowing;
      iconColor = colorOverride ?? Colors.cyan.shade200;
    } else if (symbolCode.contains('fog')) {
      iconData = Icons.foggy;
      try {
        const Icon(Icons.foggy);
      } catch (_) {
        iconData = Icons.blur_on_rounded;
      }
      iconColor = colorOverride ?? Colors.grey.shade400;
    } else if (symbolCode.contains('thunderstorm') ||
        symbolCode.contains('thundershowers_day') ||
        symbolCode.contains('thundershowers_night')) {
      iconData = Icons.flash_on_rounded;
      iconColor = colorOverride ?? Colors.yellow.shade700;
    } else if (symbolCode.contains('clearsky')) {
      iconData = Icons.wb_sunny_rounded;
      iconColor = colorOverride ?? Colors.orangeAccent;
    } else if (symbolCode.contains('fair')) {
      iconData = Icons.wb_cloudy_rounded;
      iconColor = colorOverride ?? Colors.amber.shade400;
    } else if (symbolCode.contains('rainshowers') ||
        symbolCode.contains('rain')) {
      iconData = Icons.grain_rounded;
      iconColor = colorOverride ?? Colors.blue.shade300;
    }
    return Icon(iconData, size: size, color: iconColor);
  }

  // FIX: Improved mapping so "cloudy" and other common codes never return "Unknown"
  String _symbolCodeToDescription(String symbolCode) {
    final code = symbolCode.toLowerCase();
    if (code.contains('clearsky_day')) return 'Clear (day)';
    if (code.contains('clearsky_night')) return 'Clear (night)';
    if (code.contains('clearsky_polartwilight')) {
      return 'Clear (polar twilight)';
    }
    if (code.contains('fair_day')) return 'Fair (day)';
    if (code.contains('fair_night')) return 'Fair (night)';
    if (code.contains('fair_polartwilight')) return 'Fair (polar twilight)';
    if (code.contains('partlycloudy_day')) return 'Partly cloudy (day)';
    if (code.contains('partlycloudy_night')) return 'Partly cloudy (night)';
    if (code.contains('partlycloudy_polartwilight')) {
      return 'Partly cloudy (polar twilight)';
    }
    if (code.contains('cloudy')) return 'Cloudy';
    if (code.contains('lightrainshowers_day')) {
      return 'Light rain showers (day)';
    }
    if (code.contains('lightrainshowers_night')) {
      return 'Light rain showers (night)';
    }
    if (code.contains('lightrainshowers_polartwilight')) {
      return 'Light rain showers (polar twilight)';
    }
    if (code.contains('rainshowers_day')) return 'Rain showers (day)';
    if (code.contains('rainshowers_night')) return 'Rain showers (night)';
    if (code.contains('rainshowers_polartwilight')) {
      return 'Rain showers (polar twilight)';
    }
    if (code.contains('heavyrainshowers_day')) {
      return 'Heavy rain showers (day)';
    }
    if (code.contains('heavyrainshowers_night')) {
      return 'Heavy rain showers (night)';
    }
    if (code.contains('heavyrainshowers_polartwilight')) {
      return 'Heavy rain showers (polar twilight)';
    }
    if (code.contains('lightrain')) return 'Light rain';
    if (code.contains('rain')) return 'Rain';
    if (code.contains('heavyrain')) return 'Heavy rain';
    if (code.contains('lightsnowshowers_day')) {
      return 'Light snow showers (day)';
    }
    if (code.contains('lightsnowshowers_night')) {
      return 'Light snow showers (night)';
    }
    if (code.contains('lightsnowshowers_polartwilight')) {
      return 'Light snow showers (polar twilight)';
    }
    if (code.contains('snowshowers_day')) return 'Snow showers (day)';
    if (code.contains('snowshowers_night')) return 'Snow showers (night)';
    if (code.contains('snowshowers_polartwilight')) {
      return 'Snow showers (polar twilight)';
    }
    if (code.contains('heavysnowshowers_day')) {
      return 'Heavy snow showers (day)';
    }
    if (code.contains('heavysnowshowers_night')) {
      return 'Heavy snow showers (night)';
    }
    if (code.contains('heavysnowshowers_polartwilight')) {
      return 'Heavy snow showers (polar twilight)';
    }
    if (code.contains('lightsnow')) return 'Light snow';
    if (code.contains('snow')) return 'Snow';
    if (code.contains('heavysnow')) return 'Heavy snow';
    if (code.contains('lightsleetshowers_day')) {
      return 'Light sleet showers (day)';
    }
    if (code.contains('lightsleetshowers_night')) {
      return 'Light sleet showers (night)';
    }
    if (code.contains('sleetshowers_day')) return 'Sleet showers (day)';
    if (code.contains('sleetshowers_night')) return 'Sleet showers (night)';
    if (code.contains('heavysleetshowers_day')) {
      return 'Heavy sleet showers (day)';
    }
    if (code.contains('heavysleetshowers_night')) {
      return 'Heavy sleet showers (night)';
    }
    if (code.contains('lightsleet')) return 'Light sleet';
    if (code.contains('sleet')) return 'Sleet';
    if (code.contains('heavysleet')) return 'Heavy sleet';
    if (code.contains('fog')) return 'Fog';
    if (code.contains('lightrainthunder')) return 'Light rain and thunder';
    if (code.contains('rainthunder')) return 'Rain and thunder';
    if (code.contains('heavyrainthunder')) return 'Heavy rain and thunder';
    if (code.contains('lightthundershowers_day')) {
      return 'Light thunder showers (day)';
    }
    if (code.contains('lightthundershowers_night')) {
      return 'Light thunder showers (night)';
    }
    if (code.contains('thundershowers_day')) return 'Thunder showers (day)';
    if (code.contains('thundershowers_night')) return 'Thunder showers (night)';
    if (code.contains('heavythundershowers_day')) {
      return 'Heavy thunder showers (day)';
    }
    if (code.contains('heavythundershowers_night')) {
      return 'Heavy thunder showers (night)';
    }
    if (code.contains('thunderstorm') || code.contains('thunder')) {
      return 'Thunder';
    }
    // Fallback: try to prettify the code
    if (code.isNotEmpty) {
      // Replace underscores and dashes with spaces, capitalize first letter
      String pretty = code.replaceAll('_', ' ').replaceAll('-', ' ');
      pretty = pretty[0].toUpperCase() + pretty.substring(1);
      return pretty;
    }
    return 'Unknown';
  }

  Widget _getWindDirectionIcon(double windDir,
      {required Color color, double size = 18.0}) {
    IconData iconData;
    if (windDir >= 337.5 || windDir < 22.5) {
      iconData = Icons.north_rounded;
    } else if (windDir >= 22.5 && windDir < 67.5) {
      iconData = Icons.north_east_rounded;
    } else if (windDir >= 67.5 && windDir < 112.5) {
      iconData = Icons.east_rounded;
    } else if (windDir >= 112.5 && windDir < 157.5) {
      iconData = Icons.south_east_rounded;
    } else if (windDir >= 157.5 && windDir < 202.5) {
      iconData = Icons.south_rounded;
    } else if (windDir >= 202.5 && windDir < 247.5) {
      iconData = Icons.south_west_rounded;
    } else if (windDir >= 247.5 && windDir < 292.5) {
      iconData = Icons.west_rounded;
    } else if (windDir >= 292.5 && windDir < 337.5) {
      iconData = Icons.north_west_rounded;
    } else {
      iconData = Icons.arrow_upward_rounded;
    }
    return Transform.rotate(
        angle: (windDir * (3.14159265359 / 180)) +
            (90 * (3.14159265359 / 180)), // Rotate to show direction FROM
        child: Icon(Icons.navigation_rounded, size: size, color: color));
  }

  // --- UI WIDGETS ---

  Widget _buildCurrentWeatherHero(BuildContext context,
      Map<String, dynamic> heroData, TextTheme appTextTheme) {
    final details = heroData['data']?['instant']?['details'] ?? {};
    final temp = (details['air_temperature'] ?? 0.0).toDouble();
    final windSpeed = (details['wind_speed'] ?? 0.0).toDouble();
    final windDir = (details['wind_from_direction'] ?? 0.0).toDouble();
    final humidity = (details['relative_humidity'] ?? 0.0).toDouble();

    String symbolCode = '';
    if (heroData['data']?['next_1_hours']?['summary']?['symbol_code'] != null) {
      symbolCode = heroData['data']['next_1_hours']['summary']['symbol_code'];
    } else if (heroData['data']?['next_6_hours']?['summary']?['symbol_code'] !=
        null) {
      symbolCode = heroData['data']['next_6_hours']['summary']['symbol_code'];
    }

    final time = DateTime.parse(heroData['time']);
    final primaryColor = AppColors.primaryColor(context);
    final onSurfaceColor = AppColors.textColor(context);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withOpacity(0.1),
              AppColors.backgroundColor(context).withOpacity(0.3)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMM d', 'en_US').format(time),
            style: appTextTheme.titleMedium
                ?.copyWith(color: onSurfaceColor.withOpacity(0.8)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${temp.toStringAsFixed(0)}°C',
                      style: GoogleFonts.poppins(
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTempColor(temp),
                      ),
                    ),
                    Text(
                      _symbolCodeToDescription(symbolCode),
                      style: appTextTheme.titleLarge?.copyWith(
                          color: onSurfaceColor, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _getWeatherIconWidget(context, symbolCode, temp,
                  size: 80, colorOverride: onSurfaceColor.withOpacity(0.8)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(context, Icons.air_rounded,
                  '${windSpeed.toStringAsFixed(1)} m/s', appTextTheme),
              _buildDetailItem(context, Icons.water_drop_outlined,
                  '${humidity.toStringAsFixed(0)}%', appTextTheme),
              Row(children: [
                _getWindDirectionIcon(windDir,
                    color: onSurfaceColor.withOpacity(0.7), size: 20),
                const SizedBox(width: 4),
                Text("Wind",
                    style: appTextTheme.bodyMedium
                        ?.copyWith(color: onSurfaceColor.withOpacity(0.7)))
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, IconData icon, String value,
      TextTheme appTextTheme) {
    return Row(
      children: [
        Icon(icon,
            color: AppColors.textColor(context).withOpacity(0.7), size: 20),
        const SizedBox(width: 8),
        Text(value,
            style: appTextTheme.bodyMedium?.copyWith(
                color: AppColors.textColor(context).withOpacity(0.9))),
      ],
    );
  }

  Widget _buildDailyForecastItem(BuildContext context,
      Map<String, dynamic> forecastData, TextTheme appTextTheme) {
    final time = DateTime.parse(forecastData['time']);
    final details = forecastData['data']?['instant']?['details'] ?? {};
    final temp = (details['air_temperature'] ?? 0.0).toDouble();

    String symbolCode = '';
    if (forecastData['data']?['next_1_hours']?['summary']?['symbol_code'] !=
        null) {
      symbolCode =
          forecastData['data']['next_1_hours']['summary']['symbol_code'];
    } else if (forecastData['data']?['next_6_hours']?['summary']
            ?['symbol_code'] !=
        null) {
      symbolCode =
          forecastData['data']['next_6_hours']['summary']['symbol_code'];
    } else if (forecastData['data']?['next_12_hours']?['summary']
            ?['symbol_code'] !=
        null) {
      symbolCode =
          forecastData['data']['next_12_hours']['summary']['symbol_code'];
    }

    final windSpeed = (details['wind_speed'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
          color: AppColors.cardColor(context).withOpacity(0.8),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, MMM d', 'en_US').format(time),
                  style: appTextTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onCardColor(context)),
                ),
                Text(
                  _symbolCodeToDescription(symbolCode),
                  style: appTextTheme.bodyMedium
                      ?.copyWith(color: AppColors.subtleTextColor(context)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _getWeatherIconWidget(context, symbolCode, temp,
              size: 40,
              colorOverride: AppColors.onCardColor(context).withOpacity(0.85)),
          Expanded(
            flex: 1,
            child: Text(
              '${temp.toStringAsFixed(0)}°C',
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTempColor(temp)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, TextTheme appTextTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Text(
        title,
        style: appTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold, color: AppColors.textColor(context)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;

    final TextTheme appTextTheme =
        GoogleFonts.latoTextTheme(currentTheme.textTheme).copyWith(
            headlineMedium: GoogleFonts.poppins(
                textStyle: currentTheme.textTheme.headlineMedium),
            headlineSmall: GoogleFonts.poppins(
                textStyle: currentTheme.textTheme.headlineSmall),
            titleLarge: GoogleFonts.poppins(
                textStyle: currentTheme.textTheme.titleLarge),
            titleMedium: GoogleFonts.poppins(
                textStyle: currentTheme.textTheme.titleMedium),
            bodyLarge:
                GoogleFonts.lato(textStyle: currentTheme.textTheme.bodyLarge),
            bodyMedium:
                GoogleFonts.lato(textStyle: currentTheme.textTheme.bodyMedium),
            displaySmall: GoogleFonts.poppins(
                textStyle: currentTheme.textTheme.displaySmall));

    return Theme(
      data: currentTheme.copyWith(
          textTheme: appTextTheme,
          appBarTheme: currentTheme.appBarTheme.copyWith(
            backgroundColor: Colors.transparent,
            elevation: 0,
            titleTextStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: AppColors.textColor(context),
            ),
            iconTheme:
                IconThemeData(color: AppColors.textColor(context), size: 22),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            widget.hikePlan.location,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor(context).withOpacity(0.3),
                    AppColors.backgroundColor(context),
                    AppColors.backgroundColor(context),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.3, 1.0])),
          child: SafeArea(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: colorScheme.primary),
                        const SizedBox(height: 20),
                        Text('Fetching weather data...',
                            style: appTextTheme.titleMedium?.copyWith(
                                color: AppColors.subtleTextColor(context))),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? _buildErrorView(context, appTextTheme)
                    : _showAvg
                        ? _buildAverageWeatherViewNew(context, appTextTheme)
                        : (_currentWeatherHeroData == null &&
                                _dailyForecastsList.isEmpty)
                            ? _buildNoForecastDataView(context, appTextTheme)
                            : RefreshIndicator(
                                onRefresh: _fetchWeatherDataOrAverage,
                                color: colorScheme.primary,
                                backgroundColor: AppColors.cardColor(context),
                                child: CustomScrollView(
                                  slivers: [
                                    if (_currentWeatherHeroData != null)
                                      SliverToBoxAdapter(
                                        child: _buildCurrentWeatherHero(
                                            context,
                                            _currentWeatherHeroData!,
                                            appTextTheme),
                                      ),
                                    if (_dailyForecastsList.isNotEmpty &&
                                        _currentWeatherHeroData != null)
                                      SliverToBoxAdapter(
                                          child: _buildSectionHeader(context,
                                              "Upcoming Days", appTextTheme)),
                                    SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (ctx, idx) {
                                          return AnimationConfiguration
                                              .staggeredList(
                                            position: idx,
                                            duration: const Duration(
                                                milliseconds: 400),
                                            child: SlideAnimation(
                                              verticalOffset: 70.0,
                                              child: FadeInAnimation(
                                                child: _buildDailyForecastItem(
                                                  ctx,
                                                  _dailyForecastsList[idx],
                                                  appTextTheme,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        childCount: _dailyForecastsList.length,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, TextTheme appTextTheme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.errorColor(context), size: 72),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: appTextTheme.titleLarge?.copyWith(
                  color: AppColors.errorColor(context),
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchWeatherDataOrAverage,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoForecastDataView(
      BuildContext context, TextTheme appTextTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded,
              color: AppColors.subtleTextColor(context), size: 72),
          const SizedBox(height: 20),
          Text('No weather data available for this period.',
              textAlign: TextAlign.center,
              style: appTextTheme.titleMedium
                  ?.copyWith(color: AppColors.subtleTextColor(context))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchWeatherDataOrAverage,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  // New visual style for Average Weather
  Widget _buildAverageWeatherViewNew(
      BuildContext context, TextTheme appTextTheme) {
    final currentPrimaryColor = AppColors.primaryColor(context);
    final currentCardColor =
        AppColors.cardColor(context); // For the card itself
    final onCardColor = AppColors.onCardColor(context);
    final subtleOnCardColor = AppColors.subtleTextColor(
        context); // Use hintColor for less emphasis on card

    final startDate = widget.hikePlan.startDate;
    final endDate = widget.hikePlan.endDate;
    final dateString = endDate != null && endDate.isAfter(startDate)
        ? "${DateFormat('MMM d', 'en_US').format(startDate)} – ${DateFormat('MMM d, yyyy', 'en_US').format(endDate)}"
        : DateFormat('MMMM d, yyyy', 'en_US').format(startDate);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
              color: currentCardColor
                  .withOpacity(0.9), // Slightly transparent card
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ]),
          child: SingleChildScrollView(
            // Ensure content is scrollable if it overflows
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_edu_outlined, // More thematic icon
                    size: 60,
                    color: currentPrimaryColor),
                const SizedBox(height: 16),
                Text(
                  "Historical Weather Estimate",
                  textAlign: TextAlign.center,
                  style: appTextTheme.headlineSmall?.copyWith(
                    color: currentPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "For your hike on $dateString",
                  textAlign: TextAlign.center,
                  style: appTextTheme.titleMedium?.copyWith(
                    color: onCardColor.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "The actual forecast is only available up to 10 days in advance. This data shows the typical weather conditions for your selected dates and location based on historical averages from previous years.",
                  textAlign: TextAlign.center,
                  style: appTextTheme.bodyLarge?.copyWith(
                    color: subtleOnCardColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                if (_avgTemp != null) ...[
                  _buildAvgTempRow(
                      "Avg. Temp",
                      _avgTemp!,
                      AppColors.getTempColor(_avgTemp!),
                      appTextTheme,
                      onCardColor),
                  if (_avgDayTemp != null)
                    _buildAvgTempRow("Avg. High", _avgDayTemp!,
                        Colors.orange.shade400, appTextTheme, onCardColor),
                  if (_avgNightTemp != null)
                    _buildAvgTempRow("Avg. Low", _avgNightTemp!,
                        Colors.blue.shade300, appTextTheme, onCardColor),
                ] else ...[
                  Text(
                    "No average data available.",
                    style: appTextTheme.titleMedium
                        ?.copyWith(color: subtleOnCardColor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvgTempRow(String label, double temp, Color tempColor,
      TextTheme appTextTheme, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: appTextTheme.titleMedium
                ?.copyWith(color: textColor.withOpacity(0.9)),
          ),
          Text(
            "${temp.toStringAsFixed(1)}°C",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: tempColor,
            ),
          ),
        ],
      ),
    );
  }
}
