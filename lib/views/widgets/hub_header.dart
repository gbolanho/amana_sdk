import 'package:flutter/material.dart';

class HubHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Map<String, int> usageData;

  const HubHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.usageData,
  });

  String _formatSize(int bytes) {
    if (bytes <= 0) return "0 MB";
    const gb = 1024 * 1024 * 1024;
    const mb = 1024 * 1024;
    
    if (bytes >= gb) {
      return "${(bytes / gb).toStringAsFixed(2)} GB";
    } else {
      return "${(bytes / mb).toStringAsFixed(0)} MB";
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalBytes = usageData['Total'] ?? 0;
    final formattedTotal = _formatSize(totalBytes);

    // Build breakdown string
    final breakdown = usageData.entries
        .where((e) => e.key != 'Total' && e.value > 0)
        .map((e) => "${e.key}: ${_formatSize(e.value)}")
        .join('\n');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 3,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "DISK USAGE",
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 4),
            Tooltip(
              message: breakdown.isEmpty ? "Calculating..." : breakdown,
              padding: const EdgeInsets.all(12),
              textStyle: const TextStyle(fontSize: 12, color: Colors.white),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: MouseRegion( // Add a cursor to indicate interactivity
                cursor: SystemMouseCursors.click,
                child: Text(
                  formattedTotal,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
