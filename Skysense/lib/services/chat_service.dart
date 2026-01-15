import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_config.dart';

class ChatService {
  // HTTP base (port 3000) dari ApiConfig
  String get _baseUrl => ApiConfig.baseUrl;

  // Di backend : CHAT_WS_PORT = 3002
  // Kalau suatu saat mau  ganti, ubah angka ini.
  static const int chatWsPort = 3002;

  Map<String, String> _headers(String token) => {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      };

  Uri _http(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(_baseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : (base.scheme == "https" ? 443 : 80),
      path: path.startsWith("/") ? path : "/$path",
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Uri _wsChatUri(String token) {
    final base = Uri.parse(_baseUrl);

    final wsScheme = base.scheme == "https" ? "wss" : "ws";

    // chat ws  di port 3002, path root "/" + query token
    return Uri(
      scheme: wsScheme,
      host: base.host,
      port: chatWsPort,
      path: "/",
      queryParameters: {"token": token},
    );
  }

  /// ==========================================================
  /// ADMIN: list threads
  /// GET /admin/chat/threads
  /// (sesuai index.js kamu)
  /// ==========================================================
  Future<List<Map<String, dynamic>>> adminListThreads({
    required String token,
  }) async {
    final uri = _http("/admin/chat/threads");

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw "adminListThreads error (${res.statusCode}): ${res.body}";
    }

    final decoded = jsonDecode(res.body);

    // backend kamu return langsung list
    final rawList = decoded as List;
    return rawList.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// ==========================================================
  /// GET messages by thread
  /// GET /chat/threads/:id/messages?limit=50&beforeId=...
  /// ==========================================================
  Future<List<Map<String, dynamic>>> getMessages({
    required String token,
    required int threadId,
    int limit = 60,
    int? beforeId,
  }) async {
    final q = <String, dynamic>{"limit": limit};
    if (beforeId != null) q["beforeId"] = beforeId;

    final uri = _http("/chat/threads/$threadId/messages", q);

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw "getMessages error (${res.statusCode}): ${res.body}";
    }

    final decoded = jsonDecode(res.body);

    // backend kamu return langsung list
    final rawList = decoded as List;
    return rawList.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// ==========================================================
  /// WebSocket realtime chat
  /// ws://IP:3002?token=xxxxx
  /// ==========================================================
  WebSocketChannel connectChatWs({
    required String token,
  }) {
    final uri = _wsChatUri(token);
    return WebSocketChannel.connect(uri);
  }

  /// ==========================================================
  /// (Opsional) Client: get /chat/thread (auto create thread)
  /// GET /chat/thread
  /// Return: { threadId, admin }
  /// ==========================================================
  Future<Map<String, dynamic>> getClientThread({
    required String token,
  }) async {
    final uri = _http("/chat/thread");

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw "getClientThread error (${res.statusCode}): ${res.body}";
    }

    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  /// ==========================================================
  /// (Opsional) Send message lewat WS: kamu SUDAH lakukan di ChatRoomPage
  /// payload harus type=send_message, threadId, receiverId, message
  /// ==========================================================
  String buildSendPayload({
    required int threadId,
    required int receiverId,
    required String message,
  }) {
    return jsonEncode({
      "type": "send_message",
      "threadId": threadId,
      "receiverId": receiverId,
      "message": message,
    });
  }
}
