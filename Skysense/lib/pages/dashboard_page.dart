import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_application_skysense/services/mqtt_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/chat_service.dart'; 
import 'chat_room_page.dart'; 

import 'live_video_page.dart';
import 'data_historis_page.dart';
import 'login_page.dart';
import 'about_page.dart';
import 'openweather_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ======================
  // MQTT SENSOR
  // ======================
  double temperature = 0.0;
  double humidity = 0.0;
  double windSpeed = 0.0;
  double rainChance = 0.0; // rainRate (mm/hr)
  double windDirection = 0.0; // derajat
  double light = 0.0;

  final List<FlSpot> temperatureData = [];
  int _selectedIndex = 0;
  final MqttService mqttService = MqttService();

  // ======================
  // CHAT
  // ======================
  final ChatService chat = ChatService();
  bool _chatLoading = false;

  // ======================
  // OPENWEATHER
  // ======================
  static const double _cityLat = -6.9175;
  static const double _cityLon = 107.6191;
  static const String _cityName = "Bandung";

  static const String OPEN_WEATHER_API_KEY = "d1dae3b1714863b8b136f9445315e0e5";

  bool _owLoading = false;
  String? _owError;
  _OpenWeatherCurrent? _owCurrent;

  @override
  void initState() {
    super.initState();

    mqttService.onMessage = (data) {
      if (!mounted) return;

      setState(() {
        temperature = (data['temperature'] as num?)?.toDouble() ?? temperature;
        humidity = (data['humidity'] as num?)?.toDouble() ?? humidity;
        windSpeed = (data['windSpeed'] as num?)?.toDouble() ?? windSpeed;
        windDirection = (data['windDirection'] as num?)?.toDouble() ?? windDirection;
        rainChance = (data['rainRate'] as num?)?.toDouble() ?? rainChance;
        light = (data['light'] as num?)?.toDouble() ?? light;

        final x = temperatureData.length.toDouble();
        temperatureData.add(FlSpot(x, temperature));
        if (temperatureData.length > 20) {
          temperatureData.removeAt(0);
          for (int i = 0; i < temperatureData.length; i++) {
            temperatureData[i] = FlSpot(i.toDouble(), temperatureData[i].y);
          }
        }
      });
    };

    mqttService.connect();
    _fetchOpenWeatherCurrent();
  }

  @override
  void dispose() {
    mqttService.disconnect();
    super.dispose();
  }

  Future<void> _logout() async {
    mqttService.disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ============================================================
  // ✅ BUTTON CHAT: client langsung ke room (auto create thread)
  // ============================================================
  Future<void> _openChatClient() async {
    if (_chatLoading) return;

    setState(() => _chatLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) throw "Token tidak ada. Login ulang.";

      // backend: GET /chat/thread -> {threadId, admin}
      final res = await chat.getClientThread(token: token);
      final threadId = (res["threadId"] as num).toInt();

      final admin = (res["admin"] as Map).cast<String, dynamic>();
      final adminId = (admin["id"] as num).toInt();
      final adminName = (admin["name"] ?? "Admin").toString();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            threadId: threadId,
            otherUserId: adminId,
            title: adminName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal buka chat: $e")),
      );
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  // ============================================================
  // ✅ OpenWeather current
  // ============================================================
  Future<void> _fetchOpenWeatherCurrent() async {
    if (OPEN_WEATHER_API_KEY.trim().isEmpty || OPEN_WEATHER_API_KEY == "PASTE_API_KEY_KAMU") {
      setState(() {
        _owError = "API key OpenWeather belum diisi.";
        _owCurrent = null;
      });
      return;
    }

    setState(() {
      _owLoading = true;
      _owError = null;
    });

    final url = Uri.parse(
      "https://api.openweathermap.org/data/2.5/weather"
      "?lat=$_cityLat&lon=$_cityLon"
      "&units=metric&lang=id"
      "&appid=$OPEN_WEATHER_API_KEY",
    );

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        setState(() {
          _owError = "OpenWeather error: HTTP ${res.statusCode}";
          _owCurrent = null;
          _owLoading = false;
        });
        return;
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final main = (json["main"] as Map?) ?? {};
      final wind = (json["wind"] as Map?) ?? {};
      final weatherArr = (json["weather"] as List?) ?? [];
      final w0 = weatherArr.isNotEmpty ? (weatherArr.first as Map<String, dynamic>) : {};

      setState(() {
        _owCurrent = _OpenWeatherCurrent(
          tempC: (main["temp"] as num?)?.toDouble() ?? 0.0,
          humidity: (main["humidity"] as num?)?.toDouble() ?? 0.0,
          windMs: (wind["speed"] as num?)?.toDouble() ?? 0.0,
          description: w0["description"]?.toString() ?? "-",
          icon: w0["icon"]?.toString(),
          dt: (json["dt"] as num?)?.toInt(),
        );
        _owLoading = false;
      });
    } catch (e) {
      setState(() {
        _owError = "Gagal fetch OpenWeather: $e";
        _owCurrent = null;
        _owLoading = false;
      });
    }
  }

  String getWindDirectionText(double degree) {
    if (degree >= 337.5 || degree < 22.5) return "Utara";
    if (degree >= 22.5 && degree < 67.5) return "Timur Laut";
    if (degree >= 67.5 && degree < 112.5) return "Timur";
    if (degree >= 112.5 && degree < 157.5) return "Tenggara";
    if (degree >= 157.5 && degree < 202.5) return "Selatan";
    if (degree >= 202.5 && degree < 247.5) return "Barat Daya";
    if (degree >= 247.5 && degree < 292.5) return "Barat";
    return "Barat Laut";
  }

  // ============================================================
  // ✅ FITUR A: Perhitungan irigasi
  // ============================================================
  double _clamp(double v, double min, double max) {
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }

  double calcIrrigationIndex({
    required double tempC,
    required double humidityPct,
    required double windKmh,
    required double lightWm2,
    required double rainRateMmHr,
  }) {
    final t = _clamp(tempC, 0, 45) / 45.0;
    final h = _clamp(humidityPct, 0, 100) / 100.0;
    final w = _clamp(windKmh, 0, 40) / 40.0;
    final l = _clamp(lightWm2, 0, 1200) / 1200.0;
    final r = _clamp(rainRateMmHr, 0, 50) / 50.0;

    final score01 = (0.42 * t) + (0.20 * w) + (0.18 * l) + (0.20 * (1 - h)) - (0.30 * r);
    return _clamp(score01 * 100.0, 0, 100);
  }

  String irrigationLabel(double idx) {
    if (idx >= 70) return "HIGH";
    if (idx >= 40) return "MEDIUM";
    return "LOW";
  }

  double irrigationLitersPerM2(double idx) {
    if (idx >= 70) return 6.0;
    if (idx >= 40) return 3.5;
    return 1.5;
  }

  List<String> getFarmingActivities(String weather) {
    switch (weather) {
      case "Rainy":
        return [
          "Perbaikan drainase lahan",
          "Penundaan penanaman sayuran sensitif",
          "Pengendalian penyakit jamur",
          "Penguatan bedengan",
        ];
      case "Cloudy":
        return [
          "Penanaman sayuran daun",
          "Pemupukan organik",
          "Monitoring kelembapan tanah",
          "Penyulaman tanaman",
        ];
      case "Sunny":
        return [
          "Penanaman sayuran umbi",
          "Irigasi terkontrol",
          "Pemupukan bertahap",
          "Pengendalian hama daun",
        ];
      default:
        return ["Monitoring kondisi lahan"];
    }
  }

  List<Map<String, dynamic>> getMonthlyPrediction() {
    final months = ["January", "February", "March", "April", "May", "June", "July"];
    final rainPattern = [140, 120, 90, 70, 50, 40, 35];
    final tempPattern = [22, 23, 24, 24, 25, 26, 26];

    return List.generate(months.length, (i) {
      final rain = rainPattern[i];
      final temp = tempPattern[i];

      String weather;
      IconData icon;

      if (rain > 110) {
        weather = "Rainy";
        icon = Icons.grain;
      } else if (rain < 60 && temp >= 25) {
        weather = "Sunny";
        icon = Icons.wb_sunny;
      } else {
        weather = "Cloudy";
        icon = Icons.cloud;
      }

      return {
        "month": months[i],
        "weather": weather,
        "temp": "${temp}°",
        "icon": icon,
        "activities": getFarmingActivities(weather),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthlyData = getMonthlyPrediction();

    final irrigationIdx = calcIrrigationIndex(
      tempC: temperature,
      humidityPct: humidity,
      windKmh: windSpeed,
      lightWm2: light,
      rainRateMmHr: rainChance,
    );
    final irrLabel = irrigationLabel(irrigationIdx);
    final irrLiters = irrigationLitersPerM2(irrigationIdx);

    return Scaffold(
      backgroundColor: const Color(0xFFD9ECFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "SkySense",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
        ),
        actions: [
          // ✅ CHAT BUTTON
          IconButton(
            tooltip: "Chat Admin",
            icon: _chatLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chat_bubble_outline_rounded, color: Colors.black87),
            onPressed: _chatLoading ? null : _openChatClient,
          ),

          // OpenWeather
          IconButton(
            tooltip: "OpenWeather (API Public)",
            icon: const Icon(Icons.cloud_outlined, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OpenWeatherPage(
                    cityName: _cityName,
                    lat: _cityLat,
                    lon: _cityLon,
                    apiKey: OPEN_WEATHER_API_KEY,
                  ),
                ),
              );
            },
          ),

          // About
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
            icon: const Icon(Icons.info_outline_rounded, color: Colors.black87),
            tooltip: "About",
          ),

          // Logout
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.black87),
            tooltip: "Logout",
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LOCATION
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      "Bandung",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text("Realtime Weather Monitoring", style: TextStyle(color: Colors.grey)),

              const SizedBox(height: 14),
              _openWeatherPreviewCard(),

              const SizedBox(height: 20),

              // REALTIME SENSOR GRID
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
                children: [
                  _sensorBox(Icons.water_drop, "Rainfall",
                      rainChance.isFinite ? rainChance.toStringAsFixed(1) : "0.0",
                      const Color.fromARGB(255, 87, 127, 167), Colors.white),
                  _sensorBox(Icons.thermostat, "Temperature", "${temperature.toStringAsFixed(1)}°C",
                      const Color(0xFFE74C3C), Colors.white),
                  _sensorBox(Icons.air, "Wind Speed", "${windSpeed.toStringAsFixed(1)} km/h",
                      const Color(0xFF1ABC9C), const Color.fromARGB(255, 8, 10, 12)),
                  _sensorBox(Icons.navigation, "Wind Direction", getWindDirectionText(windDirection),
                      const Color(0xFF3498DB), Colors.white),
                  _sensorBox(Icons.water, "Humidity", "${humidity.toStringAsFixed(0)}%",
                      const Color(0xFFBDC3C7), const Color.fromARGB(255, 8, 10, 12)),
                  _sensorBox(Icons.wb_sunny, "Light Intensity", "${light.toStringAsFixed(0)} W/m²",
                      const Color(0xFFF39C12), const Color.fromARGB(255, 8, 10, 12)),
                ],
              ),

              const SizedBox(height: 18),

              _calcCard(
                title: "Perhitungan Kebutuhan Irigasi",
                subtitle: "Indeks Kebutuhan Irigasi (0–100)",
                index: irrigationIdx,
                label: irrLabel,
                litersPerM2: irrLiters,
              ),

              const SizedBox(height: 20),
              const Text("Grafik Perubahan Suhu (Today)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              Container(
                height: 280,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: true),
                    titlesData: FlTitlesData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: temperatureData.isEmpty ? const [FlSpot(0, 0)] : temperatureData,
                        isCurved: true,
                        color: Colors.red,
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),
              const Text("Hari Ini", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    HourCard("Now", "22°", Icons.wb_sunny),
                    HourCard("13:00", "23°", Icons.wb_sunny),
                    HourCard("16:00", "21°", Icons.cloud),
                    HourCard("19:00", "19°", Icons.cloud),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text("Perkiraan 7 Hari", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _dayForecast("Senin", "22° / 18°", Icons.wb_sunny),
              _dayForecast("Selasa", "21° / 17°", Icons.cloud),
              _dayForecast("Rabu", "20° / 16°", Icons.cloud_queue),
              _dayForecast("Kamis", "23° / 18°", Icons.wb_sunny),

              const SizedBox(height: 28),
              const Text("Perkiraan Bulanan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              GridView.builder(
                itemCount: monthlyData.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemBuilder: (context, index) {
                  final data = monthlyData[index];
                  return PredictionCard(
                    data["month"],
                    data["weather"],
                    data["temp"],
                    data["icon"],
                    activities: data["activities"],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
            if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveVideoPage()));
            if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => const DataHistorisPage()));
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: "Dashboard"),
            BottomNavigationBarItem(icon: Icon(Icons.videocam_rounded), label: "Live"),
            BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: "History"),
          ],
        ),
      ),
    );
  }

  // ======================
  // OpenWeather preview card
  // ======================
  Widget _openWeatherPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "OpenWeatherMap (API Public)",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: "Refresh",
                    onPressed: _owLoading ? null : _fetchOpenWeatherCurrent,
                    icon: _owLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_owError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEAEA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFC0C0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_owError!, style: const TextStyle(color: Colors.redAccent, height: 1.2)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_owError == null && _owCurrent == null && !_owLoading)
                    const Text("Belum ada data. Tekan refresh untuk ambil data.", style: TextStyle(color: Colors.black54)),
                  if (_owCurrent != null) ...[
                    Row(
                      children: [
                        _owIcon(_owCurrent!.icon),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("$_cityName • ${_owCurrent!.tempC.toStringAsFixed(1)}°C",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text(_owCurrent!.description, style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _miniChip("Humidity: ${_owCurrent!.humidity.toStringAsFixed(0)}%"),
                        _miniChip("Wind: ${_owCurrent!.windMs.toStringAsFixed(1)} m/s"),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F80ED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text("Detail OpenWeather"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OpenWeatherPage(
                              cityName: _cityName,
                              lat: _cityLat,
                              lon: _cityLon,
                              apiKey: OPEN_WEATHER_API_KEY,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _owIcon(String? icon) {
    final ic = icon ?? "";
    if (ic.isEmpty) return const Icon(Icons.cloud, size: 40, color: Colors.black54);
    return Image.network(
      "https://openweathermap.org/img/wn/$ic@2x.png",
      width: 44,
      height: 44,
      errorBuilder: (_, __, ___) => const Icon(Icons.cloud, size: 40, color: Colors.black54),
    );
  }

  Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _calcCard({
    required String title,
    required String subtitle,
    required double index,
    required String label,
    required double litersPerM2,
  }) {
    final color = label == "HIGH"
        ? const Color(0xFFFFE1E1)
        : (label == "MEDIUM" ? const Color(0xFFFFF2CC) : const Color(0xFFDFF7E2));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Index: ${index.toStringAsFixed(0)} / 100\nLevel: $label",
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Text("${litersPerM2.toStringAsFixed(1)} L/m²",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text("Simulasi perhitungan untuk analisis kebutuhan irigasi.",
              style: TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _sensorBox(IconData icon, String label, String value, Color bgColor, Color iconColor) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 45, color: iconColor),
          const SizedBox(height: 14),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _dayForecast(String day, String temp, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
          Icon(icon, color: Colors.grey.shade600),
          Text(temp),
        ],
      ),
    );
  }
}

// ==========================
// Model OpenWeather
// ==========================
class _OpenWeatherCurrent {
  final double tempC;
  final double humidity;
  final double windMs;
  final String description;
  final String? icon;
  final int? dt;

  _OpenWeatherCurrent({
    required this.tempC,
    required this.humidity,
    required this.windMs,
    required this.description,
    this.icon,
    this.dt,
  });
}

// ==========================
// Widgets bawaan kamu
// ==========================
class HourCard extends StatelessWidget {
  final String time;
  final String temp;
  final IconData icon;

  const HourCard(this.time, this.temp, this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(time),
          const SizedBox(height: 8),
          Icon(icon, color: Colors.orange),
          const SizedBox(height: 8),
          Text(temp, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class PredictionCard extends StatelessWidget {
  final String month;
  final String condition;
  final String temp;
  final IconData icon;
  final List<String> activities;

  const PredictionCard(
    this.month,
    this.condition,
    this.temp,
    this.icon, {
    required this.activities,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(month, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Icon(icon, color: Colors.blue, size: 28),
          const SizedBox(height: 6),
          Text(condition, style: const TextStyle(fontSize: 13)),
          Text(temp, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Divider(),
          const Text("Kegiatan:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...activities.take(2).map((e) => Text("• $e", style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}

class TrendRow extends StatelessWidget {
  final String label;
  final String value;

  const TrendRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
