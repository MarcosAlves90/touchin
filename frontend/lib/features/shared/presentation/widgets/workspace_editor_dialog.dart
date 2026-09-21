import 'package:flutter/material.dart';

class WorkspaceEditorDialog extends StatelessWidget {
  const WorkspaceEditorDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.secondaryLabel = 'Cancelar',
    this.onSecondary,
    this.maxWidth = 640,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final IconData? primaryIcon;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewport = MediaQuery.sizeOf(context);
    final compact = viewport.width < 600;

    void close() {
      if (onSecondary != null) {
        onSecondary!();
      } else {
        Navigator.of(context).pop();
      }
    }

    final cancel = TextButton(
      onPressed: close,
      child: Text(secondaryLabel),
    );
    final submitStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 46),
    );
    final submit = primaryIcon == null
        ? FilledButton(
            style: submitStyle,
            onPressed: onPrimary,
            child: Text(primaryLabel),
          )
        : FilledButton.icon(
            style: submitStyle,
            onPressed: onPrimary,
            icon: Icon(primaryIcon, size: 18),
            label: Text(primaryLabel),
          );

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 24,
        vertical: compact ? 12 : 24,
      ),
      elevation: 0,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      clipBehavior: Clip.hardEdge,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: viewport.height - (compact ? 24 : 48),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(height: 4, color: colorScheme.primary),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 22,
                compact ? 14 : 18,
                compact ? 12 : 18,
                compact ? 12 : 16,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(icon, color: colorScheme.primary, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    visualDensity: VisualDensity.compact,
                    onPressed: close,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(compact ? 16 : 22),
                child: child,
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 18,
                10,
                compact ? 12 : 18,
                compact ? 12 : 14,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 420) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        submit,
                        const SizedBox(height: 4),
                        cancel,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      cancel,
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 150),
                        child: submit,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
