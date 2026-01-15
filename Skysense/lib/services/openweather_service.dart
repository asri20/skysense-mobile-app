import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenWeatherService {
  // Ganti dengan API key kamu
  static const String apiKey = "ISI_API_KEY_KAMU";

  // Ambil cuaca current by city (Bandung)
  Future<Map<String, dynamic>> fetchCurrentByCity(String city) async {
    final uri = Uri.parse(
      "https://api.openweathermap.org/data/2.5/weather"
      "?q=$city"
      "&appid=$apiKey"
      "&units=metric"
      "&lang=id",
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw "OpenWeather error (${res.statusCode}): ${res.body}";
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Forecast 5 hari / 3 jam
  Future<Map<String, dynamic>> fetchForecastByCity(String city) async {
    final uri = Uri.parse(
      "https://api.openweathermap.org/data/2.5/forecast"
      "?q=$city"
      "&appid=$apiKey"
      "&units=metric"
      "&lang=id",
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw "OpenWeather error (${res.statusCode}): ${res.body}";
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
