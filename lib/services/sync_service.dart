import 'dart:io';
import 'package:dio/dio.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart' show launchUrl;

class SyncService {
  final Dio _dio = Dio();

  Future<void> downloadAndInstall({
    required String url,
    required String rootPath,
    required String folderName,
    required Function(double) onProgress,
    required Function(String) onStatus,
  }) async {
    // Force folder name to Uppercase
    final upperFolder = folderName.toUpperCase();
    final destinationDir = Directory(p.join(rootPath, upperFolder));
    final zipPath = p.join(rootPath, "$upperFolder.zip");

    if (!destinationDir.existsSync()) {
      destinationDir.createSync(recursive: true);
    }

    onStatus("Downloading...");
    final extension = url.split('.').last == 'xz' ? 'tar.xz' : url.split('.').last;
    final tempPath = p.join(rootPath, "$upperFolder.$extension");

    await _dio.download(
      url,
      tempPath,
      onReceiveProgress: (received, total) {
        if (total != -1) onProgress(received / total);
      },
    );

    onStatus("Extracting...");
    final tempFile = File(tempPath);
    final bytes = tempFile.readAsBytesSync();
    
    if (url.endsWith(".zip")) {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final filePath = p.join(destinationDir.path, file.name);
        if (file.isFile) {
          final data = file.content as List<int>;
          File(filePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory(filePath).createSync(recursive: true);
        }
      }
    } else if (url.endsWith(".tar.xz")) {
      // Prioritize native tar on Linux for better symlink and performance support
      bool nativeTarSuccess = false;
      if (Platform.isLinux) {
        try {
          print("[SyncService] Attempting native tar extraction on Linux...");
          final result = await Process.run('tar', ['-xJf', tempPath, '-C', destinationDir.path]);
          if (result.exitCode == 0) {
            nativeTarSuccess = true;
            print("[SyncService] Native tar extraction successful.");
          } else {
            print("[SyncService] Native tar failed: ${result.stderr}");
          }
        } catch (e) {
          print("[SyncService] native tar command not found or failed: $e");
        }
      }

      if (!nativeTarSuccess) {
        print("[SyncService] Using Dart fallback for .tar.xz extraction...");
        final tarBytes = XZDecoder().decodeBytes(bytes);
        final archive = TarDecoder().decodeBytes(tarBytes);
        for (final file in archive) {
          final filePath = p.join(destinationDir.path, file.name);
          if (file.isFile) {
            final data = file.content as List<int>;
            File(filePath)
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          } else if (file.isSymbolicLink) {
            print("[SyncService] Skipping symlink in Dart fallback: ${file.name}");
          } else {
            Directory(filePath).createSync(recursive: true);
          }
        }
      }
    }

    if (tempFile.existsSync()) tempFile.deleteSync();

    // Flattening: If there is only one nested folder, move its contents up.
    await _flattenDirectory(destinationDir);

    // Linux: Auto-apply permissions after extraction
    if (Platform.isLinux) {
      await Process.run('chmod', ['-R', '+x', destinationDir.path]);
    }

    // Godot Self-Contained Mode
    if (upperFolder == "GODOT") {
      final scFile = File(p.join(destinationDir.path, "._sc_"));
      if (!scFile.existsSync()) {
        scFile.createSync();
        print("[SyncService] Godot Self-Contained mode enabled (._sc_ created).");
      }
    }

    // Blender Portability: Create config folder
    if (upperFolder == "BLENDER") {
      final configDir = Directory(p.join(destinationDir.path, "config"));
      if (!configDir.existsSync()) {
        configDir.createSync(recursive: true);
        print("[SyncService] Blender config folder created at ${configDir.path}");
      }
    }

    onStatus("Ready");
  }

  // Checks if extraction created an unnecessary subfolder and flattens it
  Future<void> _flattenDirectory(Directory dir) async {
    final entities = dir.listSync();
    if (entities.length == 1 && entities.first is Directory) {
      final subDir = entities.first as Directory;
      print("[SyncService] Flattening: Moving contents of ${p.basename(subDir.path)} to ${p.basename(dir.path)}");
      
      final subEntities = subDir.listSync();
      for (final entity in subEntities) {
        final newPath = p.join(dir.path, p.basename(entity.path));
        if (entity is File) {
          entity.renameSync(newPath);
        } else if (entity is Directory) {
          entity.renameSync(newPath);
        }
      }
      subDir.deleteSync(recursive: true);
    }
  }

