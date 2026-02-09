import 'package:flutter/material.dart';
import '../../services/localization_service.dart';

class PathSelector extends StatelessWidget {
  final String path;
  final VoidCallback onSelectPath;

  const PathSelector({
    super.key,
    required this.path,
    required this.onSelectPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_open,
              size: 20, color: Colors.blueGrey.withValues(alpha: 0.8)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              path,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'JetBrains Mono', // Ensure mono for paths
                  color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: onSelectPath,
            icon: const Icon(Icons.edit, size: 14),
            label: Text(Localization.t('change_path')),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF38BDF8),
            ),
          ),
        ],
      ),
    );
  }
}
