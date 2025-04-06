import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'profile_page.dart';
import 'chatbot.dart';
import 'soilDisease.dart'; 
import 'WeatherPage.dart';
import 'SoilEvalPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  await dotenv.load(fileName: ".env");
  runApp( FarmersApp(cameras: cameras,));
}

class FarmersApp extends StatelessWidget {
    final List<CameraDescription> cameras;
    FarmersApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmers App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home:  HomePage(cameras: cameras,),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  HomePage({Key? key, required this.cameras}) : super(key: key);


  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeScreen(),
      const Center(child: Text("Market Page", style: TextStyle(fontSize: 18))),
      const ProfilePage(),
      const ChatbotPage(),
      DiseaseDetectionPage(cameras: widget.cameras), // 👈 New Page Added
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_basket), label: "Market"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          BottomNavigationBarItem(
              icon: Icon(Icons.support_agent), label: "Chatbot"),
          BottomNavigationBarItem(
              icon: Icon(Icons.healing), label: "Disease"), // 👈 New Item
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmers Hub',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[700],
        centerTitle: true,
        elevation: 4,
      ),
      body: Stack(
        children: [
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeatherSection(),
                  const SizedBox(height: 20),
                  _buildQuickActions(context),
                  const SizedBox(height: 20),
                  _buildInfoCard(
                      "🌱 Sustainable Farming",
                      "Explore tips for eco-friendly farming practices.",
                      Colors.green),
                  const SizedBox(height: 10),
                  _buildInfoCard(
                      "💡 Smart Techniques",
                      "Learn about the latest innovations in agriculture.",
                      Colors.yellow[700]!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.blue, Colors.green]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 8)
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's Weather",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text("☀  28°C  |  Clear Sky",
                  style: TextStyle(fontSize: 16, color: Colors.white70)),
            ],
          ),
          Icon(Icons.wb_sunny, size: 40, color: Colors.yellowAccent),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Quick Actions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionButton(
                icon: Icons.shopping_cart, label: "Market Prices", color: Colors.red, onTap: () {
                  print("clicked");
                }),
            _buildActionButton(icon:  Icons.cloud, label: "Weather",color:  Colors.blue, onTap: () {
                  _navigateToWeatherScreen(context);
                }),
            _buildActionButton(
                icon: Icons.lightbulb,label:  "Farming Advice",color:  Colors.yellow[800]!, onTap: () {
                  print("clicked");
                }),
          ],
        ),
      ],
    );
  }

Widget _buildActionButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, size: 30, color: color),
        ),
        const SizedBox(height: 5),
        Text(
          label, 
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
void _navigateToWeatherScreen(BuildContext context) async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const WeatherScreen(),
    ),
  );
  

}

  Widget _buildInfoCard(String title, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 5),
          Text(description,
              style: TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }
}