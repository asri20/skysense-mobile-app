import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isConnected = false;

  void _toggleConnection() {
    setState(() {
      isConnected = !isConnected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SkySense Dashboard"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // 🔘 Button Connect / Disconnect
          ElevatedButton.icon(
            onPressed: _toggleConnection,
            icon: Icon(isConnected ? Icons.link_off : Icons.link),
            label: Text(isConnected ? "Disconnect" : "Connect"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              backgroundColor: isConnected ? Colors.red : Colors.green,
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),

          const SizedBox(height: 30),

          // Kalau belum connect → tampil pesan info
          if (!isConnected)
            const Text(
              "Klik tombol Connect untuk mulai monitoring data.",
              style: TextStyle(fontSize: 16),
            ),

          // Kalau sudah connect → tampil dashboard Grid
          if (isConnected)
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildDataCard("Rainfall", "-- mm", Icons.invert_colors),
                  _buildDataCard("Temperature", "-- °C", Icons.thermostat),
                  _buildDataCard("Wind Speed", "-- km/h", Icons.air),
                  _buildDataCard("Wind Direction", "--", Icons.explore),
                  _buildDataCard("Humidity", "-- %", Icons.water_drop),
                  _buildDataCard("Light Intensity", "-- lux", Icons.wb_sunny),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: Colors.blue),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
