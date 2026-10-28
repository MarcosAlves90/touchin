import 'package:flutter/material.dart';

class WorkspaceToolbar extends StatelessWidget {
  const WorkspaceToolbar({
    super.key,
    required this.child,
    this.surfaceKey,
  });

  final Widget child;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      key: surfaceKey,
      color: colorScheme.surface,
      shape: Border.all(color: colorScheme.outlineVariant),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

ButtonStyle workspaceToolbarActionStyle(ThemeData theme) => ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding:
          const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
      tapTargetSize: MaterialTapTargetSize.padded,
      iconSize: const WidgetStatePropertyAll(16),
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.labelMedium
            ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
