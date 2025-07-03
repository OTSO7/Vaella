// lib/pages/weather_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../models/hike_plan_model.dart';
// POISTETTU: Paikallinen AppColors-luokka. Käytämme nyt suoraan teemaa.

class WeatherPage extends StatefulWidget {
  final HikePlan hikePlan;
  const WeatherPage({super.key, required this.hikePlan});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final Dio _dio = Dio();
  late Future<Map<String, dynamic>> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _fetchAndParseWeather();
  }

  Future<Map<String, dynamic>> _fetchAndParseWeather() async {
    if (widget.hikePlan.latitude == null || widget.hikePlan.longitude == null) {
      throw Exception('Location data is not available for this hike plan.');
    }

    final lat = widget.hikePlan.latitude!;
    final lon = widget.hikePlan.longitude!;
    final now = DateTime.now();
    final start = widget.hikePlan.startDate;
    final diffDays = start.difference(now).inDays;

    if (diffDays > 9) {
      return _fetchAverageWeather(
          lat, lon, start, widget.hikePlan.endDate ?? start);
    }

    final url =
        'https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$lat&lon=$lon';

    try {
      final response = await _dio.get(url,
          options: Options(
              headers: {'User-Agent': 'TrekNote/1.0 (your@email.com)'}));
      return _parseForecastData(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to fetch weather data: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Map<String, dynamic> _parseForecastData(Map<String, dynamic> apiData) {
    final timeseries = apiData['properties']?['timeseries'] as List?;
    if (timeseries == null || timeseries.isEmpty) {
      throw Exception('No forecast data available in the response.');
    }

    final now = DateTime.now();
    final Map<String, dynamic> heroData = timeseries.first;

    final List<Map<String, dynamic>> hourlyData =
        timeseries.whereType<Map<String, dynamic>>().where((item) {
      final dt = DateTime.parse(item['time']);
      return dt.isAfter(now) && dt.isBefore(now.add(const Duration(hours: 24)));
    }).toList();

    final Map<String, List<double>> dailyTemps = {};
    for (var item in timeseries) {
      final dt = DateTime.parse(item['time']);
      final dayKey = DateFormat('yyyy-MM-dd').format(dt);
      final temp =
          item['data']['instant']['details']['air_temperature']?.toDouble();
      if (temp != null) {
        dailyTemps.putIfAbsent(dayKey, () => []).add(temp);
      }
    }

    final List<Map<String, dynamic>> dailyData = [];
    dailyTemps.forEach((dayKey, temps) {
      final day = DateTime.parse(dayKey);
      if (!day.isBefore(DateTime(now.year, now.month, now.day))) {
        final high = temps.reduce((a, b) => a > b ? a : b);
        final low = temps.reduce((a, b) => a < b ? a : b);
        final representativeItem = timeseries.firstWhere(
            (item) =>
                DateFormat('yyyy-MM-dd').format(DateTime.parse(item['time'])) ==
                    dayKey &&
                DateTime.parse(item['time']).hour >= 12,
            orElse: () => timeseries.firstWhere((item) =>
                DateFormat('yyyy-MM-dd').format(DateTime.parse(item['time'])) ==
                dayKey));
        dailyData.add({
          'date': day,
          'high': high,
          'low': low,
          'symbol_code': _getSymbolCode(representativeItem),
        });
      }
    });

    dailyData.sort((a, b) => a['date'].compareTo(b['date']));

    return {
      'isAverage': false,
      'heroData': heroData,
      'hourlyData': hourlyData,
      'dailyData': dailyData,
    };
  }

  Future<Map<String, dynamic>> _fetchAverageWeather(
      double lat, double lon, DateTime start, DateTime end) async {
    try {
      double total = 0, dayTotal = 0, nightTotal = 0;
      int count = 0, dayCount = 0, nightCount = 0;
      final years = [start.year - 1, start.year - 2, start.year - 3];

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
        return {
          'isAverage': true,
          'avgTemp': total / count,
          'avgDayTemp': dayCount > 0 ? dayTotal / dayCount : null,
          'avgNightTemp': nightCount > 0 ? nightTotal / nightCount : null,
        };
      } else {
        throw Exception('No historical data available.');
      }
    } catch (e) {
      throw Exception('Failed to fetch historical data: $e');
    }
  }

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _weatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingView();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorView(
                snapshot.error?.toString() ?? 'No data received.');
          }

          final data = snapshot.data!;
          return data['isAverage'] == true
              ? _buildAverageWeatherView(context, data)
              : _buildForecastView(context, data);
        },
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      width: double.infinity,
      decoration:
          BoxDecoration(gradient: _buildBackgroundGradient(context, 10)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text('Fetching Weather...',
                style:
                    GoogleFonts.poppins(color: Colors.white70, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      width: double.infinity,
      decoration: BoxDecoration(
          gradient: _buildBackgroundGradient(context, 0, isError: true)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 72),
          const SizedBox(height: 24),
          Text(error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 18)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() {
              _weatherFuture = _fetchAndParseWeather();
            }),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.9),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastView(BuildContext context, Map<String, dynamic> data) {
    final heroData = data['heroData'] as Map<String, dynamic>;
    final hourlyData = data['hourlyData'] as List<Map<String, dynamic>>;
    final dailyData = data['dailyData'] as List<Map<String, dynamic>>;
    final temp =
        heroData['data']['instant']['details']['air_temperature'].toDouble();
    final theme = Theme.of(context);
    final appTextTheme = Theme.of(context).textTheme;

    return Container(
      decoration:
          BoxDecoration(gradient: _buildBackgroundGradient(context, temp)),
      child: CustomScrollView(
        slivers: [
          _buildWeatherSliverAppBar(context, heroData, appTextTheme),
          SliverToBoxAdapter(child: const SizedBox(height: 12)),
          _buildHourlyForecast(context, hourlyData, appTextTheme),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: Text('Upcoming Days',
                  style: appTextTheme.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 400),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                      child: _buildDailyForecastCard(
                          context, dailyData[index], appTextTheme)),
                ),
              ),
              childCount: dailyData.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHourlyForecast(BuildContext context,
      List<Map<String, dynamic>> hourlyData, TextTheme appTextTheme) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: hourlyData.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 300),
              child: SlideAnimation(
                horizontalOffset: 50,
                child: FadeInAnimation(
                    child: _buildHourlyForecastChip(
                        context, hourlyData[index], appTextTheme)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHourlyForecastChip(
      BuildContext context, Map<String, dynamic> item, TextTheme appTextTheme) {
    final time = DateTime.parse(item['time']);
    final temp =
        item['data']['instant']['details']['air_temperature'].toDouble();
    final symbolCode = _getSymbolCode(item);

    return Container(
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(DateFormat('HH:mm').format(time),
              style: appTextTheme.bodyMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
          _getWeatherIconWidget(context, symbolCode, temp,
              size: 32, color: Colors.white),
          Text('${temp.round()}°',
              style: appTextTheme.titleMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDailyForecastCard(BuildContext context,
      Map<String, dynamic> dayData, TextTheme appTextTheme) {
    final date = dayData['date'] as DateTime;
    final high = dayData['high'].toDouble();
    final low = dayData['low'].toDouble();
    final symbolCode = dayData['symbol_code'] as String;

    // MUUTETTU: DateFormat-muotoilua vaihdettu näyttämään myös päivämäärä.
    final dayString = DateFormat('EEEE d.M', 'en_US').format(date);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.15),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(dayString, // Käytetään uutta muotoiltua stringiä
                  style: appTextTheme.titleMedium?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600))),
          Expanded(
              flex: 1,
              child: _getWeatherIconWidget(
                  context, symbolCode, (high + low) / 2,
                  size: 30, color: Colors.white)),
          const SizedBox(width: 16),
          Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${high.round()}°',
                      style: appTextTheme.titleMedium?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('${low.round()}°',
                      style: appTextTheme.titleMedium
                          ?.copyWith(color: Colors.white.withOpacity(0.7))),
                ],
              )),
        ],
      ),
    );
  }

  SliverAppBar _buildWeatherSliverAppBar(BuildContext context,
      Map<String, dynamic> heroData, TextTheme appTextTheme) {
    final temp =
        heroData['data']['instant']['details']['air_temperature'].toDouble();
    final symbolCode = _getSymbolCode(heroData);
    final description = _symbolCodeToDescription(symbolCode);

    return SliverAppBar(
      expandedHeight: 350,
      stretch: true,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            _getWeatherIconWidget(context, symbolCode, temp,
                size: 100, color: Colors.white),
            const SizedBox(height: 8),
            Text('${temp.round()}°',
                style: GoogleFonts.poppins(
                    fontSize: 80,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1)),
            Text(description,
                style: appTextTheme.titleLarge?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(widget.hikePlan.location,
                style: appTextTheme.titleMedium
                    ?.copyWith(color: Colors.orange.shade300))
          ],
        ),
      ),
    );
  }

  Widget _buildAverageWeatherView(
      BuildContext context, Map<String, dynamic> data) {
    final avgTemp = data['avgTemp'] as double;
    final avgDayTemp = data['avgDayTemp'] as double?;
    final avgNightTemp = data['avgNightTemp'] as double?;
    final appTextTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration:
          BoxDecoration(gradient: _buildBackgroundGradient(context, avgTemp)),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            const Icon(Icons.history_toggle_off_rounded,
                color: Colors.white, size: 60),
            const SizedBox(height: 16),
            Text('Historical Estimate',
                style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text('for ${widget.hikePlan.location}',
                style: GoogleFonts.lato(fontSize: 18, color: Colors.white70)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2), width: 1.5)),
              child: Column(
                children: [
                  Text('Average Temp.',
                      style: GoogleFonts.lato(
                          fontSize: 18, color: Colors.white70)),
                  Text('${avgTemp.round()}°',
                      style: GoogleFonts.poppins(
                          fontSize: 64,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (avgDayTemp != null)
                        Column(
                          children: [
                            Text('Avg. High',
                                style: GoogleFonts.lato(color: Colors.white70)),
                            Text('${avgDayTemp.round()}°',
                                style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ],
                        ),
                      if (avgNightTemp != null)
                        Column(
                          children: [
                            Text('Avg. Low',
                                style: GoogleFonts.lato(color: Colors.white70)),
                            Text('${avgNightTemp.round()}°',
                                style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ],
                        ),
                    ],
                  )
                ],
              ),
            ),
            const Spacer(),
            Text('Actual forecast available < 10 days before the hike.',
                style: GoogleFonts.lato(
                    color: Colors.white70, fontStyle: FontStyle.italic)),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // APUFUNKTIOT

  // MUUTETTU: Käyttää nyt teeman värejä kovakoodattujen sijaan
  Color _getThemedTempColor(BuildContext context, double temp) {
    final theme = Theme.of(context);
    if (temp >= 25) return theme.colorScheme.error;
    if (temp >= 15) return theme.colorScheme.secondary;
    if (temp >= 5) return theme.colorScheme.primary;
    return Colors.blue.shade300; // Pidetään kylmälle oma, selkeä väri
  }

  LinearGradient _buildBackgroundGradient(BuildContext context, double temp,
      {bool isError = false}) {
    // MUUTETTU: Käyttää teematietoista lämpötilaväriä
    Color baseColor =
        isError ? Colors.grey.shade800 : _getThemedTempColor(context, temp);
    return LinearGradient(
        colors: [
          baseColor.withOpacity(0.8),
          Theme.of(context).scaffoldBackgroundColor
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.7]);
  }

  String _getSymbolCode(Map<String, dynamic> item) {
    return item['data']?['next_1_hours']?['summary']?['symbol_code'] ??
        item['data']?['next_6_hours']?['summary']?['symbol_code'] ??
        item['data']?['next_12_hours']?['summary']?['symbol_code'] ??
        'unknown';
  }

  String _symbolCodeToDescription(String symbolCode) {
    final code = symbolCode.toLowerCase();
    if (code.contains('clearsky_day')) return 'Clear';
    if (code.contains('clearsky_night')) return 'Clear';
    if (code.contains('fair')) return 'Fair';
    if (code.contains('partlycloudy')) return 'Partly Cloudy';
    if (code.contains('cloudy')) return 'Cloudy';
    if (code.contains('rainshowers')) return 'Rain Showers';
    if (code.contains('rain')) return 'Rain';
    if (code.contains('snowshowers')) return 'Snow Showers';
    if (code.contains('snow')) return 'Snow';
    if (code.contains('sleet')) return 'Sleet';
    if (code.contains('fog')) return 'Fog';
    if (code.contains('thunder')) return 'Thunderstorm';
    return 'Cloudy';
  }

  Widget _getWeatherIconWidget(
      BuildContext context, String symbolCode, double temp,
      {double size = 56.0, Color? color}) {
    IconData iconData;
    final code = symbolCode.toLowerCase();
    if (code.contains('sun') || code.contains('clearsky_day'))
      iconData = Icons.wb_sunny_rounded;
    else if (code.contains('clearsky_night'))
      iconData = Icons.nightlight_round;
    else if (code.contains('cloud') || code.contains('fair'))
      iconData = Icons.cloud_queue_rounded;
    else if (code.contains('rain'))
      iconData = Icons.grain_rounded;
    else if (code.contains('snow'))
      iconData = Icons.ac_unit_rounded;
    else if (code.contains('sleet'))
      iconData = Icons.cloudy_snowing;
    else if (code.contains('fog'))
      iconData = Icons.foggy;
    else if (code.contains('thunder'))
      iconData = Icons.flash_on_rounded;
    else
      iconData = Icons.wb_cloudy_rounded;
    return Icon(iconData, size: size, color: color ?? Colors.white);
  }

  // POISTETTU: _getAppTextTheme on nyt tarpeeton, koska teema periytyy oikein.
}
