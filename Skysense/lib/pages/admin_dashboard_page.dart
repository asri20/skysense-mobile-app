import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_sensor_daily_page.dart';
import 'admin_user_management_page.dart';
import 'admin_sensor_logs_delete_page.dart';
import 'admin_users_page.dart';
import 'chat_list_page.dart';
import 'login_page.dart';
import 'about_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _tab = 0; // 0: Sensor, 1: Chat, 2: Approve

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Halaman sesuai tab
    final pages = [
      const AdminSensorDailyPage(),
      const ChatListPage(),
      const AdminUserManagementPage(),
    ];

    // Judul kecil sesuai tab
    final subtitle = _tab == 0
        ? "Sensor Harian"
        : _tab == 1
            ? "Chat Masuk"
            : "Approve User";

    return Scaffold(
      backgroundColor: const Color(0xFFD9ECFF),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.8,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Admin Dashboard",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "About",
            icon: const Icon(Icons.info_outline_rounded, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            },
          ),

          // Menu titik 3: biar tombol CRUD/Delete rapih dan gak bikin penuh
          PopupMenuButton<String>(
            tooltip: "Menu",
            icon: const Icon(Icons.more_vert_rounded, color: Colors.black87),
            onSelected: (v) {
              if (v == "users") {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                );
              }
              if (v == "logs") {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminSensorLogsDeletePage()),
                );
              }
              if (v == "logout") {
                _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: "users",
                child: Row(
                  children: [
                    Icon(Icons.manage_accounts_rounded, color: Colors.blue),
                    SizedBox(width: 10),
                    Text("Daftar User"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: "logs",
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text("Delete Sensor Logs"),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: "logout",
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.black87),
                    SizedBox(width: 10),
                    Text("Logout"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: pages[_tab],

      // Bottom nav 3 item: Chat di tengah
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          currentIndex: _tab,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          onTap: (i) => setState(() => _tab = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_rounded),
              label: "Sensor",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              label: "Chat",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.supervised_user_circle_rounded),
              label: "Approve",
            ),
          ],
        ),
      ),
    );
  }
}
