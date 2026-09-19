import 'dart:async';

import 'package:touchin_flutter/core/theme/theme_mode_controller.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key, this.controller});

  final ThemeModeController? controller;

  ThemeModeController get _controller =>
      controller ?? ThemeModeController.instance;

  @override
  Widget build(BuildContext context) {
    return WorkspaceScaffold(
      sidebar: _buildSummaryPanel(context),
      contentBuilder: (context, isWide) => _buildWorkspace(context, isWide),
    );
  }

  Widget _buildSummaryPanel(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return WorkspaceSidebar(
          title: 'Aparência e tema.',
          description: 'Escolha entre tema claro, escuro ou seguir o sistema.',
          summaryChildren: <Widget>[
            WorkspaceSummaryStripe(
              label: 'Tema atual',
              value: _themeLabel(_controller.mode),
              helper: _themeHelper(_controller.mode),
            ),
            const WorkspaceSummaryStripe(
              label: 'Escopo',
              value: 'Global',
              helper: 'Ajuste aplicado em toda a interface.',
            ),
          ],
          highlightChips: <Widget>[
            const WorkspaceHighlightChip(label: 'Configuração global'),
            const WorkspaceHighlightChip(label: 'Persistida no dispositivo'),
          ],
        );
      },
    );
  }

  Widget _buildWorkspace(BuildContext context, bool isWide) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final padding = EdgeInsets.fromLTRB(
      isWide ? 32 : 24,
      isWide ? 32 : 24,
      isWide ? 32 : 24,
      isWide ? 40 : 32,
    );

    return Padding(
      padding: padding,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final currentMode = _controller.mode;
          final isLightMode = currentMode == ThemeMode.light;
          final isDarkMode = currentMode == ThemeMode.dark;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorkspaceHeader(
                title: 'Configurações',
                description:
                    'Ajuste preferências globais da interface e mantenha a experiência do jeito que preferir.',
              ),
              const SizedBox(height: 24),
              WorkspaceSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema da interface',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Escolha entre tema claro, escuro ou seguir a preferência do sistema.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    RadioListTile<ThemeMode>(
                      contentPadding: EdgeInsets.zero,
                      value: ThemeMode.light,
                      groupValue: currentMode,
                      onChanged: (value) {
                        if (value != null) {
                          unawaited(_controller.setThemeMode(value));
                        }
                      },
                      title: const Text('Tema claro'),
                      subtitle: const Text('Força a interface clara.'),
                    ),
                    RadioListTile<ThemeMode>(
                      contentPadding: EdgeInsets.zero,
                      value: ThemeMode.dark,
                      groupValue: currentMode,
                      onChanged: (value) {
                        if (value != null) {
                          unawaited(_controller.setThemeMode(value));
                        }
                      },
                      title: const Text('Tema escuro'),
                      subtitle: const Text('Força a interface escura.'),
                    ),
                    RadioListTile<ThemeMode>(
                      contentPadding: EdgeInsets.zero,
                      value: ThemeMode.system,
                      groupValue: currentMode,
                      onChanged: (value) {
                        if (value != null) {
                          unawaited(_controller.setThemeMode(value));
                        }
                      },
                      title: const Text('Seguir sistema'),
                      subtitle: const Text(
                        'Segue a preferência do dispositivo.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isLightMode
                            ? AppTheme.accent.withValues(alpha: 0.1)
                            : colorScheme.surfaceContainerHighest.withValues(
                                alpha: 0.72,
                              ),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isLightMode
                                ? Icons.wb_sunny_rounded
                                : isDarkMode
                                    ? Icons.nightlight_round_rounded
                                    : Icons.brightness_auto_rounded,
                            color: isLightMode
                                ? AppTheme.accent
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isLightMode
                                  ? 'O tema claro está ativo em todo o app.'
                                  : isDarkMode
                                      ? 'O tema escuro está ativo em todo o app.'
                                      : 'O app continuará acompanhando o tema configurado no sistema.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Escuro',
      ThemeMode.system => 'Sistema',
    };
  }

  String _themeHelper(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'Força a interface clara.',
      ThemeMode.dark => 'Força a interface escura.',
      ThemeMode.system => 'Segue a preferência do dispositivo.',
    };
  }
}
