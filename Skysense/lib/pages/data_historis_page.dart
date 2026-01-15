import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_config.dart';

class DataHistorisPage extends StatefulWidget {
  const DataHistorisPage({super.key});

  @override
  State<DataHistorisPage> createState() => _DataHistorisPageState();
}

class _DataHistorisPageState extends State<DataHistorisPage> {
  late Future<List<HistorisRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchDataHistoris();
  }

  Future<List<HistorisRow>> fetchDataHistoris() async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/avgdata");
    final res = await http.get(uri).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw "Gagal ambil data historis (${res.statusCode})";
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List) throw "Format avgdata tidak valid (bukan List)";

    return decoded.map<HistorisRow>((item) {
      final m = (item as Map).cast<String, dynamic>();

      final tanggalRaw = (m["tanggal"] ?? "").toString();
      final tanggal = _formatTanggal(tanggalRaw);

      final avgTemp = _toDouble(m["avg_temperature"]);
      final avgHum = _toDouble(m["avg_humidity"]);
      final avgLdr = _toDouble(m["avg_ldr"]);
      final avgWind = _toDouble(m["avg_wind_speed"]);

      final kondisi = _predictCondition(
        temp: avgTemp,
        humidity: avgHum,
        ldr: avgLdr,
        wind: avgWind,
      );

      return HistorisRow(
        tanggal: tanggal,
        suhu: avgTemp,
        kelembapan: avgHum,
        ldr: avgLdr,
        wind: avgWind,
        kondisi: kondisi,
      );
    }).toList();
  }

  // ===== Helpers =====
  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static String _formatTanggal(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return "$y-$m-$d";
    } catch (_) {
      return raw.isEmpty ? "-" : raw;
    }
  }

  // ✅ Perhitungan sederhana (UTS-friendly)
  static String _predictCondition({
    required double temp,
    required double humidity,
    required double ldr,
    required double wind,
  }) {
    final isHot = temp >= 28;
    final isHumid = humidity >= 80;
    final isBright = ldr >= 600;
    final isWindy = wind >= 8;

    if (isBright && isHot && !isHumid) return "Cerah";
    if (isHumid && !isBright) return "Hujan";
    if (isWindy && !isBright) return "Berawan";
    return "Rata-rata";
  }

  IconData getWeatherIcon(String kondisi) {
    switch (kondisi) {
      case "Cerah":
        return Icons.wb_sunny_rounded;
      case "Berawan":
        return Icons.cloud_rounded;
      case "Hujan":
        return Icons.umbrella_rounded;
      case "Rata-rata":
        return Icons.analytics_rounded;
      default:
        return Icons.help_outline;
    }
  }

  Color getWeatherColor(String kondisi) {
    switch (kondisi) {
      case "Cerah":
        return const Color(0xFFFFF3C4);
      case "Berawan":
        return const Color(0xFFE3F2FD);
      case "Hujan":
        return const Color(0xFFE1F5FE);
      case "Rata-rata":
        return const Color(0xFFE8F5E9);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5BAAF4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "SKYSENSE • Data Historis",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<HistorisRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("❌ Error:\n${snap.error}", textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _future = fetchDataHistoris()),
                      child: const Text("Coba lagi"),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snap.data ?? [];

          if (data.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inbox_rounded, size: 44, color: Colors.black54),
                    const SizedBox(height: 10),
                    const Text(
                      "Belum ada data historis.\nIsi dulu data_sensor atau tunggu alat kirim data.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _future = fetchDataHistoris()),
                      child: const Text("Refresh"),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = fetchDataHistoris());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  "Riwayat Cuaca Harian",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Data dari /avgdata (DB). Dipakai untuk analisis dan prediksi cuaca pertanian.",
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                ...data.map(_card).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(HistorisRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getWeatherColor(row.kondisi),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(row.tanggal, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  Icon(getWeatherIcon(row.kondisi), size: 22),
                  const SizedBox(width: 6),
                  Text(row.kondisi, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoItem(Icons.thermostat, "Suhu", "${row.suhu.toStringAsFixed(1)}°C"),
              _infoItem(Icons.water_drop, "Hum", "${row.kelembapan.toStringAsFixed(0)}%"),
              _infoItem(Icons.wb_sunny, "LDR", row.ldr.toStringAsFixed(0)),
              _infoItem(Icons.air, "Wind", row.wind.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _infoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueGrey),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

class HistorisRow {
  final String tanggal;
  final double suhu;
  final double kelembapan;
  final double ldr;
  final double wind;
  final String kondisi;

  HistorisRow({
    required this.tanggal,
    required this.suhu,
    required this.kelembapan,
    required this.ldr,
    required this.wind,
    required this.kondisi,
  });
}
