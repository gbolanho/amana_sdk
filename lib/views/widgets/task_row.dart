import 'package:flutter/material.dart';
import '../../models/sdk_task.dart';
import '../../services/localization_service.dart';

class TaskRow extends StatelessWidget {
  final SDKTask task;
  final String? fullPath;
  final VoidCallback? onSync;
  final bool isGlobalSyncing;

  const TaskRow({
    super.key, 
    required this.task,
    this.fullPath,
    this.onSync,
    this.isGlobalSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    bool isSyncEnabled = !isGlobalSyncing && !task.isDownloading && onSync != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.isDownloading
              ? task.color.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Image.asset(task.iconPath, width: 32, height: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      task.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: task.color.withValues(alpha: task.color == Colors.white ? 0.05 : 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: task.color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        task.version,
                        style: TextStyle(
                          color: task.color == Colors.white ? Colors.white70 : task.color, 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (task.isInstalled && !task.isDownloading)
                      Text(
                        task.diskSize,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                      ),
                  ],
                ),
                if (fullPath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      fullPath!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (task.isDownloading || (task.statusMessage.isNotEmpty && task.statusMessage != "Ready"))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.statusMessage,
                        style: TextStyle(
                          color: task.color,
                          fontSize: 12,
                        ),
                      ),
                      if (task.isDownloading) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: task.progress,
                            backgroundColor: Colors.white10,
                            color: task.color,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ],
                  )
                else
                  Text(
                    Localization.t(task.descriptionKey),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (onSync != null && task.name != "Ainimonia")
            IconButton(
              onPressed: isSyncEnabled ? onSync : null,
              icon: Icon(
                task.isDownloading ? Icons.sync : Icons.refresh,
                color: isSyncEnabled ? task.color : Colors.white10,
                size: 20,
              ),
              tooltip: "Re-sync (Preserves Config)",
            ),
          if (task.isCompleted && !task.isDownloading)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(Icons.check_circle, color: task.color, size: 20),
            ),
        ],
      ),
    );
  }
}
