import 'package:flutter/material.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with TickerProviderStateMixin {
  int? selectedFeatureIndex;
  int? selectedDevIndex;

  // ==========================
  // DATA (EDIT SESUAI KELOMPOK)
  // ==========================
  final List<_AboutFeature> features = const [
    _AboutFeature(
      title: "Dashboard Realtime",
      desc:
          "Menampilkan data sensor masuk (suhu, kelembapan, angin, cahaya) secara realtime dari MQTT.",
      icon: Icons.dashboard_rounded,
    ),
    _AboutFeature(
      title: "Data Historis",
      desc:
          "Riwayat rata-rata harian dari endpoint /avgdata (hasil agregasi dari tabel data_sensor).",
      icon: Icons.history_rounded,
    ),
    _AboutFeature(
      title: "Grafik",
      desc:
          "Visualisasi perubahan nilai (contoh: suhu) untuk membantu analisis sederhana kondisi cuaca.",
      icon: Icons.show_chart_rounded,
    ),
    _AboutFeature(
      title: "Admin Panel",
      desc:
          "Manajemen user (approve/pending) + ringkasan sensor harian untuk monitoring admin.",
      icon: Icons.admin_panel_settings_rounded,
    ),
  ];

  final List<_Developer> developers = const [
    _Developer(
      name: "Angelina Geronsiana",
      nrp: "152023077",
      role: "Front-End (Client)",
      email: "angelina@mhs.itenas.ac.id",
      notes: "Fokus: Dashboard realtime, grafik, dan data historis.",
      photoAsset: "lib/assets/team/angel.png",
    ),
    _Developer(
      name: "Matilde Ina Ola",
      nrp: "152023014",
      role: "Front-End (Admin)",
      email: "matilde.ina@mhs.itenas.ac.id",
      notes: "Fokus: Admin dashboard, user management, dan UI admin.",
      photoAsset: "lib/assets/team/anggota4.jpeg",
    ),
    _Developer(
      name: "Asri Tanisha Rumapea",
      nrp: "152023137",
      role: "Back-End / API",
      email: "asri.tanisha@mhs.itenas.ac.id",
      notes: "Fokus: REST API, database, dan integrasi data sensor.",
      photoAsset: "lib/assets/team/anggota1.jpg",
    ),
  ];

  // ==========================
  // UI HELPERS
  // ==========================
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: child,
    );
  }

  Widget _chip(String text, {Color? bg, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFEAF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg ?? Colors.black87,
        ),
      ),
    );
  }

  // ==========================
  // FEATURE GRID + DETAIL
  // ==========================
  Widget _featureGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          itemCount: features.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.20, // aman dari overflow
          ),
          itemBuilder: (context, i) {
            final f = features[i];
            final selected = selectedFeatureIndex == i;

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() {
                  selectedFeatureIndex = selected ? null : i;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFEAF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? Colors.blue : const Color(0xFFEAEAEA),
                  ),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(f.icon, size: 28, color: Colors.blue),
                    const SizedBox(height: 10),
                    Text(
                      f.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        f.desc,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _chip(
                      selected ? "Dipilih" : "Klik untuk detail",
                      bg: selected ? Colors.blue : const Color(0xFFF2F4F7),
                      fg: selected ? Colors.white : Colors.black87,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: selectedFeatureIndex == null
              ? const SizedBox.shrink()
              : _detailPanelFeature(features[selectedFeatureIndex!]),
        ),
      ],
    );
  }

  Widget _detailPanelFeature(_AboutFeature f) {
    return _cardContainer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(f.icon, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(f.desc, style: const TextStyle(color: Colors.black87, height: 1.3)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip("Detail tampil di About"),
                    _chip("Info Terbaru", bg: const Color(0xFFE8F5E9)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================
  // DEVELOPER GRID 2 COL + DETAIL SLIDE DOWN
  // ==========================
  Widget _developerGrid2Col() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          itemCount: developers.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // ✅ 2 kolom
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15, // ✅ lebih tinggi, anti overflow
          ),
          itemBuilder: (context, i) {
            final d = developers[i];
            final selected = selectedDevIndex == i;

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() {
                  selectedDevIndex = selected ? null : i;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFEAF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? Colors.blue : const Color(0xFFEAEAEA),
                  ),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        d.photoAsset,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 58,
                          height: 58,
                          color: const Color(0xFFD9ECFF),
                          child: const Icon(Icons.person_rounded, color: Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.role,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.2),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _chip(
                              selected ? "Dipilih" : "Klik",
                              bg: selected ? Colors.blue : const Color(0xFFF2F4F7),
                              fg: selected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // ✅ panel detail slide down halus
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          child: selectedDevIndex == null
              ? const SizedBox.shrink()
              : _detailPanelDev(developers[selectedDevIndex!]),
        ),
      ],
    );
  }

  Widget _detailPanelDev(_Developer d) {
    return _cardContainer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              d.photoAsset,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 64,
                height: 64,
                color: const Color(0xFFEAF6FF),
                child: Icon(Icons.person_rounded, color: Colors.blue.shade700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip("NRP: ${d.nrp}"),
                    _chip(d.role, bg: const Color(0xFFE8F5E9)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.email_rounded, size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(d.email, style: const TextStyle(color: Colors.black87)),
                    ),
                  ],
                ),
                if ((d.notes ?? "").trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    d.notes!,
                    style: const TextStyle(color: Colors.black54, height: 1.25),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================
  // PAGE BUILD
  // ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9ECFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "About SkySense",
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tujuan / Deskripsi
            _cardContainer(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.insights_rounded, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Tujuan",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        SizedBox(height: 6),
                        Text(
                          "Membantu pengguna melihat kondisi lingkungan (suhu, kelembapan, angin, intensitas cahaya) "
                          "sebagai dasar pengambilan keputusan sederhana untuk kebutuhan pertanian/irigasi.",
                          style: TextStyle(color: Colors.black87, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _sectionTitle("Fitur Utama"),
            _featureGrid(),

            _sectionTitle("Sumber Data"),
            _cardContainer(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.wifi_tethering_rounded,
                    title: "Realtime (MQTT)",
                    lines: [
                      "Topic: ecowitt/weather",
                      "Update otomatis saat ada payload sensor",
                      "Jika alat mati, nilai bisa 0 — UI tetap stabil",
                    ],
                  ),
                  SizedBox(height: 14),
                  _InfoRow(
                    icon: Icons.storage_rounded,
                    title: "Historis (REST API)",
                    lines: [
                      "GET /avgdata",
                      "Hasil agregasi per tanggal dari tabel data_sensor",
                      "Dipakai untuk riwayat dan simulasi perhitungan",
                    ],
                  ),
                ],
              ),
            ),

            _sectionTitle("Perhitungan Irigasi "),
            _cardContainer(
              child: const _InfoRow(
                icon: Icons.calculate_rounded,
                title: "Analisis kebutuhan irigasi sederhana",
                lines: [
                  "Menghitung indeks kebutuhan irigasi (0–100) dari data sensor.",
                  "Contoh logika: suhu tinggi + kelembapan rendah → rekomendasi irigasi meningkat.",
                  "Tujuan: bantu petani/penyuluh dalam pengambilan keputusan irigasi.",
                ],
              ),
            ),

            _sectionTitle("Teknologi"),
            _cardContainer(
              child: const _InfoRow(
                icon: Icons.layers_rounded,
                title: "Stack",
                lines: [
                  "Flutter (UI Mobile)",
                  "Node.js + Express (REST API)",
                  "MySQL (Database)",
                  "MQTT (HiveMQ Public) untuk realtime",
                  "API PUBLIC:OpenWeatherMap, Visual Crossing",
                ],
              ),
            ),

            _sectionTitle("Kontak / Identitas"),
            _developerGrid2Col(),

            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

// ==========================
// SMALL COMPONENTS + MODELS
// ==========================
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 6),
              ...lines.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• ", style: TextStyle(color: Colors.black54)),
                      Expanded(
                        child: Text(
                          t,
                          style: const TextStyle(color: Colors.black87, height: 1.25),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutFeature {
  final String title;
  final String desc;
  final IconData icon;

  const _AboutFeature({
    required this.title,
    required this.desc,
    required this.icon,
  });
}

class _Developer {
  final String name;
  final String nrp;
  final String role;
  final String email;
  final String? notes;
  final String photoAsset;

  const _Developer({
    required this.name,
    required this.nrp,
    required this.role,
    required this.email,
    required this.photoAsset,
    this.notes,
  });
}
