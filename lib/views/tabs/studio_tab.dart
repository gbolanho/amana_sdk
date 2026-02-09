import 'package:flutter/material.dart';
import '../../models/sdk_task.dart';
import '../widgets/tool_card.dart';

class StudioTab extends StatelessWidget {
  final List<SDKTask> tasks;
  final Function(SDKTask, {List<String> extraArgs}) onLaunch;

  const StudioTab({super.key, required this.tasks, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    // We assume a 2x2 layout is desired as per "always 2x2" request
    // We split tasks into two rows
    final row1 = tasks.take(2).toList();
    final row2 = tasks.skip(2).take(2).toList();

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < row1.length; i++) ...[
                Expanded(child: _buildTaskItem(row1[i])),
                if (i < row1.length - 1) const SizedBox(width: 20),
              ]
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < row2.length; i++) ...[
                Expanded(child: _buildTaskItem(row2[i])),
                if (i < row2.length - 1) const SizedBox(width: 20),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskItem(SDKTask task) {
    return ToolCard(
      task: task,
      onLaunch: () => onLaunch(task),
      onLaunchEditor: () => onLaunch(task, extraArgs: ['-e']),
      onLaunchGameArgs: (args) => onLaunch(task, extraArgs: args),
    );
  }
}
