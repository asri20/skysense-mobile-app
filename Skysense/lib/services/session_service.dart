import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static Future<void> saveLogin({
    required String token,
    required String role,
    required String status,
    required String email,
    String? name,
    int? id,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", token);
    await prefs.setString("role", role);
    await prefs.setString("status", status);
    await prefs.setString("email", email);
    if (name != null) await prefs.setString("name", name);
    if (id != null) await prefs.setInt("id", id);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("role");
    await prefs.remove("status");
    await prefs.remove("email");
    await prefs.remove("name");
    await prefs.remove("id");
  }
}
