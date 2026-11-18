import 'package:flutter/material.dart';

class WorkspaceToolbar extends StatelessWidget {
  const WorkspaceToolbar({
    super.key,
    required this.child,
    this.surfaceKey,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final Key? surfaceKey;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      key: surfaceKey,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class WorkspaceFilterSection extends StatelessWidget {
  const WorkspaceFilterSection({
    super.key,
    required this.title,
    required this.description,
    required this.searchField,
    this.filters,
    this.footer,
    this.surfaceKey,
  });

  final String title;
  final String description;
  final Widget searchField;
  final Widget? filters;
  final Widget? footer;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return WorkspaceToolbar(
      surfaceKey: surfaceKey,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final heading = _buildHeading(theme, colors);
          final content = <Widget>[
            if (wide)
              Row(
                children: <Widget>[
                  Expanded(child: heading),
                  const SizedBox(width: 12),
                  SizedBox(width: 420, child: searchField),
                ],
              )
            else ...<Widget>[
              heading,
              const SizedBox(height: 2),
              searchField,
            ],
            if (filters != null) ...<Widget>[
              const SizedBox(height: 12),
              filters!,
            ],
            if (footer != null) ...<Widget>[
              const SizedBox(height: 8),
              footer!,
            ],
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: content,
          );
        },
      ),
    );
  }

  Widget _buildHeading(ThemeData theme, ColorScheme colors) => Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              width: 22,
              height: 22,
              child: Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              label: '$title. $description',
              child: Text(
                title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
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
