import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  State<AdminUserManagementPage> createState() => _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  final AuthService auth = AuthService();

  bool loading = true;
  bool updating = false;
  String? error;

  List<Map<String, dynamic>> users = [];
  String filter = "all"; // all | pending | approved

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString("token");
    if (t == null) throw "Token tidak ditemukan. Silakan login ulang.";
    return t;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final token = await _token();
      final status = filter == "all" ? null : filter;

      // role client biar list admin tidak ikut (opsional)
      final data = await auth.fetchUsers(token: token, status: status, role: "client");

      if (!mounted) return;
      setState(() => users = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _setStatus(int userId, String status) async {
    if (updating) return;
    setState(() => updating = true);
    try {
      final token = await _token();
      await auth.setUserStatus(token: token, userId: userId, status: status);
      await _load();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Status user diubah jadi $status ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal update status: $e")),
      );
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _filterBar(),
            const SizedBox(height: 14),

            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : (error != null)
                      ? _errorView()
                      : (users.isEmpty)
                          ? const Center(child: Text("Tidak ada user."))
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: users.length,
                              itemBuilder: (_, i) => _userCard(users[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= UI =================

  Widget _filterBar() {
    Widget chip(String key, String label, IconData icon) {
      final selected = filter == key;
      return Expanded(
        child: InkWell(
          onTap: () {
            setState(() => filter = key);
            _load();
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? Colors.blue : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: selected ? Colors.white : Colors.blue),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip("all", "All", Icons.groups_rounded),
        const SizedBox(width: 10),
        chip("pending", "Pending", Icons.hourglass_top_rounded),
        const SizedBox(width: 10),
        chip("approved", "Approved", Icons.verified_rounded),
      ],
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Gagal load users:\n$error", textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text("Coba lagi")),
          ],
        ),
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> u) {
    final id = (u["id"] as num?)?.toInt() ?? 0;
    final name = (u["name"] ?? "-").toString();
    final email = (u["email"] ?? "-").toString();
    final status = (u["status"] ?? "-").toString().toLowerCase();

    final isApproved = status == "approved";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isApproved ? const Color(0xFFE8FFF2) : const Color(0xFFFFF6E6),
                child: Icon(
                  isApproved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                  color: isApproved ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(email, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isApproved ? const Color(0xFFE8FFF2) : const Color(0xFFFFF6E6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isApproved ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (updating || isApproved) ? null : () => _setStatus(id, "approved"),
                  icon: updating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label: const Text("Approve"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1ABC9C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (updating || !isApproved) ? null : () => _setStatus(id, "pending"),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text("Set Pending"),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
