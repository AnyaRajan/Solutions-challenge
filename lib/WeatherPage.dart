import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async{
  await dotenv.load(fileName: ".env");
  runApp(WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WeatherScreen(),
    );
  }
}

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
  String lang = 'en-us'; // language can be selected during registration

  @override
  void initState() {
    super.initState();
    _getWeatherData();
  }

  Future<void> _getWeatherData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Getting device location
      final position = await _getCurrentLocation();

      // 2. Get location key from AccuWeather
      if (position == null) {
        throw "unable to get position";
      }

      locationKey = await _getLocationKey(position);

      // 3. Get weather forecast
      if (locationKey == null) {
        throw "unable to get locationKey.";
      }

      weatherData = await _getWeatherForecast(locationKey!);
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled';
    }

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

  @override
  Widget build(BuildContext context) {
    if (weatherData == null && isLoading) {
      return const CircularProgressIndicator();
    }

    if (weatherData == null && !isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Weather Forecast'),
        ),
        body: Center(
          child: Text("Unable to get Weather data",
              style: const TextStyle(fontSize: 20, color: Colors.amber)),
        ),
      );
    }
    ;
    List dailyForecasts = weatherData!['DailyForecasts'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Forecast'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: dailyForecasts
                .map<Widget>((dailyForecast) => _buildContent(dailyForecast))
                .toList(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getWeatherData,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> dailyForecast) {
    if (isLoading) {
      return const CircularProgressIndicator();
    }

    if (error != null) {
      return Text(
        'Error: $error',
        style: const TextStyle(color: Color.fromARGB(255, 90, 246, 140)),
      );
    }

    if (weatherData == null) {
      return const Text('No weather data available');
    }
    final date = dailyForecast['Date'];
    final temperature = dailyForecast['Temperature'];
    final day = dailyForecast['Day'];
    final night = dailyForecast['Night'];

    return DailyWeatherCard(
        temperature: temperature, day: day, night: night, date: date);
  }
}

class DailyWeatherCard extends StatelessWidget {
  const DailyWeatherCard({
    super.key,
    required this.temperature,
    required this.day,
    required this.night,
    required this.date,
  });

  final temperature;
  final day;
  final night;
  final date;

  List get dateSimplified => date.split('T')[0].split('-').toList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade400, Colors.blue.shade900],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date Display
                Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${dateSimplified[2]} - ${dateSimplified[1]} - ${dateSimplified[0]}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Temperature Display
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.thermostat,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${temperature['Minimum']['Value'].round()}°${temperature['Minimum']['Unit']} - '
                        '${temperature['Maximum']['Value'].round()}°${temperature['Minimum']['Unit']}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // Day Weather
                _buildWeatherInfo(
                  title: 'Day',
                  description: day['IconPhrase'],
                  icon: Icons.wb_sunny,
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Colors.white30, thickness: 1),
                ),

                // Night Weather
                _buildWeatherInfo(
                  title: 'Night',
                  description: night['IconPhrase'],
                  icon: Icons.nightlight_round,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherInfo({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}