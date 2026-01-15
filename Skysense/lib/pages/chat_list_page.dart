import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_service.dart';
import 'chat_room_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService chat = ChatService();
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> threads = [];

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString("token");
    if (t == null) throw "Token tidak ada. Login ulang.";
    return t;
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final token = await _token();
      final data = await chat.adminListThreads(token: token);
      if (!mounted) return;
      setState(() => threads = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9ECFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Chat Masuk", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
              ? Center(child: Text("Error: $error"))
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: threads.length,
                  itemBuilder: (_, i) {
                    final t = threads[i];
                    final threadId = (t["id"] as num).toInt();
                    final clientId = (t["client_id"] as num).toInt();
                    final name = (t["client_name"] ?? "-").toString();
                    final email = (t["client_email"] ?? "-").toString();
                    final last = (t["last_message"] ?? "").toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: ListTile(
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text("$email\n${last.isEmpty ? "(belum ada pesan)" : last}"),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomPage(
                                threadId: threadId,
                                otherUserId: clientId,
                                title: name,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
