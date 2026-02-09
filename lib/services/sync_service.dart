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

    // Linux: Auto-apply permissions after extraction
    if (Platform.isLinux) {
      await Process.run('chmod', ['-R', '+x', destinationDir.path]);
    }

    onStatus("Ready");
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
      // Garante que o executável tenha permissão antes de tentar abrir.
      if (Platform.isLinux) {
        print("[SyncService] Linux detectado. Aplicando chmod +x...");
        await Process.run('chmod', ['+x', cleanPath]);
      }

      // 1. ESTRATÉGIA ESPECÍFICA: BLOCK (Electron/Chromium Workaround)
      // O Electron falha se não tiver as flags de sandbox e se não rodar no shell (Windows).
      // Usamos Process.start mesmo sem argumentos extras para injetar bypass.
      if (fileName.toUpperCase().contains("BLOCK")) {
        print("[SyncService] Detectado App Electron (BLOCK). Injetando flags de bypass...");
        await Process.start(
          cleanPath,
          ['--no-sandbox', '--disable-gpu-compositing', ...args],
          workingDirectory: workingDir,
          runInShell: Platform.isWindows, // Vital para Electron no Windows
          mode: ProcessStartMode.detached,
        );
        return;
      }

      // 2. ESTRATÉGIA PARA APPS SIMPLES (TRENCH, etc) -> Sem argumentos
      // Usamos url_launcher para invocar o Shell Nativo.
      if (args.isEmpty) {
        print("[SyncService] Using url_launcher (Shell Execute)...");
        final uri = Uri.file(cleanPath);
        if (!await launchUrl(uri)) {
          throw "Could not launch $cleanPath via Shell";
        }
        return;
      }

      // 3. ESTRATÉGIA PARA APPS COMPLEXOS (GODOT) -> Com argumentos
      // runInShell: false previne a janela preta do CMD no Windows.
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

    final folders = ['Ainimonia', 'GODOT', 'TRENCH', 'BLOCK'];

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
