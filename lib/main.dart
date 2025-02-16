import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(FarmersApp());
}

class FarmersApp extends StatelessWidget {
  const FarmersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmers App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        textTheme: GoogleFonts.latoTextTheme(),
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmers Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weather Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Weather", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("🌤️  28°C  |  Clear Sky", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  Icon(Icons.wb_sunny, size: 40, color: Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Action Buttons
            const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAction(Icons.shopping_cart, "Market Prices"),
                _buildQuickAction(Icons.cloud, "Weather"),
                _buildQuickAction(Icons.lightbulb, "Farming Advice"),
              ],
            ),
          ],
        ),
      ),

      // Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_basket), label: "Market"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  // Function to create Quick Action Buttons
  Widget _buildQuickAction(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.green[200],
          child: Icon(icon, size: 30, color: Colors.green[800]),
        ),
        const SizedBox(height: 5),
        Text(label, textAlign: TextAlign.center),
      ],
    );
  }
}
