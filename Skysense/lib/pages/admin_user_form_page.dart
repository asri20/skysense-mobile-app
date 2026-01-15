import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class AdminUserFormPage extends StatefulWidget {
  final Map<String, dynamic>? initial; // kalau null = create

  const AdminUserFormPage({super.key, this.initial});

  @override
  State<AdminUserFormPage> createState() => _AdminUserFormPageState();
}

class _AdminUserFormPageState extends State<AdminUserFormPage> {
  final AuthService auth = AuthService();

  late final TextEditingController nameC;
  late final TextEditingController emailC;
  final TextEditingController passC = TextEditingController();

  String role = "client";     // client | admin
  String status = "approved"; // approved | pending | blocked

  bool saving = false;

  bool get isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController(text: (widget.initial?["name"] ?? "").toString());
    emailC = TextEditingController(text: (widget.initial?["email"] ?? "").toString());
    role = (widget.initial?["role"] ?? "client").toString();
    status = (widget.initial?["status"] ?? "approved").toString();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString("token");
    if (t == null) throw "Token tidak ditemukan. Silakan login ulang.";
    return t;
  }

  Future<void> _save() async {
    final name = nameC.text.trim();
    final email = emailC.text.trim().toLowerCase();
    final password = passC.text;

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama & email wajib diisi")));
      return;
    }
    if (!isEdit && password.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password wajib diisi untuk user baru")));
      return;
    }

    setState(() => saving = true);
    try {
      final token = await _token();

      if (isEdit) {
        final id = (widget.initial!["id"] as num).toInt();
        await auth.adminUpdateUser(
          token: token,
          userId: id,
          name: name,
          email: email,
          password: password.trim().isEmpty ? null : password,
          role: role,
          status: status,
        );
      } else {
        await auth.adminCreateUser(
          token: token,
          name: name,
          email: email,
          password: password,
          role: role,
          status: status,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true); // return changed=true
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal simpan: $e")));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    nameC.dispose();
    emailC.dispose();
    passC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9ECFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(isEdit ? "Edit User" : "Tambah User",
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameC,
                  decoration: InputDecoration(
                    labelText: "Nama",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailC,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    prefixIcon: const Icon(Icons.email_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: passC,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: isEdit ? "Password (kosongkan jika tidak ganti)" : "Password",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    prefixIcon: const Icon(Icons.lock_rounded),
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: role,
                        items: const [
                          DropdownMenuItem(value: "client", child: Text("client")),
                          DropdownMenuItem(value: "admin", child: Text("admin")),
                        ],
                        onChanged: (v) => setState(() => role = v ?? "client"),
                        decoration: InputDecoration(
                          labelText: "Role",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: status,
                        items: const [
                          DropdownMenuItem(value: "approved", child: Text("approved")),
                          DropdownMenuItem(value: "pending", child: Text("pending")),
                          DropdownMenuItem(value: "blocked", child: Text("blocked")),
                        ],
                        onChanged: (v) => setState(() => status = v ?? "approved"),
                        decoration: InputDecoration(
                          labelText: "Status",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(saving ? "Menyimpan..." : "Simpan", style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
