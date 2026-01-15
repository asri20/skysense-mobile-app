// admin_sensor_logs_delete_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminSensorLogsDeletePage extends StatefulWidget {
  const AdminSensorLogsDeletePage({super.key});

  @override
  State<AdminSensorLogsDeletePage> createState() => _AdminSensorLogsDeletePageState();
}

class _AdminSensorLogsDeletePageState extends State<AdminSensorLogsDeletePage> {
  // ✅ GANTI INI:
  // - Android emulator: http://10.0.2.2:3000
  // - HP fisik: http://IP_LAPTOP_KAMU:3000  (contoh http://192.168.1.10:3000)
  static const String BASE_URL = "http://10.0.2.2:3000";

  final List<_SensorLog> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  int _limit = 30;
  int _offset = 0;
  bool _hasMore = true;

  DateTime? _from;
  DateTime? _to;

  final ScrollController _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);

    _sc.addListener(() {
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 200) {
        if (_hasMore && !_loadingMore && !_loading) {
          _fetchMore();
        }
      }
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  String _fmtDateParam(DateTime d) {
    // Backend kamu pakai "timestamp >= ?" dan "timestamp <= ?"
    // Aman: kirim format "YYYY-MM-DD HH:mm:ss"
    String two(int x) => x.toString().padLeft(2, '0');
    return "${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}";
  }

  Uri _buildListUri({required int limit, required int offset}) {
    final q = <String, String>{
      "limit": "$limit",
      "offset": "$offset",
    };

    if (_from != null) q["dateFrom"] = _fmtDateParam(_from!);
    if (_to != null) q["dateTo"] = _fmtDateParam(_to!);

    return Uri.parse("$BASE_URL/admin/sensor-logs").replace(queryParameters: q);
  }

  Future<void> _fetch({required bool reset}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Token tidak ditemukan. Silakan login admin ulang.";
      });
      return;
    }

    setState(() {
      _error = null;
      if (reset) _loading = true;
    });

    try {
      if (reset) {
        _offset = 0;
        _hasMore = true;
        _items.clear();
      }

      final url = _buildListUri(limit: _limit, offset: _offset);
      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = "Gagal ambil data (HTTP ${res.statusCode})";
        });
        return;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = "Format data tidak valid (bukan list).";
        });
        return;
      }

      final rows = decoded.map((e) => _SensorLog.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        _items.addAll(rows);
        _loading = false;
        _loadingMore = false;

        // kalau hasil kurang dari limit, berarti habis
        if (rows.length < _limit) _hasMore = false;
        _offset = _items.length;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = "Error: $e";
      });
    }
  }

  Future<void> _fetchMore() async {
    if (!_hasMore) return;
    setState(() => _loadingMore = true);
    await _fetch(reset: false);
  }

  Future<void> _deleteLog(_SensorLog log) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      _snack("Token tidak ditemukan. Login ulang.");
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus Log?"),
        content: Text("Yakin mau hapus log ID ${log.id}?\nAksi ini tidak bisa dibatalkan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final url = Uri.parse("$BASE_URL/admin/sensor-logs/${log.id}");
      final res = await http.delete(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        _snack("Gagal hapus (HTTP ${res.statusCode})");
        return;
      }

      setState(() {
        _items.removeWhere((x) => x.id == log.id);
        // biar pagination tetap aman (opsional)
        if (_items.length < _offset) _offset = _items.length;
      });

      _snack("Log ID ${log.id} berhasil dihapus ✅");
    } catch (e) {
      _snack("Error delete: $e");
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickFrom() async {
    final picked = await _pickDateTime(initial: _from ?? DateTime.now().subtract(const Duration(days: 7)));
    if (picked == null) return;
    setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await _pickDateTime(initial: _to ?? DateTime.now());
    if (picked == null) return;
    setState(() => _to = picked);
  }

  Future<DateTime?> _pickDateTime({required DateTime initial}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return DateTime(date.year, date.month, date.day, 0, 0);

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _applyFilter() {
    // validasi sederhana
    if (_from != null && _to != null && _from!.isAfter(_to!)) {
      _snack("Filter salah: dateFrom harus <= dateTo");
      return;
    }
    _fetch(reset: true);
  }

  void _clearFilter() {
    setState(() {
      _from = null;
      _to = null;
    });
    _fetch(reset: true);
  }

  String _prettyDt(DateTime? dt) {
    if (dt == null) return "-";
    String two(int x) => x.toString().padLeft(2, '0');
    return "${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9ECFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Delete Log Sensor",
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: () => _fetch(reset: true),
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
          )
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetch(reset: true),
                        child: ListView.builder(
                          controller: _sc,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: _items.length + 1,
                          itemBuilder: (context, i) {
                            if (i == _items.length) {
                              if (_loadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              }
                              if (!_hasMore) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Center(child: Text("— Data sudah habis —")),
                                );
                              }
                              return const SizedBox(height: 80);
                            }

                            final log = _items[i];
                            return _logTile(log);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Filter Tanggal (opsional)", style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _filterChip(
                  label: _from == null ? "From" : "From: ${_prettyDt(_from)}",
                  icon: Icons.event,
                  onTap: _pickFrom,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _filterChip(
                  label: _to == null ? "To" : "To: ${_prettyDt(_to)}",
                  icon: Icons.event_available,
                  onTap: _pickTo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyFilter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.filter_alt_rounded),
                  label: const Text("Terapkan"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearFilter,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text("Reset"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF6FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logTile(_SensorLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF6FF),
          child: Text(
            "${log.id}",
            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue),
          ),
        ),
        title: Text(
          "Temp ${log.temperature.toStringAsFixed(1)}°C • Hum ${log.humidity.toStringAsFixed(0)}%",
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            "Wind ${log.windSpeed.toStringAsFixed(1)} • Dir ${log.windDirection.toStringAsFixed(0)}° • Light ${log.light.toStringAsFixed(0)}\n"
            "At: ${_prettyDt(log.createdAt)}",
            style: const TextStyle(color: Colors.black54, height: 1.25),
          ),
        ),
        trailing: IconButton(
          tooltip: "Hapus",
          onPressed: () => _deleteLog(log),
          icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
        ),
      ),
    );
  }
}

class _SensorLog {
  final int id;
  final double windSpeed;
  final double temperature;
  final double windDirection;
  final double humidity;
  final double light;
  final DateTime? createdAt;

  _SensorLog({
    required this.id,
    required this.windSpeed,
    required this.temperature,
    required this.windDirection,
    required this.humidity,
    required this.light,
    required this.createdAt,
  });

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    try {
      // mysql biasanya kirim "2026-01-12T..." atau "2026-01-12 12:34:56"
      final s = v.toString().replaceFirst(" ", "T");
      return DateTime.tryParse(s);
    } catch (_) {
      return null;
    }
  }

  factory _SensorLog.fromJson(Map<String, dynamic> j) {
    
    // id, windSpeed, temperature, windDirection, humidity, light, createdAt
    return _SensorLog(
      id: _toInt(j["id"]),
      windSpeed: _toDouble(j["windSpeed"] ?? j["wind_speed"]),
      temperature: _toDouble(j["temperature"]),
      windDirection: _toDouble(j["windDirection"] ?? j["wind_degree"] ?? j["wind_degree"]),
      humidity: _toDouble(j["humidity"]),
      light: _toDouble(j["light"] ?? j["ldr"]),
      createdAt: _parseDt(j["createdAt"] ?? j["timestamp"]),
    );
  }
}
