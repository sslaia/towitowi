import 'package:flutter/material.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final double height;
  final bool border;

  const TopBar({
    super.key,
    this.title = 'TowiTowi',
    this.leading,
    this.actions,
    this.height = 64.0,
    this.border = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: border
            ? Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.2,
                  ),
                  width: 1.0,
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title and leading button (usually back or menu)
              Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 16.0),
                  ],
                  Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primaryContainer,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
              // Action buttons on the right
              if (actions != null)
                Row(mainAxisSize: MainAxisSize.min, children: actions!),
            ],
          ),
        ),
      ),
    );
  }
}
