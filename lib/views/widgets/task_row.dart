import 'package:flutter/material.dart';
import '../../models/sdk_task.dart';
import '../../services/localization_service.dart';

class TaskRow extends StatelessWidget {
  final SDKTask task;

  const TaskRow({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
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
                Text(
                  task.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (task.isDownloading)
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
          if (task.isCompleted && !task.isDownloading)
            Icon(Icons.check_circle, color: task.color, size: 20),
        ],
      ),
    );
  }
}
