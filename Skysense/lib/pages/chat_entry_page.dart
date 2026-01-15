import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/chat_service.dart';
import 'chat_list_page.dart';
import 'chat_room_page.dart';

class ChatEntryPage extends StatefulWidget {
  const ChatEntryPage({super.key});

  @override
  State<ChatEntryPage> createState() => _ChatEntryPageState();
}

class _ChatEntryPageState extends State<ChatEntryPage> {
  final ChatService chat = ChatService();

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final role = prefs.getString("role") ?? "";

      if (token == null) throw "Token tidak ada. Login ulang.";

      // ADMIN -> list threads
      if (role == "admin") {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ChatListPage()),
        );
        return;
      }

      // CLIENT -> auto get/create thread dengan admin
      final res = await chat.getClientThread(token: token);
      final threadId = (res["threadId"] as num).toInt();

      final admin = (res["admin"] as Map).cast<String, dynamic>();
      final adminId = (admin["id"] as num).toInt();
      final adminName = (admin["name"] ?? "Admin").toString();

      if (!mounted) return;
      Navigator.pushReplacement(
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
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9ECFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Chat",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Error: $error", textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _go,
                      child: const Text("Coba lagi"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
