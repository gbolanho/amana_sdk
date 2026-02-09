import 'package:flutter/material.dart';
import '../../models/sdk_task.dart';
import '../../services/localization_service.dart';
import '../widgets/tool_card.dart';

class StudioTab extends StatelessWidget {
  final List<SDKTask> tasks;
  final Function(SDKTask, {List<String> extraArgs}) onLaunch;
  final bool dependenciesReady;

  const StudioTab({
    super.key, 
    required this.tasks, 
    required this.onLaunch,
    required this.dependenciesReady,
  });

  @override
  Widget build(BuildContext context) {
    // Categorize tasks
    final mainShortcuts = tasks.where((t) => t.name == "Ainimonia" || t.name == "GODOT").toList();
    final tools = tasks.where((t) => !mainShortcuts.contains(t)).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Localization.t('studio_top_category')),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 2.2,
            ),
            itemCount: mainShortcuts.length,
            itemBuilder: (context, index) => _buildTaskItem(mainShortcuts[index]),
          ),
          
          const SizedBox(height: 40),
          
          _buildSectionHeader(Localization.t('studio_tools_category')),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 tools side-by-side
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.5,
            ),
            itemCount: tools.length,
            itemBuilder: (context, index) => _buildTaskItem(tools[index]),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 24, color: const Color(0xFF38BDF8)),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        ),
      ],
    );
  }

  Widget _buildTaskItem(SDKTask task) {
    bool isAinimonia = task.name == "Ainimonia";
    return ToolCard(
      task: task,
      isEnabled: isAinimonia ? dependenciesReady : task.isInstalled,
      onLaunch: () => onLaunch(task),
      onLaunchEditor: () => onLaunch(task, extraArgs: ['-e']),
      onLaunchGameArgs: (args) => onLaunch(task, extraArgs: args),
    );
  }
}
