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
  }

  void _updateDiskUsage() async {
    final data = await _syncService.getDiskUsageBreakdown(rootPath);
    setState(() {
      usageData = data;
    });
  }

  void _initializeTasks() {
    bool isWin = Platform.isWindows;
    tasks = [
      SDKTask(
        name: "Ainimonia",
        descriptionKey: "desc_project",
        iconPath: "assets/images/gameicon.png",
        color: Colors.purpleAccent,
        repoUrl: "https://github.com/Amana-Games/Ainimonia.git",
      ),
      SDKTask(
        name: "GODOT",
        descriptionKey: "desc_godot",
        iconPath: "assets/images/godot.png",
        color: const Color(0xFF38BDF8),
        downloadUrl: isWin
            ? "https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_win64.exe.zip"
            : "https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_linux.x86_64.zip",
        executablePath: isWin
            ? "Godot_v4.6-stable_win64.exe"
            : "Godot_v4.6-stable_linux.x86_64",
      ),
      SDKTask(
        name: "BLOCK",
        descriptionKey: "desc_block",
        iconPath: "assets/images/BLOCK_icon.png",
        color: Colors.yellowAccent,
        downloadUrl: isWin
            ? "https://github.com/Amana-Games/BLOCK/releases/download/2026.2/BLOCK_Windows.zip"
            : "https://github.com/Amana-Games/BLOCK/releases/download/2026.2/BLOCK_Linux.zip",
        executablePath: isWin ? "BLOCK.exe" : "BLOCK",
      ),
      SDKTask(
        name: "TRENCH",
        descriptionKey: "desc_trench",
        iconPath: "assets/images/TRENCH_icon.png",
        color: Colors.orangeAccent,
        downloadUrl: isWin
            ? "https://github.com/Amana-Games/TRENCH/releases/download/v2026.2.3/TrenchBroom-Win64-AMD64-v2026.2.3-Release.zip"
            : "https://github.com/Amana-Games/TRENCH/releases/download/v2026.2.3/TrenchBroom-Linux-x86_64-v2026.2.3-Release.zip",
        executablePath: isWin ? "TRENCH.exe" : "TRENCH.AppImage",
      ),
    ];
  }

  // Lógica de Execução
  void _launchApp(SDKTask task, {List<String> extraArgs = const []}) async {
    try {
      // 1. Ainimonia Task -> Launches GAME
      if (task.name == "Ainimonia") {
        final godotTask = tasks.firstWhere((t) => t.name == "GODOT");
        final godotExePath = p.join(
          rootPath,
          "GODOT",
          godotTask.executablePath,
        );

        if (!await File(godotExePath).exists()) {
          throw "Godot executable not found at $godotExePath";
        }

        final projectDir = p.join(rootPath, "Ainimonia");
        final projectPath = p.join(projectDir, "project.godot");

        // Validate Game Launch: Check for .godot folder
        final importedDir = Directory(p.join(projectDir, ".godot"));
        if (!await importedDir.exists()) {
          throw "Project not imported! Please open in GODOT (Editor) first to import assets.";
        }

        // Clean args and launch
        final cleanArgs = extraArgs
            .where((a) => a != "." && a != "--path")
            .toList();
        await _syncService.launchTool(
          godotExePath,
          args: ["--path", p.dirname(projectPath), ...cleanArgs],
        );
      }
      // 2. GODOT Task -> Launches EDITOR for Ainimonia
      else if (task.name == "GODOT") {
        final godotExePath = p.join(rootPath, "GODOT", task.executablePath);
        if (!await File(godotExePath).exists()) {
          throw "Godot executable not found at $godotExePath";
        }

        final projectPath = p.join(rootPath, "Ainimonia", "project.godot");

        // Launch with -e (Editor) flag pointing to project
        await _syncService.launchTool(
          godotExePath,
          args: ["--path", p.dirname(projectPath), "-e"],
        );
      }
      // 3. Other Tools (BLOCK, TRENCH)
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
          task.progress = 0.0;
        });
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
      _updateDiskUsage();
    } catch (e) {
      _showError(e.toString());
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
                        ? StudioTab(tasks: tasks, onLaunch: _launchApp)
                        : _activeTab == 1
                        ? MaintenanceTab(
                            tasks: tasks,
                            rootPath: rootPath,
                            onSelectPath: _selectPath,
                            onSync: _runFullSync,
                            isSyncing: isGlobalProcessing,
                            isTokenValid: isTokenValid,
                          )
                        : const SystemInfoTab(),
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
