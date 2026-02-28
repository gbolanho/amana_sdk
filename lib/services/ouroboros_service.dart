import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// OuroborosService handles the self-update lifecycle for the AMANA SDK.
/// It checks for updates on GitHub, downloads assets, and performs self-replacement.
class OuroborosService {
  final Dio _dio = Dio();
  final String repoOwner = 'gbolanho';
  final String repoName = 'amana_sdk';

  /// Checks if a newer version is available on GitHub.
  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );

      if (response.statusCode == 200) {
        final latestTag = response.data['tag_name'] as String;
        final currentVersion = await _getCurrentVersion();

        if (_isVersionNewer(currentVersion, latestTag)) {
          final assets = response.data['assets'] as List;
          final platformAsset = _findAssetForPlatform(assets);

          if (platformAsset != null) {
            return {
              'version': latestTag,
              'url': platformAsset['browser_download_url'],
              'name': platformAsset['name'],
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return null;
  }

  /// Downloads the update asset.
  Future<String?> downloadUpdate(
    String url,
    String fileName, {
    required Function(double) onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = p.join(tempDir.path, fileName);

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      return savePath;
    } catch (e) {
      debugPrint('Error downloading update: $e');
      return null;
    }
  }

  /// Applies the update by replacing the current executable.
  Future<void> applyUpdate(String downloadedFilePath) async {
    final currentExecutable = Platform.resolvedExecutable;
    
    if (Platform.isWindows) {
      await _applyWindowsUpdate(currentExecutable, downloadedFilePath);
    } else if (Platform.isLinux) {
      await _applyLinuxUpdate(currentExecutable, downloadedFilePath);
    }
  }

  Future<void> _applyWindowsUpdate(String currentExe, String newFile) async {
    final oldExe = '$currentExe.old';
    final oldFile = File(oldExe);

    // 1. Rename current to .old (Windows allows renaming even if in use)
    if (oldFile.existsSync()) {
      oldFile.deleteSync();
    }
    
    File(currentExe).renameSync(oldExe);

    // 2. Move new file to original location
    // If it's a zip, we should probably extract it first, but for single-file binaries:
    if (newFile.endsWith('.exe')) {
      File(newFile).copySync(currentExe);
    } else if (newFile.endsWith('.zip')) {
      // Integration with Archive might be needed if the release is a ZIP
      // For now, assuming binary or handling based on extension
    }

    // 3. Restart the app
    await Process.start(currentExe, [], mode: ProcessStartMode.detached);
    exit(0);
  }

  Future<void> _applyLinuxUpdate(String currentExe, String newFile) async {
    // Linux strategy: Just replace it (if permissions allow)
    // Most AppImages or binaries can be replaced while running as long as they are not locked
    final file = File(newFile);
    await file.copy(currentExe);
    await Process.run('chmod', ['+x', currentExe]);

    await Process.start(currentExe, [], mode: ProcessStartMode.detached);
    exit(0);
  }

  Future<String> _getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  bool _isVersionNewer(String current, String latest) {
    // Clean tags like 'v1.1.0' to '1.1.0'
    final cleanLatest = latest.startsWith('v') ? latest.substring(1) : latest;
    
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> latestParts = cleanLatest.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      int c = i < currentParts.length ? currentParts[i] : 0;
      int l = i < latestParts.length ? latestParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  Map<String, dynamic>? _findAssetForPlatform(List assets) {
    if (Platform.isWindows) {
      return assets.firstWhere(
        (a) => (a['name'] as String).endsWith('.exe') || (a['name'] as String).contains('windows'),
        orElse: () => null,
      );
    } else if (Platform.isLinux) {
      return assets.firstWhere(
        (a) => (a['name'] as String).endsWith('.AppImage') || (a['name'] as String).contains('linux'),
        orElse: () => null,
      );
    }
    return null;
  }
}
