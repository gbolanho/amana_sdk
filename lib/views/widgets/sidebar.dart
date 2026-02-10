import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final int activeIndex;
  final Function(int) onTabSelected;
  final VoidCallback onSettings;

  const Sidebar({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Premium Floating App Logo
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/app_icon.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.apps, color: Color(0xFF38BDF8), size: 32),
            ),
          ),
          const SizedBox(height: 60),
          _SidebarItem(
            icon: Icons.dashboard_rounded,
            isActive: activeIndex == 0,
            onTap: () => onTabSelected(0),
          ),
          const SizedBox(height: 20),
          _SidebarItem(
            icon: Icons.build_circle_outlined,
            isActive: activeIndex == 1,
            onTap: () => onTabSelected(1),
          ),
          const SizedBox(height: 20),
          _SidebarItem(
            icon: Icons.info_outline,
            isActive: activeIndex == 2,
            onTap: () => onTabSelected(2),
          ),
          const Spacer(),
          IconButton(
            onPressed: onSettings,
            icon: Icon(
              Icons.settings,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            tooltip: "Settings",
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        width: 60,
        decoration: isActive
            ? const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFF38BDF8), width: 3),
                ),
              )
            : null,
        child: Icon(
          icon,
          color: isActive
              ? const Color(0xFF38BDF8)
              : Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
