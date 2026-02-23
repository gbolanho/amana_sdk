import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../widgets/glass_card.dart';

class SystemInfoTab extends StatefulWidget {
  final String rootPath;
  const SystemInfoTab({super.key, required this.rootPath});

  @override
  State<SystemInfoTab> createState() => _SystemInfoTabState();
}

class _SystemInfoTabState extends State<SystemInfoTab> {
  List<SystemCategory> _categories = [];
  bool _isLoading = true;
  String _osName = "Unknown";
  IconData _osIcon = Icons.computer;

  @override
  void initState() {
    super.initState();
    _fetchSystemInfo();
  }

  Future<void> _fetchSystemInfo() async {
    final List<SystemCategory> categories = [];

    try {
      // 1. SYSTEM BASICS
      final systemMetrics = <SystemMetric>[];
      if (Platform.isWindows) {
        final winInfo = await DeviceInfoPlugin().windowsInfo;
        _osName = "Windows ${winInfo.majorVersion} ${winInfo.editionId}";
        _osIcon = Icons.window;
        systemMetrics.add(
          SystemMetric(
            "Build",
            winInfo.buildNumber.toString(),
            Icons.info_outline,
          ),
        );
        systemMetrics.add(
          SystemMetric("Computer Name", winInfo.computerName, Icons.badge),
        );

        final uptime = await _pwsh(
          '(Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime | Select-Object -ExpandProperty TotalHours',
        );
        if (uptime.isNotEmpty) {
          final hours = double.tryParse(uptime.trim()) ?? 0;
          systemMetrics.add(
            SystemMetric(
              "Session Uptime",
              "${hours.toStringAsFixed(1)} h",
              Icons.timer_outlined,
            ),
          );
        }
      } else {
        _osName = Platform.operatingSystem;
        _osIcon = Icons.terminal;
        systemMetrics.add(
          SystemMetric(
            "Kernel",
            Platform.operatingSystemVersion,
            Icons.settings_input_component,
          ),
        );
        final uptime = await _cmd('uptime', ['-p']);
        systemMetrics.add(
          SystemMetric(
            "Uptime",
            uptime.trim().replaceFirst('up ', ''),
            Icons.timer_outlined,
          ),
        );
      }
      categories.add(
        SystemCategory("SYSTEM", Icons.desktop_windows, systemMetrics),
      );

      // 2. CPU DATA (PowerShell is more reliable for multi-line data)
      final cpuMetrics = <SystemMetric>[];
      if (Platform.isWindows) {
        final name = await _pwsh(
          'Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name',
        );
        final cores = await _pwsh(
          'Get-CimInstance Win32_Processor | Select-Object -ExpandProperty NumberOfCores',
        );
        final threads = await _pwsh(
          'Get-CimInstance Win32_Processor | Select-Object -ExpandProperty NumberOfLogicalProcessors',
        );
        final clock = await _pwsh(
          'Get-CimInstance Win32_Processor | Select-Object -ExpandProperty MaxClockSpeed',
        );
        final l3 = await _pwsh(
          'Get-CimInstance Win32_Processor | Select-Object -ExpandProperty L3CacheSize',
        );

        cpuMetrics.add(
          SystemMetric("Model", name.split('\n').first.trim(), Icons.memory),
        );
        cpuMetrics.add(
          SystemMetric(
            "Topology",
            "$cores Cores / $threads Threads",
            Icons.account_tree,
          ),
        );
        if (clock.isNotEmpty) {
          final mhz = double.tryParse(clock.trim()) ?? 0;
          cpuMetrics.add(
            SystemMetric(
              "Base Clock",
              "${(mhz / 1000).toStringAsFixed(2)} GHz",
              Icons.speed,
            ),
          );
        }
        if (l3.isNotEmpty && l3.trim() != "0") {
          final kbytes = int.tryParse(l3.trim()) ?? 0;
          cpuMetrics.add(
            SystemMetric(
              "L3 Cache",
              "${(kbytes / 1024).toStringAsFixed(0)} MB",
              Icons.layers,
            ),
          );
        }
      } else {
        final cpuInfo = await _cmd('lscpu', []);
        final model = RegExp(
          r'Model name:\s+(.*)',
        ).firstMatch(cpuInfo)?.group(1);
        final speed = RegExp(
          r'CPU max MHz:\s+(.*)',
        ).firstMatch(cpuInfo)?.group(1);
        final threads = RegExp(
          r'CPU\(s\):\s+(.*)',
        ).firstMatch(cpuInfo)?.group(1);
        cpuMetrics.add(
          SystemMetric("Model", model ?? "Linux CPU", Icons.memory),
        );
        cpuMetrics.add(
          SystemMetric("Processors", threads ?? "Unknown", Icons.account_tree),
        );
        if (speed != null) {
          cpuMetrics.add(
            SystemMetric(
              "Max Clock",
              "${(double.parse(speed) / 1000).toStringAsFixed(2)} GHz",
              Icons.speed,
            ),
          );
        }
      }
      categories.add(SystemCategory("CPU", Icons.bolt, cpuMetrics));

      // 3. GPU DATA - Prioritize Dedicated GPU & Handle 12GB+ VRAM
      final gpuMetrics = <SystemMetric>[];
      if (Platform.isWindows) {
        // Try NVIDIA-SMI first (Best for 12GB+ accuracy)
        final nvidiasmi = await _cmd('nvidia-smi', [
          '--query-gpu=name,memory.total,driver_version',
          '--format=csv,noheader,nounits',
        ]);

        if (nvidiasmi.isNotEmpty && !nvidiasmi.contains("not found")) {
          try {
            final parts = nvidiasmi.split('\n').first.split(',');
            final name = parts[0].trim();
            final vramMb = double.tryParse(parts[1].trim()) ?? 0;
            final driver = parts[2].trim();

            gpuMetrics.add(SystemMetric("Model", name, Icons.videogame_asset));
            gpuMetrics.add(
              SystemMetric(
                "VRAM",
                "${(vramMb / 1024).toStringAsFixed(1)} GB dedicated",
                Icons.layers,
              ),
            );
            gpuMetrics.add(
              SystemMetric("Driver Version", driver, Icons.update),
            );
          } catch (_) {}
        }

        // If NVIDIA-SMI failed or didn't find the card, use WMI with 64-bit property if available
        if (gpuMetrics.isEmpty) {
          final gpuDetails = await _pwsh(
            'Get-CimInstance Win32_VideoController | Where-Object { \$_.AdapterRAM -gt 1 -and \$_.Name -notmatch "Virtual|Software|Parsec|Basic" } | Sort-Object AdapterRAM -Descending | Select-Object -First 1 | Select-Object Name, AdapterRAM, DriverVersion | ConvertTo-Json',
          );

          if (gpuDetails.isNotEmpty) {
            try {
              final data = jsonDecode(gpuDetails);
              gpuMetrics.add(
                SystemMetric(
                  "Model",
                  (data['Name'] ?? "Unknown GPU").toString().trim(),
                  Icons.videogame_asset,
                ),
              );
              final vramRaw = data['AdapterRAM'];
              if (vramRaw != null) {
                final double bytes = (vramRaw is num)
                    ? vramRaw.toDouble().abs()
                    : 0.0;
                // Handle potential 4GB wrap-around if reported as uint32
                double gb = bytes / (1024 * 1024 * 1024);
                if (gb == 4.0 && data['Name'].toString().contains("NVIDIA")) {
                  // Logic: If it's a modern NVIDIA and WMI says exactly 4GB, it's likely capped.
                  // But without smi, we can't be sure of the 12GB.
                  gpuMetrics.add(
                    SystemMetric("VRAM", ">= 4.0 GB dedicated", Icons.layers),
                  );
                } else {
                  gpuMetrics.add(
                    SystemMetric(
                      "VRAM",
                      "${gb.toStringAsFixed(1)} GB dedicated",
                      Icons.layers,
                    ),
                  );
                }
              }
              gpuMetrics.add(
                SystemMetric(
                  "Driver Version",
                  (data['DriverVersion'] ?? "Unknown").toString(),
                  Icons.update,
                ),
              );
            } catch (_) {}
          }
        }
      } else {
        final glx = await _cmd('glxinfo', ['-B']);
        final renderer = RegExp(r'Device:\s+(.*)').firstMatch(glx)?.group(1);
        gpuMetrics.add(
          SystemMetric(
            "Renderer",
            renderer ?? "Generic GL",
            Icons.videogame_asset,
          ),
        );
      }
      categories.add(SystemCategory("GPU", Icons.visibility, gpuMetrics));

      // 4. MEMORY (RAM)
      final ramMetrics = <SystemMetric>[];
      if (Platform.isWindows) {
        final totalKb = await _pwsh(
          '(Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize',
        );
        final freeKb = await _pwsh(
          '(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory',
        );
        final speed = await _pwsh(
          'Get-CimInstance Win32_PhysicalMemory | Select-Object -ExpandProperty Speed',
        );

        final tkb = double.tryParse(totalKb.trim()) ?? 0;
        final fkb = double.tryParse(freeKb.trim()) ?? 0;
        final used = tkb - fkb;

        ramMetrics.add(
          SystemMetric(
            "Usage",
            "${(used / (1024 * 1024)).toStringAsFixed(1)} / ${(tkb / (1024 * 1024)).toStringAsFixed(1)} GB",
            Icons.pie_chart,
            progress: tkb > 0 ? (used / tkb) : null,
          ),
        );
        if (speed.isNotEmpty) {
          ramMetrics.add(
            SystemMetric(
              "Memory Speed",
              "${speed.trim().split('\n').first} MHz",
              Icons.shutter_speed,
            ),
          );
        }
      } else {
        final mem = await _cmd('free', ['-m']);
        final lines = mem.split('\n');
        if (lines.length > 1) {
          final p = lines[1].split(RegExp(r'\s+'));
          final tot = int.tryParse(p[1]) ?? 1;
          final usd = int.tryParse(p[2]) ?? 0;
          ramMetrics.add(
            SystemMetric(
              "Usage",
              "${(usd / 1024).toStringAsFixed(1)} / ${(tot / 1024).toStringAsFixed(1)} GB",
              Icons.pie_chart,
              progress: usd / tot,
            ),
          );
        }
      }
      categories.add(SystemCategory("MEMORY", Icons.storage, ramMetrics));

      // 5. STORAGE - Normalized Drive detection
      final storageMetrics = <SystemMetric>[];
      if (Platform.isWindows) {
        String driveLetter = "C";
        if (widget.rootPath.contains(":")) {
          driveLetter = widget.rootPath
              .split(":")[0]
              .toUpperCase()
              .replaceAll(RegExp(r'[^A-Z]'), '');
        }

        // Strategy A: Get-PSDrive (Very reliable for all mounted drives)
        final pDrive = await _pwsh(
          "Get-PSDrive $driveLetter | Select-Object Used, Free | ConvertTo-Json",
        );
        if (pDrive.isNotEmpty) {
          try {
            final data = jsonDecode(pDrive);
            final double u = (data['Used'] as num).toDouble();
            final double f = (data['Free'] as num).toDouble();
            final t = u + f;
            storageMetrics.add(
              SystemMetric(
                "Drive $driveLetter:",
                "${(u / (1024 * 1024 * 1024)).toStringAsFixed(1)} / ${(t / (1024 * 1024 * 1024)).toStringAsFixed(0)} GB",
                Icons.storage,
                progress: t > 0 ? (u / t) : 0,
              ),
            );
          } catch (_) {}
        }

        // Strategy B Fallback: Get-Volume
        if (storageMetrics.isEmpty) {
          final diskInfo = await _pwsh(
            "Get-Volume -DriveLetter $driveLetter | Select-Object Size, SizeRemaining | ConvertTo-Json",
          );
          if (diskInfo.isNotEmpty) {
            try {
              final data = jsonDecode(diskInfo);
              final double t = (data['Size'] as num).toDouble();
              final double f = (data['SizeRemaining'] as num).toDouble();
              final u = t - f;
              storageMetrics.add(
                SystemMetric(
                  "Drive $driveLetter:",
                  "${(u / (1024 * 1024 * 1024)).toStringAsFixed(1)} / ${(t / (1024 * 1024 * 1024)).toStringAsFixed(0)} GB",
                  Icons.storage,
                  progress: t > 0 ? (u / t) : 0,
                ),
              );
            } catch (_) {}
          }
        }
      } else {
        final df = await _cmd('df', ['-h', widget.rootPath]);
        final lines = df.split('\n');
        if (lines.length > 1) {
          final p = lines[1].split(RegExp(r'\s+'));
          storageMetrics.add(
            SystemMetric("Volume", "${p[2]} used of ${p[1]}", Icons.storage),
          );
        }
      }
      categories.add(
        SystemCategory("STORAGE", Icons.cloud_queue, storageMetrics),
      );

      // 6. NETWORK
      final netMetrics = <SystemMetric>[];
      if (Platform.isWindows) {
        final online = await _pwsh(
          'Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet',
        );
        final ip = await _pwsh(
          '(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi", "Ethernet" | Select-Object -First 1).IPAddress',
        );
        netMetrics.add(
          SystemMetric(
            "Internet",
            online.trim() == "True" ? "Online" : "Offline",
            online.trim() == "True" ? Icons.wifi : Icons.wifi_off,
          ),
        );
        if (ip.isNotEmpty) {
          netMetrics.add(SystemMetric("Local IP", ip.trim(), Icons.lan));
        }
      } else {
        final ip = await _cmd('hostname', ['-I']);
        final ping = await _cmd('ping', ['-c', '1', '1.1.1.1']);
        netMetrics.add(
          SystemMetric(
            "Internet",
            ping.contains("1 received") ? "Online" : "Offline",
            Icons.wifi,
          ),
        );
        if (ip.isNotEmpty) {
          netMetrics.add(
            SystemMetric("IP", ip.split(' ').first.trim(), Icons.lan),
          );
        }
      }
      categories.add(
        SystemCategory("NETWORK", Icons.network_check, netMetrics),
      );
    } catch (e) {
      debugPrint("Error fetching system info: $e");
    }

    if (mounted) {
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  Future<String> _pwsh(String command) async {
    try {
      final res = await Process.run('powershell', ['-Command', command]);
      return res.stdout.toString();
    } catch (e) {
      return "";
    }
  }

  Future<String> _cmd(String command, List<String> args) async {
    try {
      final res = await Process.run(command, args);
      return res.stdout.toString();
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(80),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.blueAccent),
                    const SizedBox(height: 24),
                    Text(
                      "Scanning System Hardware...",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._categories.map((cat) => _buildCategorySection(cat)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(_osIcon, size: 48, color: Colors.blueAccent),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "System Diagnostics",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _osName,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySection(SystemCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(category.icon, size: 18, color: Colors.white24),
              const SizedBox(width: 12),
              Text(
                category.name,
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: Divider(color: Colors.white10)),
            ],
          ),
        ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: category.metrics.map((m) => _buildMetricCard(m)).toList(),
        ),
      ],
    );
  }

  Widget _buildMetricCard(SystemMetric metric) {
    return SizedBox(
      width: 280,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    metric.icon,
                    color: Colors.blueAccent.withOpacity(0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      metric.label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                metric.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                softWrap: true,
              ),
              if (metric.progress != null) ...[
                const SizedBox(height: 16),
                Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: metric.progress!.clamp(0.0, 1.0),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.blueAccent, Colors.cyanAccent],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SystemCategory {
  final String name;
  final IconData icon;
  final List<SystemMetric> metrics;
  SystemCategory(this.name, this.icon, this.metrics);
}

class SystemMetric {
  final String label;
  final String value;
  final IconData icon;
  final double? progress;
  SystemMetric(this.label, this.value, this.icon, {this.progress});
}
