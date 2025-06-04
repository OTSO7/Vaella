import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  double? _avgTemp;
  double? _avgDayTemp;
  double? _avgNightTemp;
  bool _showAvg = false;

  @override
  void initState() {
    super.initState();
    _fetchWeatherDataOrAverage();
  }

  Future<void> _fetchWeatherDataOrAverage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _weatherData = null;
      _avgTemp = null;
      _avgDayTemp = null;
      _avgNightTemp = null;
      _showAvg = false;
    });

    if (widget.hikePlan.latitude == null || widget.hikePlan.longitude == null) {
      setState(() {
        _errorMessage = 'Location data not available for this hike plan.';
        _isLoading = false;
      });
      return;
    }

    final lat = widget.hikePlan.latitude!;
    final lon = widget.hikePlan.longitude!;
    final now = DateTime.now();
    final start = widget.hikePlan.startDate;
    final diffDays = start.difference(now).inDays;

    // If hike is more than 10 days away, show average
    if (diffDays > 10) {
      await _fetchAverageWeather(
          lat, lon, start, widget.hikePlan.endDate ?? start);
      return;
    }

    // Otherwise, fetch normal forecast
    final url =
        'https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$lat&lon=$lon';

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'TrekNoteFlutter/1.0 (your@email.com)',
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
              'Failed to fetch weather data: ${e.message}. Check your internet connection.';
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

  Future<void> _fetchAverageWeather(
      double lat, double lon, DateTime start, DateTime end) async {
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
        final startStr = DateFormat('yyyy-MM-dd')
            .format(DateTime(year, start.month, start.day));
        final endStr =
            DateFormat('yyyy-MM-dd').format(DateTime(year, end.month, end.day));
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
              'No historical weather data available for this location and date.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch historical weather data: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _parseForecasts() {
    if (_weatherData == null) return [];
    final timeseries = _weatherData!['properties']?['timeseries'] as List?;
    if (timeseries == null || timeseries.isEmpty) return [];

    final now = DateTime.now();
    final start = widget.hikePlan.startDate.subtract(const Duration(days: 1));
    final end = (widget.hikePlan.endDate ?? widget.hikePlan.startDate)
        .add(const Duration(days: 2));

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

    final forecasts = <Map<String, dynamic>>[];
    for (final item in timeseries) {
      final dt = DateTime.parse(item['time']);
      if (dt.isAfter(start) && dt.isBefore(end) && dt.hour == 12) {
        forecasts.add(item);
      }
    }

    final result = <Map<String, dynamic>>[];
    if (current != null) result.add(current);
    result.addAll(forecasts.where((f) => f != current));
    return result;
  }

  Widget _getWeatherIconWidget(String symbolCode, double temp) {
    if (symbolCode.contains('clearsky')) {
      return Icon(Icons.wb_sunny_rounded, size: 64, color: _getTempColor(temp));
    } else if (symbolCode.contains('cloudy')) {
      return Icon(Icons.cloud, size: 64, color: Colors.blueGrey.shade400);
    } else if (symbolCode.contains('fair')) {
      return Icon(Icons.wb_cloudy_rounded,
          size: 64, color: Colors.amber.shade400);
    } else if (symbolCode.contains('rainshowers') ||
        symbolCode.contains('rain')) {
      return Icon(Icons.grain, size: 64, color: Colors.blue.shade400);
    } else if (symbolCode.contains('snow')) {
      return Icon(Icons.ac_unit, size: 64, color: Colors.lightBlueAccent);
    } else if (symbolCode.contains('fog')) {
      return Icon(Icons.blur_on, size: 64, color: Colors.grey.shade400);
    } else if (symbolCode.contains('thunderstorm')) {
      return Icon(Icons.flash_on, size: 64, color: Colors.yellow.shade700);
    }
    return Icon(Icons.help_outline, size: 64, color: Colors.grey);
  }

  Color _getTempColor(double temp) {
    if (temp >= 25) return Colors.redAccent.shade200;
    if (temp >= 15) return Colors.orange.shade300;
    if (temp >= 0) return Colors.teal.shade400;
    if (temp >= -10) return Colors.lightBlue.shade100;
    return Colors.indigo.shade100;
  }

  Widget _buildWeatherCard(Map<String, dynamic> forecast,
      {bool isCurrent = false}) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final time = DateTime.parse(forecast['time']);
    final details = forecast['data']?['instant']?['details'] ?? {};
    final temp =
        (details['air_temperature'] ?? details['temperature_2m_mean'] ?? 0.0)
            .toDouble();
    final windSpeed = (details['wind_speed'] ?? 0.0).toDouble();
    final windDir = (details['wind_from_direction'] ?? 0.0).toDouble();

    String symbolCode = '';
    if (forecast['data']?['next_1_hours']?['summary']?['symbol_code'] != null) {
      symbolCode = forecast['data']['next_1_hours']['summary']['symbol_code'];
    } else if (forecast['data']?['next_6_hours']?['summary']?['symbol_code'] !=
        null) {
      symbolCode = forecast['data']['next_6_hours']['summary']['symbol_code'];
    } else if (forecast['data']?['next_12_hours']?['summary']?['symbol_code'] !=
        null) {
      symbolCode = forecast['data']['next_12_hours']['summary']['symbol_code'];
    }

    // Use a more neutral background for readability
    final cardColor = isCurrent
        ? theme.colorScheme.primary.withOpacity(0.12)
        : theme.colorScheme.surface;

    return Card(
      color: cardColor,
      elevation: isCurrent ? 6 : 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            _getWeatherIconWidget(symbolCode, temp),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCurrent
                        ? 'Weather today'
                        : DateFormat('EEE, d.M.').format(time),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _symbolCodeToDescription(symbolCode),
                    style: textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.thermostat,
                          size: 18, color: _getTempColor(temp)),
                      const SizedBox(width: 4),
                      Text(
                        '${temp.toStringAsFixed(1)}°C',
                        style: textTheme.titleLarge?.copyWith(
                          color: _getTempColor(temp),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.air,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${windSpeed.toStringAsFixed(1)} m/s',
                        style: textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _getWindDirectionIcon(windDir),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _symbolCodeToDescription(String symbolCode) {
    if (symbolCode.contains('clearsky')) return 'Clear sky';
    if (symbolCode.contains('cloudy')) return 'Cloudy';
    if (symbolCode.contains('fair')) return 'Fair';
    if (symbolCode.contains('rainshowers')) return 'Rain showers';
    if (symbolCode.contains('rain')) return 'Rain';
    if (symbolCode.contains('snow')) return 'Snow';
    if (symbolCode.contains('fog')) return 'Fog';
    if (symbolCode.contains('thunderstorm')) return 'Thunderstorm';
    return 'Unknown';
  }

  Widget _getWindDirectionIcon(double windDir) {
    IconData icon = Icons.north;
    if (windDir >= 337.5 || windDir < 22.5) {
      icon = Icons.north;
    } else if (windDir >= 22.5 && windDir < 67.5) {
      icon = Icons.north_east;
    } else if (windDir >= 67.5 && windDir < 112.5) {
      icon = Icons.east;
    } else if (windDir >= 112.5 && windDir < 157.5) {
      icon = Icons.south_east;
    } else if (windDir >= 157.5 && windDir < 202.5) {
      icon = Icons.south;
    } else if (windDir >= 202.5 && windDir < 247.5) {
      icon = Icons.south_west;
    } else if (windDir >= 247.5 && windDir < 292.5) {
      icon = Icons.west;
    } else if (windDir >= 292.5 && windDir < 337.5) {
      icon = Icons.north_west;
    }
    return Icon(icon, size: 18);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final forecasts = _parseForecasts();

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text('Weather: ${widget.hikePlan.location}',
            style: textTheme.titleLarge),
        backgroundColor: theme.colorScheme.surface,
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
                  Text('Fetching weather data...', style: textTheme.bodyMedium),
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
                          onPressed: _fetchWeatherDataOrAverage,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _showAvg
                  ? Center(
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        color: theme.colorScheme.surface.withOpacity(0.98),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 24),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 36, horizontal: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.insights_rounded,
                                  size: 64, color: theme.colorScheme.primary),
                              const SizedBox(height: 18),
                              Text(
                                "No forecast available for your hike dates",
                                textAlign: TextAlign.center,
                                style: textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const SizedBox(height: 14),
                              Text(
                                "Weather forecast is only available for the next 10 days.\n"
                                "Below you see the *average weather* for these dates and this location, calculated from previous years.\n"
                                "This is not a forecast, but a statistical average for the selected period.",
                                textAlign: TextAlign.center,
                                style: textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.85),
                                ),
                              ),
                              const SizedBox(height: 28),
                              if (_avgTemp != null) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.thermostat,
                                        color: _getTempColor(_avgTemp!),
                                        size: 32),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${_avgTemp!.toStringAsFixed(1)}°C",
                                      style: textTheme.headlineMedium?.copyWith(
                                        color: _getTempColor(_avgTemp!),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 38,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.wb_sunny_rounded,
                                        color: Colors.orange.shade400,
                                        size: 26),
                                    const SizedBox(width: 6),
                                    Text(
                                      _avgDayTemp != null
                                          ? "Day: ${_avgDayTemp!.toStringAsFixed(1)}°C"
                                          : "Day: -",
                                      style: textTheme.titleMedium?.copyWith(
                                        color: Colors.orange.shade400,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    Icon(Icons.nights_stay_rounded,
                                        color: Colors.blue.shade400, size: 26),
                                    const SizedBox(width: 6),
                                    Text(
                                      _avgNightTemp != null
                                          ? "Night: ${_avgNightTemp!.toStringAsFixed(1)}°C"
                                          : "Night: -",
                                      style: textTheme.titleMedium?.copyWith(
                                        color: Colors.blue.shade400,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Text(
                                  "No average data available.",
                                  style: textTheme.bodyLarge,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                  : AnimationLimiter(
                      child: RefreshIndicator(
                        onRefresh: _fetchWeatherDataOrAverage,
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