  // Delete everything except configuration folders (SC) for safe re-download
  Future<void> cleanForRedownload(String folderPath, String folderName) async {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return;

    final preserves = ['config', 'data', 'editor_data', '._sc_'];
    
    final entities = dir.listSync();
    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (preserves.contains(name)) continue;

      try {
        if (entity is File) {
          entity.deleteSync();
        } else if (entity is Directory) {
          entity.deleteSync(recursive: true);
        }
      } catch (e) {
        print("[SyncService] Could not delete $name: $e");
      }
    }
  }

  // Locates the actual executable within a folder (useful for portable folders with subdirectories)
  Future<String?> findExecutable(String folderPath, String pattern) async {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return null;

    // Check root first for efficiency (especially for flattened folders)
    final rootFile = File(p.join(folderPath, pattern));
    if (rootFile.existsSync()) return rootFile.path;

    // Follow up with recursive search if not found at root
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.toLowerCase() == pattern.toLowerCase()) {
            return entity.path;
          }
        }
      }
    } catch (e) {
      print("[SyncService] Error during executable search: $e");
    }
    return null;
  }

  // Injects the Blender path into Godot settings
  Future<void> finalizeStudioConfiguration(String rootPath) async {
    try {
      final godotDir = p.join(rootPath, "GODOT");
      final blenderDir = p.join(rootPath, "BLENDER");
      
      // 1. Locate the Blender executable
      final blenderExe = await findExecutable(
        blenderDir, 
        Platform.isWindows ? "blender.exe" : "blender"
      );
      
      if (blenderExe == null) {
        print("[SyncService] Blender executable not found for configuration injection.");
        return;
      }

      // 2. Locate (or create) Godot's configuration file (Self-Contained mode uses editor_data/)
      final configDir = Directory(p.join(godotDir, "editor_data"));
      if (!configDir.existsSync()) configDir.createSync(recursive: true);
      
      // Injection Rule: editor_settings-4.6.tres (as per Godot 4.6 LTS structure)
      File configFile = File(p.join(configDir.path, "editor_settings-4.6.tres"));
      
      String content = "";
      if (configFile.existsSync()) {
        content = await configFile.readAsString();
      } else {
        // Base template if it doesn't exist
        content = '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n';
      }

      // 3. Inject or update the Blender path
      // Godot prefere caminhos com "/" mesmo no Windows.
      final normalizedPath = p.canonicalize(blenderExe).replaceAll("\\", "/");
      final settingLine = 'filesystem/import/blender/blender_path = "$normalizedPath"';

      final settingRegex = RegExp(r'^filesystem/import/blender/blender_path\s*=.*$', multiLine: true);

      if (content.contains(settingRegex)) {
        // Substitui a linha existente
        content = content.replaceFirst(settingRegex, settingLine);
      } else {
        // Adiciona logo abaixo de [resource]
        if (content.contains('[resource]')) {
           content = content.replaceFirst('[resource]', '[resource]\n$settingLine');
        } else {
           // Fallback se o arquivo estiver zoado
           content += "\n[resource]\n$settingLine\n";
        }
      }

      await configFile.writeAsString(content);
      print("[SyncService] Configured Godot for Blender (LTS): $normalizedPath");

    } catch (e) {
      print("[SyncService] Error finalizing configuration: $e");
    }
  }

  Future<void> syncGit({
    required String repoUrl,
    required String token,
    required String rootPath,
    required Function(String) onStatus,
  }) async {
    // Project folder remains as Repo name (Ainimonia)
    final projectPath = p.join(rootPath, "Ainimonia");
    final authUrl = repoUrl.replaceFirst("https://", "https://$token@");

    final isClone = !Directory(p.join(projectPath, ".git")).existsSync();
    onStatus(isClone ? "Cloning..." : "Pulling...");

    final result = isClone
        ? await Process.run('git', ['clone', authUrl, projectPath])
        : await Process.run('git', ['-C', projectPath, 'pull']);

    if (result.exitCode != 0) throw Exception(result.stderr);
    onStatus("Ready");
  }

  // Launches executable with Hybrid Approach, Electron fixes, and Linux Permissions
  Future<void> launchTool(
    String fullPath, {
    List<String> args = const [],
  }) async {
    final file = File(fullPath);
    if (!file.existsSync()) throw "Executable not found at $fullPath";

    final cleanPath = p.canonicalize(fullPath);
    final workingDir = p.dirname(cleanPath);
    final fileName = p.basename(cleanPath);

    print("[SyncService] Launching: $cleanPath");
    print("[SyncService] Args: $args");
    print("[SyncService] CWD: $workingDir");

    try {
      // 0. SPECIFIC STRATEGY: Linux (Permission Check)
      if (Platform.isLinux) {
        print("[SyncService] Linux detected. Applying chmod +x...");
        await Process.run('chmod', ['+x', cleanPath]);
      }

      // 1. SPECIFIC STRATEGY: BLOCK (Electron Portability)
      if (fileName.toUpperCase().contains("BLOCK")) {
        print("[SyncService] Detected Electron App (BLOCK). Injecting portability data dir...");
        await Process.start(
          cleanPath,
          ['--user-data-dir=./data', '--no-sandbox', '--disable-gpu-compositing', ...args],
          workingDirectory: workingDir,
          runInShell: Platform.isWindows,
          mode: ProcessStartMode.detached,
        );
        return;
      }

      // 2. SPECIFIC STRATEGY: TRENCH (Environment Isolation)
      if (fileName.toUpperCase().contains("TRENCH")) {
        print("[SyncService] Detected TRENCH. Isolating environment variables...");
        final dataDir = p.join(workingDir, "data");
        if (!Directory(dataDir).existsSync()) Directory(dataDir).createSync(recursive: true);

        final env = Map<String, String>.from(Platform.environment);
        if (Platform.isWindows) {
          env['APPDATA'] = dataDir;
        } else {
          env['HOME'] = dataDir;
        }

        await Process.start(
          cleanPath,
          args,
          workingDirectory: workingDir,
          environment: env,
          runInShell: Platform.isWindows,
          mode: ProcessStartMode.detached,
        );
        return;
      }

      // 3. SPECIFIC STRATEGY: BLENDER (Environment isolation for portability)
      if (fileName.toUpperCase().contains("BLENDER")) {
        print("[SyncService] Detected BLENDER. Isolating environment variables...");
        final configDir = p.join(workingDir, "config");
        if (!Directory(configDir).existsSync()) Directory(configDir).createSync(recursive: true);

        final env = Map<String, String>.from(Platform.environment);
        // On Linux, Blender looks for config in $HOME/.config/blender
        // But if we want it truly portable, we should point HOME to our folder.
        if (Platform.isWindows) {
          env['APPDATA'] = configDir;
        } else {
          env['HOME'] = workingDir; // Points to BLENDER/ folder
        }

        await Process.start(
          cleanPath,
          args,
          workingDirectory: workingDir,
          environment: env,
          runInShell: Platform.isWindows,
          mode: ProcessStartMode.detached,
        );
        return;
      }

      // 4. STRATEGY FOR SIMPLE APPS (No arguments)
      if (args.isEmpty && !Platform.isLinux) {
        print("[SyncService] Using url_launcher (Shell Execute)...");
        final uri = Uri.file(cleanPath);
        if (!await launchUrl(uri)) {
          throw "Could not launch $cleanPath via Shell";
        }
        return;
      }

      // 5. STRATEGY FOR COMPLEX APPS OR LINUX (Direct Execute)
      print("[SyncService] Using Process.start (Detached)...");
      await Process.start(
        cleanPath,
        args,
        workingDirectory: workingDir,
        runInShell: Platform.isWindows,
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      print("[SyncService] Fatal Error Launching: $e");
      rethrow;
    }
  }

  // Calculate total and detailed size
  Future<Map<String, int>> getDiskUsageBreakdown(String rootPath) async {
    final breakdown = <String, int>{};
    int total = 0;

    final folders = ['Ainimonia', 'GODOT', 'TRENCH', 'BLOCK', 'BLENDER'];

    for (final folder in folders) {
      final dir = Directory(p.join(rootPath, folder));
      final size = await getDirectorySize(dir);
      breakdown[folder] = size;
      total += size;
    }

    breakdown['Total'] = total;
    return breakdown;
  }

  // Calculate total folder size (Recursive)
  Future<int> getDirectorySize(Directory dir) async {
    int totalSize = 0;
    try {
      if (dir.existsSync()) {
        await for (var entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      print(e);
    }
    return totalSize;
  }
}
