import 'package:flutter/material.dart';
import '../../models/sdk_task.dart';
import '../../services/localization_service.dart';
import '../widgets/task_row.dart';
import '../widgets/path_selector.dart';

class MaintenanceTab extends StatelessWidget {
  final List<SDKTask> tasks;
  final String rootPath;
  final VoidCallback onSelectPath;
  final VoidCallback onSync;
  final bool isSyncing;
  final bool isTokenValid;

  const MaintenanceTab({
    super.key,
    required this.tasks,
    required this.rootPath,
    required this.onSelectPath,
    required this.onSync,
    required this.isSyncing,
    required this.isTokenValid,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PathSelector(path: rootPath, onSelectPath: onSelectPath),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              return TaskRow(task: tasks[index]);
            },
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: (isTokenValid && !isSyncing)
                  ? const Color(0xFF38BDF8)
                  : Colors.white10,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: isSyncing ? 0 : 5,
            ),
            onPressed: (isTokenValid && !isSyncing) ? onSync : null,
            child: isSyncing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Text(
                        Localization.t('syncing_btn'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : Text(
                    Localization.t('sync_btn'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }
}
