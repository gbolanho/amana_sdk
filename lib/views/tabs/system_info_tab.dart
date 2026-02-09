import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../widgets/glass_card.dart';

class SystemInfoTab extends StatefulWidget {
  const SystemInfoTab({super.key});

  @override
  State<SystemInfoTab> createState() => _SystemInfoTabState();
}

class _SystemInfoTabState extends State<SystemInfoTab> {
  Map<String, String> _info = {
    "OS": "Loading...",
    "CPU": "Loading...",
    "RAM": "Loading...",
    "GPU": "Loading...",
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSystemInfo();
  }

  Future<void> _fetchSystemInfo() async {
    final newInfo = <String, String>{};

    try {
      // 1. OS Info
      if (Platform.isWindows) {
        final winInfo = await DeviceInfoPlugin().windowsInfo;
        newInfo["OS"] = "Windows ${winInfo.majorVersion}.${winInfo.minorVersion} (${winInfo.buildNumber})";
        newInfo["Device Name"] = winInfo.computerName;
      } else {
        newInfo["OS"] = Platform.operatingSystem;
      }

      // 2. RAM (using WMIC on Windows)
      if (Platform.isWindows) {
        try {
          // TotalVisibleMemorySize is in Kilobytes
          final ramResult = await Process.run('wmic', ['OS', 'get', 'TotalVisibleMemorySize']);
          if (ramResult.exitCode == 0) {
            final lines = ramResult.stdout.toString().split('\n');
            if (lines.length > 1) {
              final kbString = lines[1].trim();
              final kb = int.tryParse(kbString) ?? 0;
              if (kb > 0) {
                 final gb = (kb / (1024 * 1024)).toStringAsFixed(1);
                 newInfo["RAM"] = "$gb GB";
              }
            }
          }
        } catch (e) {
          newInfo["RAM"] = "Unknown";
        }
      } else {
        newInfo["RAM"] = "Not Supported on ${Platform.operatingSystem}";
      }

      // 3. CPU & GPU (using WMIC on Windows)
      if (Platform.isWindows) {
        // CPU Name
        try {
          final cpuResult = await Process.run('wmic', ['cpu', 'get', 'name']);
          if (cpuResult.exitCode == 0) {
            final lines = cpuResult.stdout.toString().split('\n');
            if (lines.length > 1) {
               newInfo["CPU"] = lines[1].trim(); 
            }
          }
        } catch (_) {}

        // GPU Name & VRAM
        try {
          final gpuResult = await Process.run('wmic', ['path', 'win32_videocontroller', 'get', 'name,adapterram']);
          if (gpuResult.exitCode == 0) {
             final lines = gpuResult.stdout.toString().trim().split('\n');
             // Skip header
             if (lines.length > 1) {
               String gpuName = "Unknown GPU";
               String vram = "Unknown VRAM";
               
               for (var i = 1; i < lines.length; i++) {
                  final line = lines[i].trim();
                  if (line.isEmpty) continue;
                  
                  // Split by multiple spaces
                  final parts = line.split(RegExp(r'\s{2,}'));
                  if (parts.length >= 2) {
                     // AdapterRAM is bytes
                     final bytes = int.tryParse(parts[0]) ?? 0;
                     if (bytes > 0) {
                       final gb = (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
                       vram = "$gb GB";
                       gpuName = parts[1];
                       newInfo["GPU"] = "$gpuName ($vram VRAM)";
                       break; 
                     }
                  }
               }
             }
          }
        } catch (_) {}
      }

    } catch (e) {
      debugPrint("Error fetching system info: $e");
    }

    if (mounted) {
      setState(() {
        _info = newInfo;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "System Information",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _info.entries.map((entry) {
                return SizedBox(
                  width: 300,
                  height: 120,
                  child: GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
