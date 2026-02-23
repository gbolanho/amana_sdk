import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:process_run/stdio.dart' show File, Directory;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/sdk_task.dart';
import '../services/localization_service.dart';
import '../services/sync_service.dart';
import 'settings_screen.dart';
import 'tabs/studio_tab.dart';
import 'tabs/maintenance_tab.dart';
import 'tabs/system_info_tab.dart';
import 'widgets/hub_header.dart';
import 'widgets/sidebar.dart';

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});
  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  int _activeTab = 0; // 0: Studio, 1: Maintenance, 2: Info
  String rootPath = "C:/AmanaSDK";
  Map<String, int> usageData = {};
  final TextEditingController _tokenController = TextEditingController();
  final SyncService _syncService = SyncService();
  bool isGlobalProcessing = false;
  bool isTokenValid = false;

  late List<SDKTask> tasks;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeTasks();
    _tokenController.addListener(() {
      setState(() => isTokenValid = _tokenController.text.trim().isNotEmpty);
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      rootPath = prefs.getString('sdk_root_path') ?? "C:/AmanaSDK";
      _tokenController.text = prefs.getString('github_token') ?? "";
    });
    _updateDiskUsage();
    await _checkInstallationStatus();
    _autoRedirectIfNeeded();
  }

  void _updateDiskUsage() async {
    final data = await _syncService.getDiskUsageBreakdown(rootPath);
    setState(() {
      usageData = data;
      // Populate individual task disk size
      for (var task in tasks) {
        final folderName = task.name.toUpperCase();
        if (usageData.containsKey(folderName)) {
          final bytes = usageData[folderName]!;
          if (bytes > 1024 * 1024 * 1024) {
            task.diskSize =
                "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
          } else {
            task.diskSize = "${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB";
          }
        }
      }
    });
  }

  Future<void> _checkInstallationStatus() async {
    for (var task in tasks) {
      bool installed = false;
      if (task.name == "AINIMONIA") {
        final projectDir = p.join(rootPath, "AINIMONIA");
        installed = Directory(p.join(projectDir, ".git")).existsSync();
      } else {
        // Blender is now at the root of the BLENDER folder, simplifying things.
        final taskDir = p.join(rootPath, task.name.toUpperCase());
        final exe = await _syncService.findExecutable(
          taskDir,
          Platform.isWindows
              ? (task.executablePath ?? "")
              : (task.executablePath?.replaceAll(".exe", "") ?? ""),
        );
        installed = exe != null;
      }
      setState(() {
        task.isInstalled = installed;
        task.isCompleted = installed;
      });
    }

    // After checking all, run a quick configuration finalize to ensure portability (paths injection)
    await _syncService.finalizeStudioConfiguration(rootPath);
  }

  void _autoRedirectIfNeeded() {
    // If any essential tool is missing, redirect to Maintenance
    bool allReady = tasks.every((t) => t.isInstalled);
    if (!allReady && _activeTab == 0) {
      setState(() => _activeTab = 1);
      print("[HubScreen] Some tools missing. Redirecting to Maintenance...");
    }
  }

  String _extractVersion(String? url) {
    if (url == null) return "Stable";
    // Regex based on common patterns in the URLs provided
    final reg = RegExp(r'(\d+\.\d+[\.\d]*)');
    final match = reg.firstMatch(url);
    return match?.group(0) ?? "Latest";
  }

  void _initializeTasks() {
    bool isWin = Platform.isWindows;
    // Helper to get urls based on OS
    String? getUrl(String win, String linux) => isWin ? win : linux;
    String? getExe(String win, String linux) => isWin ? win : linux;

    tasks = [
      SDKTask(
        name: "AINIMONIA",
        descriptionKey: "desc_project",
        iconPath: "assets/images/gameicon.png",
        color: Colors.white,
        repoUrl: "https://github.com/Amana-Games/Ainimonia.git",
        version: "Main",
      ),
      SDKTask(
        name: "GODOT",
        descriptionKey: "desc_godot",
        iconPath: "assets/images/godot.png",
        color: const Color(0xFF38BDF8),
        downloadUrl: getUrl(
          "https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_win64.exe.zip",
          "https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_linux.x86_64.zip",
        ),
        executablePath: getExe(
          "Godot_v4.6-stable_win64.exe",
          "Godot_v4.6-stable_linux.x86_64",
        ),
        version: "4.6 Stable",
      ),
      SDKTask(
        name: "BLOCK",
        descriptionKey: "desc_block",
        iconPath: "assets/images/BLOCK_icon.png",
        color: const Color(0xFFEF4444), // Block Red
        downloadUrl: getUrl(
          "https://github.com/Amana-Games/BLOCK/releases/download/v2026.2.3/BLOCK_Windows.zip",
          "https://github.com/Amana-Games/BLOCK/releases/download/v2026.2.3/BLOCK_Linux.zip",
        ),
        executablePath: getExe("BLOCK.exe", "BLOCK"),
        version: "2026.2.3",
      ),
      SDKTask(
        name: "TRENCH",
        descriptionKey: "desc_trench",
        iconPath: "assets/images/TRENCH_icon.png",
        color: const Color(0xFFF97316), // Trench Orange
        downloadUrl: getUrl(
          "https://github.com/Amana-Games/TRENCH/releases/download/v2026.2.7/TRENCH-Win64-AMD64-v2026.2.5-Release.zip",
          "https://github.com/Amana-Games/TRENCH/releases/download/v2026.2.7/TRENCH-Linux-x86_64-v2026.2.5-Release.zip",
        ),
        executablePath: getExe("TRENCH.exe", "TRENCH.AppImage"),
        version: "2026.2.7",
      ),
      SDKTask(
        name: "BLENDER",
        descriptionKey: "desc_blender",
        iconPath: "assets/images/blender.png",
        color: const Color(0xFFEA580C), // Blender Deep Orange
        downloadUrl: getUrl(
          "https://download.blender.org/release/Blender4.5/blender-4.5.6-windows-x64.zip",
          "https://download.blender.org/release/Blender4.5/blender-4.5.6-linux-x64.tar.xz",
        ),
        executablePath: getExe("blender.exe", "blender"),
        version: "4.5.6 LTS",
      ),
      SDKTask(
        name: "MATMAKER",
        descriptionKey: "desc_matmaker",
        iconPath: "assets/images/matmaker.png",
        color: const Color(0xFF8B5CF6), // Purple
        downloadUrl: getUrl(
          "https://github.com/Amana-Games/MATMAKER/releases/download/v2026.2.2/MATMAKER_v2026.2.2_windows.zip",
          "https://github.com/Amana-Games/MATMAKER/releases/download/v2026.2.2/MATMAKER_v2026.2.2_linux.tar.gz",
        ),
        executablePath: getExe("MATMAKER.exe", "MATMAKER"),
        version: "2026.2.2",
      ),
    ];
  }

  // Execution Logic
  void _launchApp(SDKTask task, {List<String> extraArgs = const []}) async {
    if (!task.isInstalled && task.name != "AINIMONIA") {
      _showError("${task.name} is not installed. Please sync first.");
      return;
    }

    try {
      // 1. AINIMONIA Task -> Launches GAME
      if (task.name == "AINIMONIA") {
        // Dependency Check for AINIMONIA
        final dependencies = tasks.where((t) => t.name != "AINIMONIA");
        if (dependencies.any((t) => !t.isInstalled)) {
          _showError(
            "Cannot launch AINIMONIA: Some tools (Godot, Blender, etc.) are missing.",
          );
          return;
        }

        final godotTask = tasks.firstWhere((t) => t.name == "GODOT");
        final godotExePath = p.join(
          rootPath,
          "GODOT",
          godotTask.executablePath,
        );

        if (!await File(godotExePath).exists()) {
          throw "Godot executable not found at $godotExePath";
        }

        final projectDir = p.join(rootPath, "AINIMONIA");
        final projectPath = p.join(projectDir, "project.godot");

        // Validate Game Launch: Check for .godot folder
        final importedDir = Directory(p.join(projectDir, ".godot"));
        if (!await importedDir.exists()) {
          throw "Project not imported! Please open in GODOT (Editor) first to import assets.";
        }

        // Launch Game: --path "Ainimonia"
        final cleanArgs = extraArgs
            .where((a) => a != "." && a != "--path")
            .toList();
        await _syncService.launchTool(
          godotExePath,
          args: [
            "--path",
            p.relative(projectDir, from: p.dirname(godotExePath)),
            ...cleanArgs,
          ],
        );
      }
      // 2. GODOT Task -> Launches EDITOR for Ainimonia
      else if (task.name == "GODOT") {
        final godotExePath = p.join(rootPath, "GODOT", task.executablePath);
        if (!await File(godotExePath).exists()) {
          throw "Godot executable not found at $godotExePath";
        }

        final projectDir = p.join(rootPath, "Ainimonia");

        // Launch Editor: --path "Ainimonia" -e
        await _syncService.launchTool(
          godotExePath,
          args: [
            "--path",
            p.relative(projectDir, from: p.dirname(godotExePath)),
            "-e",
          ],
        );
      }
      // 3. BLENDER Task
      else if (task.name == "BLENDER") {
        final blenderDir = p.join(rootPath, "BLENDER");
        final blenderExe = await _syncService.findExecutable(
          blenderDir,
          Platform.isWindows ? "blender.exe" : "blender",
        );

        if (blenderExe == null) {
          throw "Blender executable not found in $blenderDir";
        }

        await _syncService.launchTool(blenderExe, args: extraArgs);
      }
      // 4. MATMAKER Task
      else if (task.name == "MATMAKER") {
        final taskDirName = task.name.toUpperCase();
        final exePath = p.join(rootPath, taskDirName, task.executablePath);

        if (!await File(exePath).exists()) {
          throw "${task.name} executable not found at $exePath";
        }

        await _syncService.launchTool(exePath, args: extraArgs);
      }
      // 5. Other Tools (BLOCK, TRENCH)
      else {
        // Direct Path: root/TASK/TASK.exe
        final taskDirName = task.name.toUpperCase();
        final exePath = p.join(rootPath, taskDirName, task.executablePath);

        if (!await File(exePath).exists()) {
          throw "${task.name} executable not found at $exePath";
        }

        await _syncService.launchTool(exePath, args: extraArgs);
      }
    } catch (e) {
      _showError("Launch failed: $e. Setup might be incomplete.");
    }
  }

  Future<void> _runFullSync() async {
    setState(() => isGlobalProcessing = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_token', _tokenController.text);

    try {
      for (var task in tasks) {
        setState(() {
          task.isDownloading = true;
          task.isCompleted = false;
          task.isInstalled = task.isInstalled; // Keep previous state for UI
          task.progress = 0.0;
        });

        // Optimization: Skip download if already installed (except for AINIMONIA which is a Git Pull)
        if (task.name != "AINIMONIA" && task.isInstalled) {
          setState(() {
            task.statusMessage = "Already installed. Skipping...";
            task.isDownloading = false;
            task.isCompleted = true;
          });
          continue;
        }

        if (task.repoUrl != null && task.downloadUrl == null) {
          await _syncService.syncGit(
            repoUrl: task.repoUrl!,
            token: _tokenController.text,
            rootPath: rootPath,
            onStatus: (s) => setState(() => task.statusMessage = s),
          );
        } else if (task.downloadUrl != null) {
          await _syncService.downloadAndInstall(
            url: task.downloadUrl!,
            rootPath: rootPath,
            folderName: task.name,
            onProgress: (p) => setState(() => task.progress = p),
            onStatus: (s) => setState(() => task.statusMessage = s),
          );
        }
        setState(() {
          task.isDownloading = false;
          task.isCompleted = true;
        });
      }

      // Finalize Configuration (Injection)
      setState(() {
        for (var task in tasks) {
          if (task.name == "GODOT" ||
              task.name == "BLENDER" ||
              task.name == "MATMAKER") {
            task.statusMessage = "Configuring Portability...";
          }
        }
      });
      await _syncService.finalizeStudioConfiguration(rootPath);

      setState(() {
        for (var task in tasks) {
          task.statusMessage = "Ready";
        }
      });

      // Re-check installation status
      await _checkInstallationStatus();
      _updateDiskUsage();
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => isGlobalProcessing = false);
    }
  }

  Future<void> _syncSingleTask(SDKTask task) async {
    setState(() => isGlobalProcessing = true);
    try {
      setState(() {
        task.isDownloading = true;
        task.isCompleted = false;
        task.isInstalled = false;
        task.progress = 0.0;
        task.statusMessage = "Cleaning...";
      });

      // Safe clean
      final taskPath = p.join(rootPath, task.name.toUpperCase());
      await _syncService.cleanForRedownload(taskPath, task.name);

      if (task.repoUrl != null && task.downloadUrl == null) {
        await _syncService.syncGit(
          repoUrl: task.repoUrl!,
          token: _tokenController.text,
          rootPath: rootPath,
          onStatus: (s) => setState(() => task.statusMessage = s),
        );
      } else if (task.downloadUrl != null) {
        await _syncService.downloadAndInstall(
          url: task.downloadUrl!,
          rootPath: rootPath,
          folderName: task.name,
          onProgress: (p) => setState(() => task.progress = p),
          onStatus: (s) => setState(() => task.statusMessage = s),
        );
      }

      // Configuration check after specific tools
      if (task.name == "GODOT" || task.name == "BLENDER") {
        setState(() => task.statusMessage = "Configuring Portability...");
        await _syncService.finalizeStudioConfiguration(rootPath);
        setState(() => task.statusMessage = "Ready");
      }

      setState(() {
        task.isDownloading = false;
        task.isCompleted = true;
        task.statusMessage = "Ready";
      });

      await _checkInstallationStatus();
      _updateDiskUsage();
    } catch (e) {
      _showError("Sync failed for ${task.name}: $e");
    } finally {
      setState(() => isGlobalProcessing = false);
    }
  }

  Future<void> _selectPath() async {
    String? path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sdk_root_path', path);
      setState(() => rootPath = path);
      _updateDiskUsage();
      await _checkInstallationStatus(); // Re-verify on path change
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          Sidebar(
            activeIndex: _activeTab,
            onTabSelected: (index) => setState(() => _activeTab = index),
            onSettings: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  tokenController: _tokenController,
                  onLanguageToggle: () => setState(() {
                    Localization.currentLanguage =
                        Localization.currentLanguage == 'en' ? 'pt' : 'en';
                  }),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HubHeader(
                    title: Localization.t('hub_title'),
                    subtitle: _activeTab == 0
                        ? "STUDIO DASHBOARD"
                        : _activeTab == 1
                        ? "MAINTENANCE"
                        : "SYSTEM INFO",
                    usageData: usageData,
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: _activeTab == 0
                        ? StudioTab(
                            tasks: tasks,
                            onLaunch: _launchApp,
                            dependenciesReady: tasks
                                .where((t) => t.name != "AINIMONIA")
                                .every((t) => t.isInstalled),
                          )
                        : _activeTab == 1
                        ? MaintenanceTab(
                            tasks: tasks,
                            rootPath: rootPath,
                            onSelectPath: _selectPath,
                            onSync: _runFullSync,
                            onSyncTask: _syncSingleTask,
                            isSyncing: isGlobalProcessing,
                            isTokenValid: isTokenValid,
                          )
                        : SystemInfoTab(rootPath: rootPath),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
