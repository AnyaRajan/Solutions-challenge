import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  String? apiKey = dotenv.env['WEATHER_API_KEY']; // api key in dot env file
  String? locationKey;
  Map<String, dynamic>? weatherData;
  String? error;
  bool isLoading = false;
  bool locationDenied = false;
  String lang = 'en-us'; // language can be selected during registration

  @override
  void initState() {
    super.initState();
    _checkLocationAndFetch();
  }

  Future<void> _checkLocationAndFetch() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => locationDenied = true);
      return;
    }
    await _getWeatherData();
  }

  Future<void> _getWeatherData() async {
    setState(() {
      isLoading = true;
      error = null;
      locationDenied = false;
    });

    try {
      final position = await _getCurrentLocation();
      locationKey = await _getLocationKey(position);
      weatherData = await _getWeatherForecast(locationKey!);
    } catch (e) {
      if (mounted) {
    setState(() => error = e.toString());
  }
    } finally {
      if (mounted) {
    setState(() => isLoading = false);
  }
    }
  }

  Future<Position> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied';
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<String> _getLocationKey(Position position) async {
    final response = await http.get(Uri.parse(
        'http://dataservice.accuweather.com/locations/v1/cities/geoposition/search'
        '?apikey=$apiKey'
        '&q=${position.latitude},${position.longitude}'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['Key'];
    } else {
      throw 'Failed to get location key: ${response.statusCode}';
    }
  }

  Future<Map<String, dynamic>> _getWeatherForecast(String locationKey) async {
    final response = await http.get(Uri.parse(
        'http://dataservice.accuweather.com/forecasts/v1/daily/5day/$locationKey'
        '?apikey=$apiKey'
        '&language=$lang'
        '&metric=true'
        // '&language=hi-in'
        ));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw 'Failed to get weather forecast: ${response.statusCode}';
    }
  }
  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
    await _checkLocationAndFetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Forecast'),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getWeatherData,
          ),
        ],
      ),
      body: _buildBody(),
      backgroundColor: Colors.blue[50],
    );
  }

  Widget _buildBody() {
    if (locationDenied) {
      return _buildLocationDeniedView();
    }

    if (isLoading) {
      return const Center(child: WeatherLoadingIndicator());
    }

    if (error != null) {
      return WeatherErrorView(error: error!, onRetry: _getWeatherData);
    }

    if (weatherData == null) {
      return const Center(child: Text('No weather data available'));
    }

    return _buildWeatherContent();
  }

  Widget _buildLocationDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              'Location Services Disabled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'We need your location to provide accurate weather forecasts',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on, color: Colors.white,),
              label: const Text('Enable Location', style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: const EdgeInsets.symmetric(
                    horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _openLocationSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherContent() {
    final dailyForecasts = weatherData!['DailyForecasts'];
    return RefreshIndicator(
      onRefresh: _getWeatherData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 10),
          ...dailyForecasts.map<Widget>(
            (dailyForecast) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: DailyWeatherCard(
                temperature: dailyForecast['Temperature'],
                day: dailyForecast['Day'],
                night: dailyForecast['Night'],
                date: dailyForecast['Date'],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WeatherLoadingIndicator extends StatelessWidget {
  const WeatherLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          strokeWidth: 5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
        const SizedBox(height: 20),
        Text(
          'Fetching Weather Data...',
          style: TextStyle(
            fontSize: 18,
            color: Colors.blue[800],
          ),
        ),
      ],
    );
  }
}

class WeatherErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const WeatherErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              'Error Occurred',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyWeatherCard extends StatelessWidget {
  final dynamic temperature;
  final dynamic day;
  final dynamic night;
  final String date;

  const DailyWeatherCard({
    super.key,
    required this.temperature,
    required this.day,
    required this.night,
    required this.date,
  });

  List<String> get formattedDate => date.split('T')[0].split('-');

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[400]!, Colors.blue[800]!],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Date
              Text(
                '${formattedDate[2]}/${formattedDate[1]}/${formattedDate[0]}',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              
              // Temperature
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.thermostat, color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Text(
                    '${temperature['Minimum']['Value'].round()}° - '
                    '${temperature['Maximum']['Value'].round()}°',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Day/Night Info
              _buildWeatherSection(
                icon: Icons.wb_sunny,
                title: 'Day',
                description: day['IconPhrase'],
              ),
              const Divider(color: Colors.white54, height: 30),
              _buildWeatherSection(
                icon: Icons.nightlight_round,
                title: 'Night',
                description: night['IconPhrase'],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}