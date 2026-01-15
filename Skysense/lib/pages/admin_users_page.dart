import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import 'admin_user_form_page.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final AuthService auth = AuthService();

  bool loading = true;
  String? error;

  List<Map<String, dynamic>> users = [];

  String query = "";
  String filterStatus = "all"; // all|pending|approved|blocked
  String filterRole = "all"; // all|client|admin

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString("token");
    if (t == null) throw "Sesi habis. Silakan login ulang.";
    return t;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final token = await _token();
      final status = filterStatus == "all" ? null : filterStatus;
      final role = filterRole == "all" ? null : filterRole;

      final data = await auth.fetchUsers(token: token, status: status, role: role);

      if (!mounted) return;
      setState(() => users = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return users;
    return users.where((u) {
      final name = (u["name"] ?? "").toString().toLowerCase();
      final email = (u["email"] ?? "").toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  Future<void> _openCreate() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminUserFormPage()),
    );
    if (changed == true) _load();
  }

  Future<void> _openEdit(Map<String, dynamic> u) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminUserFormPage(initial: u)),
    );
    if (changed == true) _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> u) async {
    final id = int.tryParse(u["id"].toString()) ?? 0;
    final name = (u["name"] ?? "-").toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus user?"),
        content: Text("User \"$name\" akan dihapus permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final token = await _token();
      await auth.adminDeleteUser(token: token, userId: id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User berhasil dihapus ✅")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal hapus: $e")));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "approved":
        return Colors.green;
      case "pending":
        return Colors.orange;
      case "blocked":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFD9ECFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Manajemen User",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: "Filter Role",
            onSelected: (v) {
              setState(() => filterRole = v);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: "all", child: Text("Role: All")),
              PopupMenuItem(value: "client", child: Text("Role: Client")),
              PopupMenuItem(value: "admin", child: Text("Role: Admin")),
            ],
            icon: const Icon(Icons.badge_rounded, color: Colors.black87),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text("User Baru", style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _searchBar(),
              const SizedBox(height: 10),
              _statusChips(),
              const SizedBox(height: 12),

              if (loading) ...[
                const SizedBox(height: 60),
                const Center(child: CircularProgressIndicator()),
              ] else if (error != null) ...[
                _errorView(),
              ] else if (filtered.isEmpty) ...[
                const SizedBox(height: 70),
                const Center(child: Text("Tidak ada user.", style: TextStyle(color: Colors.black54))),
              ] else ...[
                ...filtered.map(_userCard),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: TextField(
        onChanged: (v) => setState(() => query = v),
        decoration: InputDecoration(
          hintText: "Cari nama atau email...",
          prefixIcon: const Icon(Icons.search_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _statusChips() {
    Widget chip(String key, String label, IconData icon) {
      final selected = filterStatus == key;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.blue),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) {
          setState(() => filterStatus = key);
          _load();
        },
        selectedColor: Colors.blue,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        chip("all", "All", Icons.groups_rounded),
        chip("pending", "Pending", Icons.hourglass_top_rounded),
        chip("approved", "Approved", Icons.verified_rounded),
        chip("blocked", "Blocked", Icons.block_rounded),
      ],
    );
  }

  Widget _userCard(Map<String, dynamic> u) {
    final id = int.tryParse(u["id"].toString()) ?? 0;
    final name = (u["name"] ?? "-").toString();
    final email = (u["email"] ?? "-").toString();
    final role = (u["role"] ?? "-").toString();
    final status = (u["status"] ?? "-").toString().toLowerCase();

    final c = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: c.withOpacity(0.12),
            child: Icon(
              status == "approved"
                  ? Icons.verified_rounded
                  : status == "pending"
                      ? Icons.hourglass_top_rounded
                      : Icons.block_rounded,
              color: c,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: c),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(email, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text("Role: $role • ID: $id", style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),

          PopupMenuButton<String>(
            tooltip: "Aksi",
            onSelected: (v) {
              if (v == "edit") _openEdit(u);
              if (v == "delete") _confirmDelete(u);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: "edit", child: Text("Edit")),
              PopupMenuItem(value: "delete", child: Text("Hapus")),
            ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 44, color: Colors.red),
          const SizedBox(height: 10),
          Text("Gagal memuat:\n$error", textAlign: TextAlign.center),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Coba lagi"),
          )
        ],
      ),
    );
  }
}
