import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  const PaginationControls({
    super.key,
    required this.page,
    required this.totalPages,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    this.previousLabel = 'Anterior',
    this.nextLabel = 'Próxima',
  });

  final int page;
  final int totalPages;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String previousLabel;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final buttonStyle = FilledButton.styleFrom(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        final buttonGap = isCompact ? 6.0 : 8.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Página $page de $totalPages',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: buttonStyle,
                    onPressed: hasPrevious ? onPrevious : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: Text(previousLabel),
                  ),
                ),
                SizedBox(width: buttonGap),
                Expanded(
                  child: FilledButton.icon(
                    style: buttonStyle,
                    onPressed: hasNext ? onNext : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: Text(nextLabel),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
