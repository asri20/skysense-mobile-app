import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/admin_sensor_service.dart';

class AdminSensorDailyPage extends StatefulWidget {
  const AdminSensorDailyPage({super.key});

  @override
  State<AdminSensorDailyPage> createState() => _AdminSensorDailyPageState();
}

class _AdminSensorDailyPageState extends State<AdminSensorDailyPage> {
  final AdminSensorService service = AdminSensorService();

  bool loading = true;
  String? error;

  List<Map<String, dynamic>> rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await service.fetchAvgDaily();
      if (!mounted) return;
      setState(() => rows = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Gagal load avgdata:\n$error", textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text("Coba lagi")),
            ],
          ),
        ),
      );
    }

    double pick(Map<String, dynamic> r, List<String> keys) {
      for (final k in keys) {
        if (r.containsKey(k)) return _num(r[k]);
      }
      return 0;
    }

    final tempSpots = <FlSpot>[];
    final humSpots = <FlSpot>[];
    final windSpots = <FlSpot>[];

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final t = pick(r, ["avg_temperature", "temperature", "avgTemp", "avg_temp"]);
      final h = pick(r, ["avg_humidity", "humidity", "avgHum", "avg_hum"]);
      final w = pick(r, ["avg_wind_speed", "windSpeed", "avgWind", "avg_wind"]);

      tempSpots.add(FlSpot(i.toDouble(), t));
      humSpots.add(FlSpot(i.toDouble(), h));
      windSpots.add(FlSpot(i.toDouble(), w));
    }

    double avgOf(List<FlSpot> s) => s.isEmpty ? 0 : (s.map((e) => e.y).reduce((a, b) => a + b) / s.length);

    final avgT = avgOf(tempSpots);
    final avgH = avgOf(humSpots);
    final avgW = avgOf(windSpots);

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerCard(avgT: avgT, avgH: avgH, avgW: avgW),
            const SizedBox(height: 16),
            const Text("Ringkasan Grafik (Harian)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            _chartCard(title: "Temperature", subtitle: "Rata-rata harian", spots: tempSpots),
            const SizedBox(height: 12),

            _chartCard(title: "Humidity", subtitle: "Rata-rata harian", spots: humSpots),
            const SizedBox(height: 12),

            _chartCard(title: "Wind Speed", subtitle: "Rata-rata harian", spots: windSpots),
            const SizedBox(height: 18),

            const Text("Data (raw) /avgdata", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            ...rows.take(20).map(_rowTile).toList(),
          ],
        ),
      ),
    );
  }

  Widget _headerCard({required double avgT, required double avgH, required double avgW}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          _statPill(icon: Icons.thermostat, label: "Avg Temp", value: "${avgT.toStringAsFixed(1)}°C"),
          const SizedBox(width: 10),
          _statPill(icon: Icons.water_drop, label: "Avg Hum", value: "${avgH.toStringAsFixed(0)}%"),
          const SizedBox(width: 10),
          _statPill(icon: Icons.air, label: "Avg Wind", value: "${avgW.toStringAsFixed(1)}"),
        ],
      ),
    );
  }

  Widget _statPill({required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFD9ECFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required List<FlSpot> spots,
  }) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: true),
                titlesData: FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                    isCurved: true,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowTile(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
      ),
      child: Text(r.toString(), style: const TextStyle(fontSize: 12)),
    );
  }
}
