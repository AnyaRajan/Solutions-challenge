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
      HomeScreen( cameras: widget.cameras,),
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

class HomeScreen extends StatefulWidget {
  
  final List<CameraDescription> cameras;
  
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _cropNameController = TextEditingController();
  final TextEditingController _cropImageController = TextEditingController();
  final TextEditingController _cropFeaturesController = TextEditingController();
  final List<Map<String, dynamic>> _crops = [];


  @override
  void dispose() {
    _cropNameController.dispose();
    _cropImageController.dispose();
    _cropFeaturesController.dispose();
    super.dispose();
  }


  void _addCrop() {
    if (_cropNameController.text.isNotEmpty && 
        _cropImageController.text.isNotEmpty) {
      setState(() {
        _crops.add({
          "name": _cropNameController.text,
          "image": _cropImageController.text,
          "features": _cropFeaturesController.text.isEmpty ? 
            "No additional information available" : 
            _cropFeaturesController.text,
        });
        _cropNameController.clear();
        _cropImageController.clear();
        _cropFeaturesController.clear();
      });
    }
  }

  
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
                  _buildQuickActions(context, widget.cameras),
                  const SizedBox(height: 20),
                  _buildCropsSection(),     // New crops section
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

  Widget _buildCropsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "🌾 Your Planted Crops", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            TextButton.icon(
              onPressed: () {
                _showAddCropModal();
              },
              icon: const Icon(Icons.add, color: Colors.green),
              label: const Text(
                "Add Crop",
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180, 
          child: _crops.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.grass_outlined, size: 48, color: Colors.green.withOpacity(0.7)),
                      const SizedBox(height: 8),
                      Text(
                        "No crops planted yet", 
                        style: TextStyle(color: Colors.grey[700], fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _crops.length,
                  itemBuilder: (context, index) {
                    return _buildCropCard(
                      _crops[index]["name"], 
                      _crops[index]["image"],
                      _crops[index]["features"],
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddCropModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Add New Crop",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cropNameController,
                decoration: const InputDecoration(
                  labelText: "Crop Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.eco),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cropImageController,
                decoration: const InputDecoration(
                  labelText: "Image URL",
                  border: OutlineInputBorder(),
                  hintText: "Enter a valid image URL",
                  prefixIcon: Icon(Icons.image),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cropFeaturesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Crop Features & Information",
                  border: OutlineInputBorder(),
                  hintText: "Enter details like planting date, expected harvest, variety, etc.",
                  prefixIcon: Icon(Icons.info_outline),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      _addCrop();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("Add Crop"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCropCard(String name, String imageUrl, String features) {
  return SizedBox(
    width: 160,
    height: 180, // Fixed total height
    child: Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showCropDetails(name, imageUrl, features),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section with fixed height
            Container(
              height: 100, // Reduced from original to leave space
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) => const AssetImage('assets/images.png'),
                ),
              ),
            ),
            
            // Content section with flexible space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        onPressed: () => _showCropDetails(name, imageUrl, features),
                        child: const Text(
                          "More info",
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showCropDetails(String name, String imageUrl, String features) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with image
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Crop Information",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: SingleChildScrollView(
                        child: Text(
                          features,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Button
              Padding(
                padding: const EdgeInsets.only(bottom: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildQuickActions(BuildContext context, List<CameraDescription> cameras) {
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
                icon: Icons.lightbulb,label:  "Soil Detection",color:  Colors.yellow[800]!, onTap: () {
                  _navigateToSoilDetection(context, cameras);
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
  );}

void _navigateToSoilDetection(BuildContext context, List<CameraDescription> cameras) async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SoilApp(cameras: cameras,),
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