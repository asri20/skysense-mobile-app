import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/chat_service.dart';

class ChatRoomPage extends StatefulWidget {
  final int threadId;
  final int otherUserId; // receiver id
  final String title;

  const ChatRoomPage({
    super.key,
    required this.threadId,
    required this.otherUserId,
    required this.title,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ChatService chat = ChatService();
  final TextEditingController msgC = TextEditingController();

  WebSocketChannel? channel;

  bool loading = true;
  String? error;
  List<Map<String, dynamic>> messages = [];

  int myId = 0;
  String myRole = "";

  Future<void> _init() async {
    setState(() { loading = true; error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) throw "Token hilang. Login ulang.";
      myRole = prefs.getString("role") ?? "";
      // opsional: simpan id user di prefs pas login, tapi kalau belum ada ya gapapa.
      // paling aman: decode JWT di backend — tapi di Flutter kita cukup tampilin bubble berdasar sender_role.
      // Untuk tampilan, kita pakai sender_role: kalau admin berarti kanan untuk admin, dsb.
      // myId tidak wajib.

      final initial = await chat.getMessages(token: token, threadId: widget.threadId, limit: 60);
      messages = initial;

      channel = chat.connectChatWs(token: token);
      channel!.stream.listen((event) {
        try {
          final data = jsonDecode(event);
          if (data is Map && data["type"] == "new_message") {
            final msg = (data["message"] as Map).cast<String, dynamic>();
            if ((msg["thread_id"] as num).toInt() == widget.threadId) {
              setState(() => messages.add(msg));
            }
          }
        } catch (_) {}
      });

      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); loading = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _send() {
    final text = msgC.text.trim();
    if (text.isEmpty || channel == null) return;

    final payload = {
      "type": "send_message",
      "threadId": widget.threadId,
      "receiverId": widget.otherUserId,
      "message": text,
    };

    channel!.sink.add(jsonEncode(payload));
    msgC.clear();
  }

  @override
  void dispose() {
    msgC.dispose();
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9ECFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
              ? Center(child: Text("Error: $error"))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final m = messages[i];
                          final role = (m["sender_role"] ?? "").toString();
                          final text = (m["message"] ?? "").toString();
                          final isMe = role == myRole;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blue : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                              ),
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: msgC,
                              decoration: InputDecoration(
                                hintText: "Ketik pesan...",
                                filled: true,
                                fillColor: const Color(0xFFF2F4F7),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 48,
                            width: 48,
                            child: ElevatedButton(
                              onPressed: _send,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Icon(Icons.send_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
