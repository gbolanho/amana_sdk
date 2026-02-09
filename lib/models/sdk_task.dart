import 'package:flutter/material.dart';

class SDKTask {
  final String name;
  final String descriptionKey;
  final String iconPath;
  final Color color;
  final String? repoUrl;
  final String? downloadUrl;
  final String? executablePath; // Caminho relativo ao rootPath/FOLDER/
  final String version;
  String diskSize;

  double progress;
  bool isCompleted;
  bool isDownloading;
  bool isInstalled;
  String statusMessage;

  SDKTask({
    required this.name,
    required this.descriptionKey,
    required this.iconPath,
    required this.color,
    this.version = "Unknown",
    this.diskSize = "0 MB",
    this.repoUrl,
    this.downloadUrl,
    this.executablePath,
    this.progress = 0.0,
    this.isCompleted = false,
    this.isDownloading = false,
    this.isInstalled = false,
    this.statusMessage = "",
  });
}
