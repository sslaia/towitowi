import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class BottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;
  final VoidCallback onCreatePressed;
  final VoidCallback onMenuPressed;

  const BottomBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onCreatePressed,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 80.0 + bottomPadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Nav buttons row
          Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Left Items: Menu & Library
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      InkWell(
                        onTap: onMenuPressed,
                        borderRadius: BorderRadius.circular(16.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          child: SizedBox(
                            height: 44.0,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.menu_rounded,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                  size: 24.0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _buildNavItem(
                        index: 0,
                        icon: Icons.auto_stories_outlined,
                        activeIcon: Icons.auto_stories,
                        label: 'nav.library'.tr(),
                        theme: theme,
                      ),
                    ],
                  ),
                ),
                // Gap for FAB
                const SizedBox(width: 80.0),
                // Right Items: Search & Bookmarks
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(
                        index: 1,
                        icon: Icons.search_outlined,
                        activeIcon: Icons.search,
                        label: 'nav.search'.tr(),
                        theme: theme,
                      ),
                      _buildNavItem(
                        index: 2,
                        icon: Icons.bookmark_border_rounded,
                        activeIcon: Icons.bookmark_rounded,
                        label: 'nav.bookmarks'.tr(),
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Central FAB (Creating new note)
          Positioned(
            top: -24.0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 64.0,
                height: 64.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.brightness == Brightness.dark
                      ? Colors.black
                      : theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      blurRadius: 20.0,
                      spreadRadius: 2.0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4.0), // Black border wrapper
                child: Material(
                  color: theme.colorScheme.primaryContainer,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onCreatePressed,
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: Icon(
                        Icons.add,
                        size: 32.0,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required ThemeData theme,
  }) {
    final isActive = currentIndex == index;
    final color = isActive
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return InkWell(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(16.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: SizedBox(
          height: 44.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isActive ? activeIcon : icon, color: color, size: 24.0),
              if (isActive) ...[
                const SizedBox(height: 4.0),
                Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
