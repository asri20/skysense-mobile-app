import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class AuthService {
  // ===================== AUTH =====================
  Future<Map<String, dynamic>> login(String email, String password) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/auth/login");

    final res = await http
        .post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"email": email, "password": password}),
        )
        .timeout(const Duration(seconds: 12));

    final body = _safeJson(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (body["error"] ?? body["message"] ?? "Login gagal").toString();
      throw msg;
    }

    if (body["token"] == null || body["user"] == null) {
      throw "Response login tidak lengkap (token/user null)";
    }

    return body;
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/auth/register");

    final res = await http
        .post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"name": name, "email": email, "password": password}),
        )
        .timeout(const Duration(seconds: 12));

    final body = _safeJson(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (body["error"] ?? body["message"] ?? "Register gagal").toString();
      throw msg;
    }

    return body;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ===================== ADMIN: LIST USERS =====================
  // GET /admin/users?status=&role=
  Future<List<Map<String, dynamic>>> fetchUsers({
    required String token,
    String? status, // pending/approved/blocked/null
    String? role, // client/admin/null
  }) async {
    final qp = <String, String>{};
    if (status != null && status.isNotEmpty && status != "all") qp["status"] = status;
    if (role != null && role.isNotEmpty && role != "all") qp["role"] = role;

    final uri = Uri.parse("${ApiConfig.baseUrl}/admin/users")
        .replace(queryParameters: qp.isEmpty ? null : qp);

    final res = await http
        .get(uri, headers: {"Authorization": "Bearer $token"})
        .timeout(const Duration(seconds: 12));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = _safeJson(res.body);
      throw (body["error"] ?? body["message"] ?? "Gagal ambil users").toString();
    }

    final decoded = jsonDecode(res.body);
    if (decoded is List) {
      return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  // ===================== ADMIN: CREATE USER =====================
  // POST /admin/users
  Future<Map<String, dynamic>> adminCreateUser({
    required String token,
    required String name,
    required String email,
    required String password,
    String role = "client",
    String status = "approved",
  }) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/admin/users");

    final res = await http
        .post(
          uri,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            "name": name,
            "email": email,
            "password": password,
            "role": role,
            "status": status,
          }),
        )
        .timeout(const Duration(seconds: 12));

    final body = _safeJson(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw (body["error"] ?? body["message"] ?? "Gagal membuat user").toString();
    }

    return body;
  }

  // ===================== ADMIN: UPDATE USER =====================
  // PATCH /admin/users/:id
  Future<Map<String, dynamic>> adminUpdateUser({
    required String token,
    required int userId,
    String? name,
    String? email,
    String? password, // optional
    String? role,
    String? status,
  }) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/admin/users/$userId");

    final payload = <String, dynamic>{};
    if (name != null) payload["name"] = name;
    if (email != null) payload["email"] = email;
    if (role != null) payload["role"] = role;
    if (status != null) payload["status"] = status;
    if (password != null && password.trim().isNotEmpty) payload["password"] = password;

    final res = await http
        .patch(
          uri,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));

    final body = _safeJson(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw (body["error"] ?? body["message"] ?? "Gagal update user").toString();
    }

    return body;
  }

  // ===================== ADMIN: DELETE USER =====================
  // DELETE /admin/users/:id
  Future<Map<String, dynamic>> adminDeleteUser({
    required String token,
    required int userId,
  }) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/admin/users/$userId");

    final res = await http
        .delete(uri, headers: {"Authorization": "Bearer $token"})
        .timeout(const Duration(seconds: 12));

    final body = _safeJson(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw (body["error"] ?? body["message"] ?? "Gagal hapus user").toString();
    }

    return body;
  }

  // ===================== ADMIN: UPDATE STATUS (kalau masih mau dipakai) =====================
  Future<Map<String, dynamic>> setUserStatus({
    required String token,
    required int userId,
    required String status,
  }) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/admin/users/$userId/status");

    final res = await http
        .patch(
          uri,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({"status": status}),
        )
        .timeout(const Duration(seconds: 12));

    final body = _safeJson(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw (body["error"] ?? body["message"] ?? "Gagal update status").toString();
    }

    return body;
  }

  // ===================== ADMIN: SENSOR DAILY =====================
  Future<List<Map<String, dynamic>>> fetchAvgData() async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/avgdata");

    final res = await http.get(uri).timeout(const Duration(seconds: 12));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = _safeJson(res.body);
      throw (body["error"] ?? body["message"] ?? "Gagal ambil avgdata").toString();
    }

    final decoded = jsonDecode(res.body);
    if (decoded is List) {
      return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  // ===================== HELPERS =====================
  Map<String, dynamic> _safeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return {"message": raw};
    } catch (_) {
      return {"message": raw};
    }
  }
}
