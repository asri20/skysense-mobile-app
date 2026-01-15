import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OpenWeatherPage extends StatefulWidget {
  final String cityName;
  final double lat;
  final double lon;
  final String apiKey;

  const OpenWeatherPage({
    super.key,
    required this.cityName,
    required this.lat,
    required this.lon,
    required this.apiKey,
  });

  @override
  State<OpenWeatherPage> createState() => _OpenWeatherPageState();
}

class _OpenWeatherPageState extends State<OpenWeatherPage> {
  bool loading = true;
  String? error;

  Map<String, dynamic>? current;
  List<Map<String, dynamic>> hourly = [];
  List<Map<String, dynamic>> daily = [];

  @override
  void initState() {
    super.initState();
    fetchAuto();
  }

  Future<void> fetchAuto() async {
    if (widget.apiKey.trim().isEmpty || widget.apiKey == "PASTE_API_KEY_KAMU") {
      setState(() {
        loading = false;
        error = "API key OpenWeather belum diisi.";
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    // 1) coba OneCall 3.0 dulu
    final okOneCall = await _tryFetchOneCall30();
    if (okOneCall) return;

    // 2) fallback: Current 2.5 + Forecast 2.5
    final okFallback = await _fetchFallback25();
    if (okFallback) return;

    setState(() {
      loading = false;
      error ??= "Gagal ambil data OpenWeather (OneCall & fallback).";
    });
  }

  // =========================
  // TRY: One Call API 3.0
  // =========================
  Future<bool> _tryFetchOneCall30() async {
    final url = Uri.parse(
      "https://api.openweathermap.org/data/3.0/onecall"
      "?lat=${widget.lat}&lon=${widget.lon}"
      "&exclude=minutely,alerts"
      "&units=metric&lang=id"
      "&appid=${widget.apiKey}",
    );

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 12));

      if (res.statusCode == 401 || res.statusCode == 403) {
        // plan belum aktif -> fallback
        setState(() {
          error = "One Call 3.0 tidak tersedia (HTTP ${res.statusCode}). Menggunakan fallback API 2.5.";
        });
        return false;
      }

      if (res.statusCode != 200) {
        setState(() {
          error = "One Call 3.0 error HTTP ${res.statusCode}. Menggunakan fallback...";
        });
        return false;
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final c = json["current"] as Map<String, dynamic>?;
      final h = (json["hourly"] as List?)?.cast<Map>() ?? [];
      final d = (json["daily"] as List?)?.cast<Map>() ?? [];

      setState(() {
        current = c;
        hourly = h.map((e) => Map<String, dynamic>.from(e)).toList();
        daily = d.map((e) => Map<String, dynamic>.from(e)).toList();
        loading = false;
        error = null;
      });

      return true;
    } catch (e) {
      setState(() {
        error = "One Call 3.0 gagal: $e. Menggunakan fallback...";
      });
      return false;
    }
  }

  // =========================
  // FALLBACK: API 2.5
  // - current: /data/2.5/weather
  // - forecast: /data/2.5/forecast (5 hari / 3 jam)
  // =========================
  Future<bool> _fetchFallback25() async {
    try {
      final urlCurrent = Uri.parse(
        "https://api.openweathermap.org/data/2.5/weather"
        "?lat=${widget.lat}&lon=${widget.lon}"
        "&units=metric&lang=id"
        "&appid=${widget.apiKey}",
      );

      final urlForecast = Uri.parse(
        "https://api.openweathermap.org/data/2.5/forecast"
        "?lat=${widget.lat}&lon=${widget.lon}"
        "&units=metric&lang=id"
        "&appid=${widget.apiKey}",
      );

      final resC = await http.get(urlCurrent).timeout(const Duration(seconds: 12));
      if (resC.statusCode != 200) {
        setState(() => error = "Fallback current (2.5) HTTP ${resC.statusCode}");
        return false;
      }

      final resF = await http.get(urlForecast).timeout(const Duration(seconds: 12));
      if (resF.statusCode != 200) {
        setState(() => error = "Fallback forecast (2.5) HTTP ${resF.statusCode}");
        return false;
      }

      final jc = jsonDecode(resC.body) as Map<String, dynamic>;
      final jf = jsonDecode(resF.body) as Map<String, dynamic>;

      // current → bentuk mirip onecall.current
      final main = (jc["main"] as Map?) ?? {};
      final wind = (jc["wind"] as Map?) ?? {};
      final weatherArr = (jc["weather"] as List?) ?? [];
      final w0 = weatherArr.isNotEmpty ? (weatherArr.first as Map<String, dynamic>) : {};

      final nowDt = (jc["dt"] as num?)?.toInt();
      current = {
        "dt": nowDt,
        "temp": (main["temp"] as num?)?.toDouble() ?? 0.0,
        "humidity": (main["humidity"] as num?)?.toInt() ?? 0,
        "wind_speed": (wind["speed"] as num?)?.toDouble() ?? 0.0,
        "weather": [
          {
            "main": w0["main"]?.toString() ?? "-",
            "description": w0["description"]?.toString() ?? "-",
            "icon": w0["icon"]?.toString() ?? "",
          }
        ],
      };

      // hourly dari /forecast (3 jam) ambil 12 item
      final list = (jf["list"] as List?) ?? [];
      hourly = list.take(12).map((e) => Map<String, dynamic>.from(e as Map)).map((e) {
        final dt = (e["dt"] as num?)?.toInt() ?? 0;
        final m = (e["main"] as Map?) ?? {};
        final wArr = (e["weather"] as List?) ?? [];
        final w = wArr.isNotEmpty ? (wArr.first as Map<String, dynamic>) : {};
        return {
          "dt": dt,
          "temp": (m["temp"] as num?)?.toDouble() ?? 0.0,
          "weather": [
            {
              "main": w["main"]?.toString() ?? "-",
              "description": w["description"]?.toString() ?? "-",
              "icon": w["icon"]?.toString() ?? "",
            }
          ],
        };
      }).toList();

      // daily: group per tanggal → ambil min/max
      final byDay = <String, List<Map<String, dynamic>>>{};
      for (final item in list) {
        final m = Map<String, dynamic>.from(item as Map);
        final dt = DateTime.fromMillisecondsSinceEpoch(((m["dt"] as num?)?.toInt() ?? 0) * 1000);
        final key =
            "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
        byDay.putIfAbsent(key, () => []);
        byDay[key]!.add(m);
      }

      final dailyBuilt = <Map<String, dynamic>>[];
      final sortedKeys = byDay.keys.toList()..sort();

      for (final key in sortedKeys.take(7)) {
        final items = byDay[key]!;
        double minT = 9999, maxT = -9999;

        final first = items.first;
        final wArr = (first["weather"] as List?) ?? [];
        final w = wArr.isNotEmpty ? (wArr.first as Map<String, dynamic>) : {};
        final dtUnix = (first["dt"] as num?)?.toInt() ?? 0;

        for (final it in items) {
          final mm = (it["main"] as Map?) ?? {};
          final t = (mm["temp"] as num?)?.toDouble();
          if (t != null) {
            if (t < minT) minT = t;
            if (t > maxT) maxT = t;
          }
        }

        if (minT == 9999) minT = 0;
        if (maxT == -9999) maxT = 0;

        dailyBuilt.add({
          "dt": dtUnix,
          "temp": {"min": minT, "max": maxT},
          "weather": [
            {
              "main": w["main"]?.toString() ?? "-",
              "description": w["description"]?.toString() ?? "-",
              "icon": w["icon"]?.toString() ?? "",
            }
          ],
        });
      }

      setState(() {
        daily = dailyBuilt;
        loading = false;
        // kalau sukses, error jangan bikin UI “jelek”
        error = null;
      });

      return true;
    } catch (e) {
      setState(() => error = "Fallback 2.5 gagal: $e");
      return false;
    }
  }

  String _weekday(int weekday) {
    const days = ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"];
    return days[(weekday - 1) % 7];
  }

  String _hh(int unix) {
    final dt = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
    return "${dt.hour.toString().padLeft(2, '0')}:00";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9ECFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "OpenWeather • ${widget.cityName}",
          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            onPressed: loading ? null : fetchAuto,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            tooltip: "Refresh",
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (current == null && error != null)
              ? Center(child: Text(error!, style: const TextStyle(color: Colors.redAccent)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (error != null) ...[
                        _infoBanner(error!),
                        const SizedBox(height: 12),
                      ],
                      _currentCard(),
                      const SizedBox(height: 16),
                      const Text("Hourly (12 Jam)",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      _hourlyList(),
                      const SizedBox(height: 16),
                      const Text("Daily (7 Hari)",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      _dailyList(),
                      const SizedBox(height: 16),
                      _apiInfoCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _infoBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2CC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6D6A8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.black87),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black87, height: 1.2)),
          ),
        ],
      ),
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: child,
    );
  }

  Widget _currentCard() {
    final c = current ?? {};
    final temp = (c["temp"] as num?)?.toDouble() ?? 0.0;
    final hum = (c["humidity"] as num?)?.toInt() ?? 0;
    final wind = (c["wind_speed"] as num?)?.toDouble() ?? 0.0;

    final weatherArr = (c["weather"] as List?) ?? [];
    final w0 = weatherArr.isNotEmpty ? (weatherArr.first as Map<String, dynamic>) : {};
    final desc = (w0["description"]?.toString() ?? "-");
    final icon = (w0["icon"]?.toString() ?? "");

    return _cardShell(
      child: Row(
        children: [
          _owIcon(icon, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${temp.toStringAsFixed(1)}°C",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip("Humidity: $hum%"),
                    _chip("Wind: ${wind.toStringAsFixed(1)} m/s"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hourlyList() {
    final take = hourly.take(12).toList();

    // FIX OVERFLOW: tinggi list ditambah + padding kartu diperkecil
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: take.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final h = take[i];
          final dtUnix = (h["dt"] as num?)?.toInt() ?? 0;
          final temp = (h["temp"] as num?)?.toDouble() ?? 0.0;

          final weatherArr = (h["weather"] as List?) ?? [];
          final w0 = weatherArr.isNotEmpty ? (weatherArr.first as Map<String, dynamic>) : {};
          final icon = (w0["icon"]?.toString() ?? "");

          return Container(
            width: 92,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_hh(dtUnix), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _owIcon(icon, size: 34),
                const SizedBox(height: 6),
                Text("${temp.toStringAsFixed(0)}°",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dailyList() {
    final take = daily.take(7).toList();
    return Column(
      children: take.map((day) {
        final dt = DateTime.fromMillisecondsSinceEpoch(((day["dt"] as num?)?.toInt() ?? 0) * 1000);
        final temp = (day["temp"] as Map?) ?? {};
        final minT = (temp["min"] as num?)?.toDouble() ?? 0.0;
        final maxT = (temp["max"] as num?)?.toDouble() ?? 0.0;

        final weatherArr = (day["weather"] as List?) ?? [];
        final w0 = weatherArr.isNotEmpty ? (weatherArr.first as Map<String, dynamic>) : {};
        final desc = (w0["main"]?.toString() ?? "-");
        final icon = (w0["icon"]?.toString() ?? "");

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(_weekday(dt.weekday),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              _owIcon(icon, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(desc, style: const TextStyle(color: Colors.black54)),
              ),
              Text("${maxT.toStringAsFixed(0)}° / ${minT.toStringAsFixed(0)}°",
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _owIcon(String icon, {double size = 32}) {
    if (icon.isEmpty) return Icon(Icons.cloud, size: size, color: Colors.black54);
    return Image.network(
      "https://openweathermap.org/img/wn/$icon.png",
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => Icon(Icons.cloud, size: size, color: Colors.black54),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _apiInfoCard() {
    return _cardShell(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Catatan UAS (API Public)", style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text(
            "Halaman ini mengambil data dari OpenWeather.\n"
            "Mode utama: One Call API 3.0.\n"
            "Jika One Call belum aktif (401/403), otomatis fallback ke Current Weather + 5 Day/3 Hour Forecast (API 2.5).",
            style: TextStyle(color: Colors.black87, height: 1.3),
          ),
        ],
      ),
    );
  }
}
