import 'package:flutter/material.dart';
import '../models/note.dart';

class NoteListItem extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final bool isSelected;

  const NoteListItem({
    super.key,
    required this.note,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  State<NoteListItem> createState() => _NoteListItemState();
}

class _NoteListItemState extends State<NoteListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.only(
            left: _isHovered ? 8.0 : 0.0,
            right: 8.0,
            top: 24.0,
            bottom: 24.0,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.05)
                : _isHovered
                ? theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.05,
                  )
                : Colors.transparent,
            border: Border(
              left: widget.isSelected
                  ? BorderSide(
                      color: theme.colorScheme.primaryContainer,
                      width: 3.0,
                    )
                  : BorderSide.none,
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category / Label Tag
                    Text(
                      '# ${widget.note.label.toUpperCase()}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.secondaryContainer,
                        fontSize: 10.0,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    // Title
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: theme.textTheme.headlineMedium!.copyWith(
                        color: (widget.isSelected || _isHovered)
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      child: Text(widget.note.title),
                    ),
                    const SizedBox(height: 4.0),
                    // Relative Time
                    Text(
                      widget.note.relativeTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    // Snippet description
                    Text(
                      widget.note.plainTextSnippet.isEmpty
                          ? '(Empty Note)'
                          : widget.note.plainTextSnippet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
