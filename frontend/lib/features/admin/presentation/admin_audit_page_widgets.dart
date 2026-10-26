import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

String auditLocalDate(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year}';
}

String auditLocalTime(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
}

String auditLocalDateTime(DateTime value) =>
    '${auditLocalDate(value)} ${auditLocalTime(value)}';

String auditUtcTimestamp(DateTime value) {
  final utc = value.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${_two(utc.month)}-${_two(utc.day)}T'
      '${_two(utc.hour)}:${_two(utc.minute)}:${_two(utc.second)}Z';
}

String auditEntityLabel(String value) {
  return const <String, String>{
        'card': 'Tarefa',
        'project': 'Projeto',
        'employee': 'Funcionário',
        'kanban_column': 'Coluna do Kanban',
        'user': 'Usuário',
        'company': 'Empresa',
        'time_clock': 'Registro de ponto',
        'punch': 'Batida',
      }[value] ??
      value;
}

String auditMetadataText(Map<String, dynamic>? payload) {
  if (payload == null || payload.isEmpty) return '';
  return const JsonEncoder.withIndent('  ').convert(payload);
}

String _two(int value) => value.toString().padLeft(2, '0');

class AuditResultVisual {
  const AuditResultVisual({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.container,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color container;
}

AuditResultVisual auditResultVisual(
  ThemeData theme,
  String result,
  String Function(String value) labelFor,
) {
  final colors = AppTheme.adminColors(theme);
  final normalized = result.toLowerCase();
  final tone = switch (normalized) {
    'success' || 'succeeded' => colors.success,
    'failed' || 'failure' || 'error' => colors.danger,
    'warning' || 'warn' => colors.warning,
    _ => colors.neutral,
  };
  final icon = switch (normalized) {
    'success' || 'succeeded' => Icons.check_circle_outline_rounded,
    'failed' || 'failure' || 'error' => Icons.error_outline_rounded,
    'warning' || 'warn' => Icons.warning_amber_rounded,
    _ => Icons.info_outline_rounded,
  };
  return AuditResultVisual(
    label: labelFor(result),
    icon: icon,
    foreground: tone.foreground,
    container: tone.container,
  );
}

class AuditResultBadge extends StatelessWidget {
  const AuditResultBadge({
    super.key,
    required this.result,
    required this.label,
  });

  final String result;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = auditResultVisual(theme, result, (_) => label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: visual.container,
        border: Border.all(color: visual.foreground.withValues(alpha: 0.48)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: 12, color: visual.foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              visual.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: visual.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuditTechnicalId extends StatelessWidget {
  const AuditTechnicalId({
    super.key,
    required this.value,
    required this.copyLabel,
    this.showCopyButton = true,
    this.maxLines = 1,
  });

  final String value;
  final String copyLabel;
  final bool showCopyButton;
  final int maxLines;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('$copyLabel copiado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final text = Tooltip(
      message: value,
      child: Text(
        value,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );

    if (!showCopyButton) return text;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: text),
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            onPressed: () => _copy(context),
            tooltip: 'Copiar $copyLabel',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ),
      ],
    );
  }
}

class AuditEventTableHeader extends StatelessWidget {
  const AuditEventTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget label(String text) => Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        );

