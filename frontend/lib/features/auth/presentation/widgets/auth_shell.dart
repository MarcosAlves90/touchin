import 'package:flutter/material.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';

part 'auth_form_widgets.dart';

class AuthBrandImages {
  static const login = 'https://res.cloudinary.com/dgsywmzb2/image/upload/'
      'f_auto,q_auto:best,w_1920,c_limit/login_a7de1w.jpg';
  static const register = 'https://res.cloudinary.com/dgsywmzb2/image/upload/'
      'f_auto,q_auto:best,w_1920,c_limit/cadastro_q0zfus.jpg';
  static const forgotPassword =
      'https://res.cloudinary.com/dgsywmzb2/image/upload/'
      'f_auto,q_auto:best,w_1920,c_limit/recuperacao-de-senha_snzc6m.jpg';
  static const changePassword =
      'https://res.cloudinary.com/dgsywmzb2/image/upload/'
      'f_auto,q_auto:best,w_1920,c_limit/troca-obrigatoria-de-senha_apzwxa.jpg';
}

TextStyle? authPageTitleStyle(BuildContext context) {
  final theme = Theme.of(context);
  final isMobile = MediaQuery.sizeOf(context).width < 920;

  return (isMobile
          ? theme.textTheme.headlineMedium
          : theme.textTheme.headlineLarge)
      ?.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    height: 1.12,
  );
}

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.formPanel,
    required this.brandHeadline,
    required this.brandDescription,
    required this.brandTags,
    required this.brandImageUrl,
    required this.brandStep,
  });

  final Widget formPanel;
  final String brandHeadline;
  final String brandDescription;
  final List<String> brandTags;
  final String brandImageUrl;
  final String brandStep;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 920;
            if (!isWide) {
              return _AuthFormStage(child: formPanel);
            }

            return Row(
              children: [
                Expanded(
                  flex: 40,
                  child: _AuthBrandPanel(
                    headline: brandHeadline,
                    description: brandDescription,
                    tags: brandTags,
                    imageUrl: brandImageUrl,
                    step: brandStep,
                  ),
                ),
                Expanded(
                  flex: 60,
                  child: _AuthFormStage(child: formPanel),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AuthFormStage extends StatelessWidget {
  const _AuthFormStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      key: const Key('auth-form-stage'),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Row(
            children: [
              Container(height: 3, width: 76, color: colors.primary),
              Expanded(
                child: Container(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthCompactBrandBadge extends StatelessWidget {
  const AuthCompactBrandBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 42,
          width: 42,
          alignment: Alignment.center,
          color: colors.primary,
          child: Icon(
            Icons.fingerprint_rounded,
            color: colors.onPrimary,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TOUCHIN',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: colors.onSurface,
              ),
            ),
            Text(
              'WORKSPACE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel({
    required this.headline,
    required this.description,
    required this.tags,
    required this.imageUrl,
    required this.step,
  });

  final String headline;
  final String description;
  final List<String> tags;
  final String imageUrl;
  final String step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      key: const Key('auth-editorial-hero'),
      decoration: BoxDecoration(
        color: Color.lerp(
            theme.scaffoldBackgroundColor, colors.surfaceContainerHighest, 0.5),
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuthCompactBrandBadge(),
                  const SizedBox(height: 64),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: Image.network(imageUrl,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (context, error, stackTrace) =>
                              ColoredBox(color: colors.surfaceContainerHigh)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(headline,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Text(description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant, height: 1.5)),
                  const SizedBox(height: 24),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final tag in tags)
                      Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact),
                  ]),
                  const SizedBox(height: 32),
                  Text('$step  /  04',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colors.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
