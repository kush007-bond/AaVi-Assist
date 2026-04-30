import 'package:flutter/material.dart';
import '../app_theme.dart';

enum NavTab { home, roomMap, settings }

class AppBottomNavBar extends StatelessWidget {
  final NavTab current;
  final ValueChanged<NavTab> onTap;

  const AppBottomNavBar({
    super.key,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 2)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            filledIcon: Icons.home,
            label: 'HOME',
            active: current == NavTab.home,
            onTap: () => onTap(NavTab.home),
          ),
          _NavItem(
            icon: Icons.layers_outlined,
            filledIcon: Icons.layers,
            label: 'ROOM MAP',
            active: current == NavTab.roomMap,
            onTap: () => onTap(NavTab.roomMap),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            filledIcon: Icons.settings,
            label: 'SETTINGS',
            active: current == NavTab.settings,
            onTap: () => onTap(NavTab.settings),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData filledIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.filledIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minWidth: 60, minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? filledIcon : icon,
              color: active ? Colors.white : const Color(0xFF64748B),
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PublicSans',
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.8,
                color: active ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
