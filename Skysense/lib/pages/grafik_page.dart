import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class GrafikPage extends StatelessWidget {
  const GrafikPage({super.key});

  @override
  Widget build(BuildContext context) {
    // === DATA PRAKIRAAN DINAMIS (bisa kamu ubah) ===
    final List<Map<String, dynamic>> forecastData = [
      {"time": "09.00", "temp": 22},
      {"time": "12.00", "temp": 26},
      {"time": "15.00", "temp": 23},
      {"time": "18.00", "temp": 20},
    ];

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text("Grafik Data Cuaca"),
        backgroundColor: Colors.lightBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Grafik Perubahan Suhu",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // === LINE CHART DINAMIS ===
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              height: 280,
              child: LineChart(
                LineChartData(
                  minY: _minTemp(forecastData) - 2,
                  maxY: _maxTemp(forecastData) + 2,
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),

                  /// =============================
                  /// === TITLES (WAKTU & SUHU) ===
                  /// =============================
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < forecastData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                forecastData[value.toInt()]["time"],
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            "${value.toInt()}°",
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),

                  /// =============================
                  /// === GARIS DATA DINAMIS ======
                  /// =============================
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      spots: List.generate(
                        forecastData.length,
                        (i) => FlSpot(
                          i.toDouble(),
                          forecastData[i]["temp"].toDouble(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Prakiraan Cuaca",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // CARD PRAKIRAAN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: forecastData.map((data) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  width: 85,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        data["time"],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(Icons.wb_sunny, size: 30),
                      const SizedBox(height: 8),
                      Text(
                        "${data["temp"]}°C",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Helper buat auto-scale grafik
  double _minTemp(List<Map<String, dynamic>> data) => data
      .map((e) => e["temp"] as int)
      .reduce((a, b) => a < b ? a : b)
      .toDouble();

  double _maxTemp(List<Map<String, dynamic>> data) => data
      .map((e) => e["temp"] as int)
      .reduce((a, b) => a > b ? a : b)
      .toDouble();
}
