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
    // Força o nome da pasta para Maiúsculo
    final upperFolder = folderName.toUpperCase();
    final destinationDir = Directory(p.join(rootPath, upperFolder));
    final zipPath = p.join(rootPath, "$upperFolder.zip");

    if (!destinationDir.existsSync()) {
      destinationDir.createSync(recursive: true);
    }

    onStatus("Downloading...");
    await _dio.download(
      url,
      zipPath,
      onReceiveProgress: (received, total) {
        if (total != -1) onProgress(received / total);
      },
    );

    onStatus("Extracting...");
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      final filePath = p.join(destinationDir.path, filename);
      if (file.isFile) {
        final data = file.content as List<int>;
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory(filePath).createSync(recursive: true);
      }
    }
    if (File(zipPath).existsSync()) File(zipPath).deleteSync();

    // Flattening: Se houver apenas uma pasta dentro e nada mais, movemos tudo para cima.
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

  // Verifica se a extração criou uma subpasta desnecessária e move o conteúdo para cima
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

  // Deleta tudo exceto as pastas de configuração (SC) para re-download seguro
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

  // Localiza o executável real dentro de uma pasta (útil para pastas portable com subdiretórios)
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

  // Injeta o caminho do Blender nas configurações da Godot
  Future<void> finalizeStudioConfiguration(String rootPath) async {
    try {
      final godotDir = p.join(rootPath, "GODOT");
      final blenderDir = p.join(rootPath, "BLENDER");
      
      // 1. Achar o executável do Blender
      final blenderExe = await findExecutable(
        blenderDir, 
        Platform.isWindows ? "blender.exe" : "blender"
      );
      
      if (blenderExe == null) {
        print("[SyncService] Blender executable not found for configuration injection.");
        return;
      }

      // 2. Localizar (ou criar) o arquivo de configurações da Godot (modo SC usa editor_data/)
      final configDir = Directory(p.join(godotDir, "editor_data"));
      if (!configDir.existsSync()) configDir.createSync(recursive: true);
      
      // Regra de Injeção: editor_settings-4.x.tres
      File configFile = File(p.join(configDir.path, "editor_settings-4.x.tres"));
      
      String content = "";

      if (configFile.existsSync()) {
        content = await configFile.readAsString();
      } else {
        // Template base se não existir
        content = '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n';
      }

      // 3. Injetar ou atualizar o caminho do Blender
      // Normaliza o caminho para formato Godot (slashes) e usa canonicalize
      final normalizedBlenderPath = p.canonicalize(blenderExe).replaceAll("\\", "/");
      final blenderSetting = 'filesystem/import/blender/blender_path = "$normalizedBlenderPath"';

      if (content.contains('filesystem/import/blender/blender_path')) {
        // Substitui a linha existente
        content = content.replaceFirst(
          RegExp(r'filesystem/import/blender/blender_path = ".*"'), 
          blenderSetting
        );
      } else {
        // Adiciona ao final da seção [resource]
        if (content.contains('[resource]')) {
           content = content.replaceFirst('[resource]', '[resource]\n$blenderSetting');
        } else {
           content += "\n[resource]\n$blenderSetting";
        }
      }

      await configFile.writeAsString(content);
      print("[SyncService] Blender path injected into Godot settings (${p.basename(configFile.path)}): $normalizedBlenderPath");

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
    // Pasta do projeto permanece como o nome do Repo (Ainimonia)
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

  // Lança o executável com Abordagem Híbrida, Correção para Electron e Permissões Linux
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
      // 0. ESTRATÉGIA ESPECÍFICA: Linux (Permission Check)
      if (Platform.isLinux) {
        print("[SyncService] Linux detectado. Aplicando chmod +x...");
        await Process.run('chmod', ['+x', cleanPath]);
      }

      // 1. ESTRATÉGIA ESPECÍFICA: BLOCK (Electron Portability)
      if (fileName.toUpperCase().contains("BLOCK")) {
        print("[SyncService] Detectado App Electron (BLOCK). Injetando portability data dir...");
        await Process.start(
          cleanPath,
          ['--user-data-dir=./data', '--no-sandbox', '--disable-gpu-compositing', ...args],
          workingDirectory: workingDir,
          runInShell: Platform.isWindows,
          mode: ProcessStartMode.detached,
        );
        return;
      }

      // 2. ESTRATÉGIA ESPECÍFICA: TRENCH (Environment Isolation)
      if (fileName.toUpperCase().contains("TRENCH")) {
        print("[SyncService] Detectado TRENCH. Isolando variáveis de ambiente...");
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

      // 3. ESTRATÉGIA PARA APPS SIMPLES (Sem argumentos)
      if (args.isEmpty) {
        print("[SyncService] Using url_launcher (Shell Execute)...");
        final uri = Uri.file(cleanPath);
        if (!await launchUrl(uri)) {
          throw "Could not launch $cleanPath via Shell";
        }
        return;
      }

      // 4. ESTRATÉGIA PARA APPS COMPLEXOS (GODOT, etc)
      print("[SyncService] Using Process.start (Detached)...");
      await Process.start(
        cleanPath,
        args,
        workingDirectory: workingDir,
        runInShell: false,
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      print("[SyncService] Fatal Error Launching: $e");
      rethrow;
    }
  }

  // Calcula tamanho total e detalhado
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

  // Calcula tamanho total da pasta (Recursivo)
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
