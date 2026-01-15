import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

class LiveVideoPage extends StatefulWidget {
  const LiveVideoPage({super.key});

  @override
  State<LiveVideoPage> createState() => _LiveVideoPageState();
}

class _LiveVideoPageState extends State<LiveVideoPage> {
  // IP CAM (sesuaikan)
  final String espCamIp = "10.230.214.36";

  // Status motor PAN dummy
  String motorStatus = "IDLE";

  void dummyPanControl(String cmd) {
    setState(() => motorStatus = cmd);
    debugPrint("PAN: $cmd");
  }

  @override
  Widget build(BuildContext context) {
    final camUrl = "http://$espCamIp:81/stream";

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Live Kondisi Langit",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent,
      ),

      backgroundColor: Colors.grey[100],

      body: Center(
        
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                "Streaming dari ESP32-CAM",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              // ================================
              // VIDEO STREAM CARD
              // ================================
              Container(
                width: 330,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Mjpeg(
                    stream: camUrl,
                    isLive: true,
                    fit: BoxFit.cover,
                    error: (context, error, stack) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_off_rounded,
                              color: Colors.redAccent,
                              size: 40,
                            ),
                            SizedBox(height: 10),
                            Text(
                              "Tidak bisa terhubung\ndengan ESP32-CAM",
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ================================
              // STATUS MOTOR (DUMMY)
              // ================================
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  "PAN: $motorStatus",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ================================
              // CONTROL PAN (Dummy)
              // ================================
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => dummyPanControl("LEFT"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(22),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 20),

                  ElevatedButton(
                    onPressed: () => dummyPanControl("STOP"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(20),
                    ),
                    child: const Icon(
                      Icons.stop_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 20),

                  ElevatedButton(
                    onPressed: () => dummyPanControl("RIGHT"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(22),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              TextButton(
                onPressed: () => dummyPanControl("IDLE"),
                child: const Text(
                  "Reset Posisi",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
