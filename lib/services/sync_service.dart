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

  // Lança o executável com Abordagem Híbrida (Shell Nativo vs Processo Detachado)
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
      // ESTRATÉGIA 1: Apps Simples (BLOCK, TRENCH) -> Sem argumentos
      // Usamos url_launcher para invocar o Shell Nativo do Windows.
      // Isso resolve automaticamente o Working Directory e previne janelas de CMD/Console.
      if (args.isEmpty) {
        print("[SyncService] Using url_launcher (Shell Execute)...");
        final uri = Uri.file(cleanPath);
        if (!await launchUrl(uri)) {
          throw "Could not launch $cleanPath via Shell";
        }
        return;
      }

      // ESTRATÉGIA 2: Apps Complexos (GODOT) -> Com argumentos
      // Usamos Process.start para ter controle exato dos argumentos passed.
      // runInShell: false previne a janela preta do CMD.
      // mode: detached garante que o processo sobreviva ao fechamento do Hub.
      print("[SyncService] Using Process.start (Detached)...");
      await Process.start(
        cleanPath,
        args,
        workingDirectory: workingDir,
        runInShell: false, // Vital para evitar janela de console no Godot
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