    return Container(
      key: const ValueKey<String>('audit-table-header'),
      color: colors.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          SizedBox(width: 124, child: label('Data/hora (local)')),
          Expanded(flex: 5, child: label('Evento')),
          SizedBox(width: 100, child: label('Resultado')),
          Expanded(flex: 3, child: label('Ator')),
          Expanded(flex: 4, child: label('Recurso')),
          Expanded(flex: 2, child: label('Projeto')),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class AuditEventTableRow extends StatelessWidget {
  const AuditEventTableRow({
    super.key,
    required this.event,
    required this.actionLabel,
    required this.resultLabel,
    required this.onTap,
  });

  final AuditEventResponse event;
  final String actionLabel;
  final String resultLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visual = auditResultVisual(theme, event.result, (_) => resultLabel);
    final actor = event.actorUserId;

    return Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          focusColor: AppTheme.adminColors(theme)
              .selectedIndicator
              .withValues(alpha: 0.16),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: visual.foreground, width: 3),
                bottom: BorderSide(color: colors.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(11, 11, 14, 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 124,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auditLocalDate(event.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        auditLocalTime(event.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          event.action,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AuditResultBadge(
                      result: event.result,
                      label: resultLabel,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: AuditTechnicalId(
                      value: actor ?? 'Sistema',
                      copyLabel: 'ID do ator',
                      showCopyButton: false,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auditEntityLabel(event.entityType),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AuditTechnicalId(
                          value: event.entityId,
                          copyLabel: 'ID da entidade',
                          showCopyButton: false,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: AuditTechnicalId(
                      value: event.projectId ?? '—',
                      copyLabel: 'ID do projeto',
                      showCopyButton: false,
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuditEventCard extends StatelessWidget {
  const AuditEventCard({
    super.key,
    required this.event,
    required this.actionLabel,
    required this.resultLabel,
    required this.onTap,
  });

  final AuditEventResponse event;
  final String actionLabel;
  final String resultLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visual = auditResultVisual(theme, event.result, (_) => resultLabel);

    return Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          focusColor: AppTheme.adminColors(theme)
              .selectedIndicator
              .withValues(alpha: 0.16),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                left: BorderSide(color: visual.foreground, width: 4),
                top: BorderSide(color: colors.outlineVariant),
                right: BorderSide(color: colors.outlineVariant),
                bottom: BorderSide(color: colors.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    AuditResultBadge(
                      result: event.result,
                      label: resultLabel,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          auditLocalDateTime(event.timestamp),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  actionLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  event.action,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 12),
                _AuditCardMeta(
                  icon: Icons.person_outline_rounded,
                  label: 'Ator',
                  child: AuditTechnicalId(
                    value: event.actorUserId ?? 'Sistema',
                    copyLabel: 'ID do ator',
                  ),
                ),
                const SizedBox(height: 8),
                _AuditCardMeta(
                  icon: Icons.inventory_2_outlined,
                  label: 'Recurso',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auditEntityLabel(event.entityType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AuditTechnicalId(
                        value: event.entityId,
                        copyLabel: 'ID da entidade',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _AuditCardMeta(
                  icon: Icons.folder_outlined,
                  label: 'Projeto',
                  child: event.projectId == null
                      ? Text(
                          'Sem projeto',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        )
                      : AuditTechnicalId(
                          value: event.projectId!,
                          copyLabel: 'ID do projeto',
                        ),
                ),
                const SizedBox(height: 6),
                Divider(color: colors.outlineVariant),
                Row(
                  children: [
                    Text(
                      'Abrir detalhes',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuditCardMeta extends StatelessWidget {
  const _AuditCardMeta({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: colors.onSurfaceVariant),
        ),
        const SizedBox(width: 7),
        SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: child),
      ],
    );
  }
}

class AuditLoadingSkeleton extends StatelessWidget {
  const AuditLoadingSkeleton({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: 'Carregando eventos de auditoria',
      child: Padding(
        key: const ValueKey<String>('audit-loading-skeleton'),
        padding:
            EdgeInsets.fromLTRB(compact ? 16 : 24, 4, compact ? 16 : 24, 18),
        child: compact
            ? ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _AuditCardSkeleton(
                  color: colors.surfaceContainerHighest,
                ),
              )
            : Column(
                children: [
                  _AuditTableSkeletonHeader(
                    color: colors.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 1),
                  Expanded(
                    child: ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 6,
                      separatorBuilder: (_, __) => const SizedBox(height: 1),
                      itemBuilder: (_, index) => _AuditRowSkeleton(
                        color: colors.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AuditTableSkeletonHeader extends StatelessWidget {
  const _AuditTableSkeletonHeader({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          _AuditSkeletonBlock(width: 92, height: 12, color: color),
          const SizedBox(width: 22),
          _AuditSkeletonBlock(width: 120, height: 12, color: color),
          const Spacer(),
          _AuditSkeletonBlock(width: 68, height: 12, color: color),
          const SizedBox(width: 18),
          _AuditSkeletonBlock(width: 74, height: 12, color: color),
          const SizedBox(width: 18),
          _AuditSkeletonBlock(width: 92, height: 12, color: color),
        ],
      ),
    );
  }
}

class _AuditRowSkeleton extends StatelessWidget {
  const _AuditRowSkeleton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          _AuditSkeletonBlock(width: 78, height: 12, color: color),
          const SizedBox(width: 24),
          _AuditSkeletonBlock(width: 180, height: 14, color: color),
          const Spacer(),
          _AuditSkeletonBlock(width: 68, height: 22, color: color),
          const SizedBox(width: 18),
          _AuditSkeletonBlock(width: 80, height: 12, color: color),
          const SizedBox(width: 22),
          _AuditSkeletonBlock(width: 106, height: 12, color: color),
        ],
      ),
    );
  }
}

class _AuditCardSkeleton extends StatelessWidget {
  const _AuditCardSkeleton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AuditSkeletonBlock(width: 74, height: 22, color: color),
              const Spacer(),
              _AuditSkeletonBlock(width: 116, height: 12, color: color),
            ],
          ),
          const SizedBox(height: 14),
          _AuditSkeletonBlock(width: 190, height: 16, color: color),
          const SizedBox(height: 8),
          _AuditSkeletonBlock(width: 110, height: 10, color: color),
          const SizedBox(height: 16),
          _AuditSkeletonBlock(width: double.infinity, height: 12, color: color),
          const SizedBox(height: 8),
          _AuditSkeletonBlock(width: 220, height: 12, color: color),
        ],
      ),
    );
  }
}

class _AuditSkeletonBlock extends StatelessWidget {
  const _AuditSkeletonBlock({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color.withValues(alpha: 0.72)),
      ),
    );
  }
}

class AuditEventDetailsDialog extends StatelessWidget {
  const AuditEventDetailsDialog({
    super.key,
    required this.event,
    required this.actionLabel,
    required this.resultLabel,
    required this.onClose,
  });

  final AuditEventResponse event;
  final String actionLabel;
  final String resultLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visual = auditResultVisual(theme, event.result, (_) => resultLabel);
    final metadata = auditMetadataText(event.metadataPayload);

    Widget field(String label, Widget child) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      );
    }

    return Dialog(
      key: const ValueKey<String>('audit-event-details'),
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 600 ? 12 : 40,
        vertical: 24,
      ),
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outline),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                border: Border(
                  left: BorderSide(color: visual.foreground, width: 4),
                  bottom: BorderSide(color: colors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Icon(visual.icon, color: visual.foreground, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalhes do evento',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Consulte os dados técnicos registrados para este evento.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Fechar detalhes',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AuditResultBadge(
                          result: event.result,
                          label: resultLabel,
                        ),
                        Text(
                          auditLocalDateTime(event.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    field(
                      'Evento',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            actionLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.action,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    field(
                      'Ator',
                      AuditTechnicalId(
                        value: event.actorUserId ?? 'Sistema',
                        copyLabel: 'ID do ator',
                      ),
                    ),
                    field(
                      'Recurso',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auditEntityLabel(event.entityType),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          AuditTechnicalId(
                            value: event.entityId,
                            copyLabel: 'ID da entidade',
                          ),
                        ],
                      ),
                    ),
                    field(
                      'Projeto',
                      event.projectId == null
                          ? Text(
                              'Sem projeto associado.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            )
                          : AuditTechnicalId(
                              value: event.projectId!,
                              copyLabel: 'ID do projeto',
                            ),
                    ),
                    field(
                      'Registrado em (local)',
                      Text(
                        auditLocalDateTime(event.timestamp),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    field(
                      'Registrado em (UTC)',
                      Text(
                        auditUtcTimestamp(event.timestamp),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    field(
                      'ID do evento',
                      AuditTechnicalId(
                        value: event.id,
                        copyLabel: 'ID do evento',
                      ),
                    ),
                    if (event.correlationId != null)
                      field(
                        'Correlation ID',
                        AuditTechnicalId(
                          value: event.correlationId!,
                          copyLabel: 'Correlation ID',
                        ),
                      ),
                    Divider(color: colors.outlineVariant),
                    const SizedBox(height: 14),
                    Text(
                      'Metadados',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (metadata.isEmpty)
                      Text(
                        'Sem metadados adicionais.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            metadata,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
