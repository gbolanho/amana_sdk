import 'package:flutter/material.dart';
import '../../models/sdk_task.dart';
import '../../services/localization_service.dart';
import 'glass_card.dart';

class ToolCard extends StatefulWidget {
  final SDKTask task;
  final bool isEnabled;
  final VoidCallback onLaunch;
  final VoidCallback? onLaunchEditor; // Only for Ainimonia
  final Function(List<String>)? onLaunchGameArgs; // Launch details

  const ToolCard({
    super.key,
    required this.task,
    this.isEnabled = true,
    required this.onLaunch,
    this.onLaunchEditor,
    this.onLaunchGameArgs,
  });

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isAinimonia = widget.task.name == "Ainimonia";

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = widget.isEnabled && true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Opacity(
        opacity: widget.isEnabled ? 1.0 : 0.4,
        child: GlassCard(
          isHovered: _isHovered,
          padding: EdgeInsets.zero, // Handle padding internally for responsiveness
          onTap: (isAinimonia || !widget.isEnabled) ? null : widget.onLaunch,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate dynamic scaling based on height
              final h = constraints.maxHeight;
              final isSmall = h < 200;
              final padding = isSmall ? 8.0 : 16.0;
              
              return Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: EdgeInsets.all(isSmall ? 4.0 : 8.0),
                        child: Image.asset(
                          widget.task.iconPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(height: isSmall ? 4 : 10),
                    // Title
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.task.name,
                        style: TextStyle(
                          fontSize: isSmall ? 16 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.9),
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: widget.task.color.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isSmall ? 2 : 5),
                    // Description
                    if (h > 120) // Hide description if very small
                      Text(
                        Localization.t(widget.task.descriptionKey),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: isSmall ? 9 : 10,
                            color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    SizedBox(height: isSmall ? 8 : 15),
                    
                    // Buttons
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: isAinimonia
                          ? _buildAinimoniaButtons(isSmall)
                          : _buildButton(
                              label: widget.isEnabled ? "LAUNCH" : "NOT INSTALLED",
                              icon: widget.isEnabled ? Icons.rocket_launch : Icons.sync_problem,
                              color: widget.isEnabled ? widget.task.color : Colors.white24,
                              onTap: widget.isEnabled ? widget.onLaunch : () {},
                              isFullWidth: true,
                              isSmall: isSmall,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAinimoniaButtons(bool isSmall) {
    return Row(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
          _buildButton(
            label: widget.isEnabled ? "LAUNCH GAME" : "SETUP REQUIRED",
            icon: widget.isEnabled ? Icons.play_arrow : Icons.lock,
            color: widget.isEnabled ? Colors.greenAccent : Colors.white24,
            onTap: widget.isEnabled ? widget.onLaunch : () {},
            isSmall: isSmall,
          ),
          if (widget.isEnabled) ...[
            const SizedBox(width: 8),
            _buildButton(
              label: "EDITOR",
              icon: Icons.edit,
              color: Colors.blueAccent,
              onTap: widget.onLaunchEditor ?? () {},
              isSmall: isSmall,
            ),
          ],
          if (widget.onLaunchGameArgs != null && widget.isEnabled)
            PopupMenuButton<List<String>>(
              icon: Icon(Icons.settings,
                  color: Colors.white.withValues(alpha: 0.3), size: isSmall ? 14 : 16),
              tooltip: "Advanced Launch Options",
              onSelected: widget.onLaunchGameArgs,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: ["--windowed", "--resolution", "1280x720"],
                  child: Text("Windowed 720p"),
                ),
                const PopupMenuItem(
                  value: ["--fullscreen"],
                  child: Text("Fullscreen"),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: ["--verbose"],
                  child: Text("Verbose Output (Debug)"),
                ),
                const PopupMenuItem(
                  value: ["--debug-collisions"],
                  child: Text("Show Collisions (Debug)"),
                ),
                const PopupMenuItem(
                   value: ["--rendering-driver", "opengl3"],
                   child: Text("Force OpenGL 3"),
                ),
              ],
            ),
       ],
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
    bool isSmall = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: isFullWidth 
          ? EdgeInsets.symmetric(horizontal: isSmall ? 20 : 40, vertical: isSmall ? 4 : 8) 
          : EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: isSmall ? 4 : 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isSmall ? 12 : 14, color: color),
            SizedBox(width: isSmall ? 4 : 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmall ? 10 : 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
