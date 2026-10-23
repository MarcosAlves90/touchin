import 'dart:ui';

import 'package:flutter/material.dart';

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
                  flex: 53,
                  child: _AuthBrandPanel(
                    headline: brandHeadline,
                    description: brandDescription,
                    tags: brandTags,
                    imageUrl: brandImageUrl,
                    step: brandStep,
                  ),
                ),
                Expanded(
                  flex: 47,
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

  static const _amber = Color(0xFFFFB020);
  static const _ivory = Color(0xFFF8F4E9);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 580;
        final inset = narrow ? 34.0 : 54.0;

        return Container(
          key: const Key('auth-editorial-hero'),
          color: const Color(0xFF201914),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Transform.scale(
                      scale: 1.06,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        excludeFromSemantics: true,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.38, 0.72, 1.0],
                      colors: [
                        Color(0xBF15100D),
                        Color(0x775F3417),
                        Color(0xC61F1813),
                        Color(0xF2161513),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        _amber.withValues(alpha: 0.28),
                        Colors.transparent,
                        const Color(0xFF0F0E0D).withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child:
                    Container(width: 1, color: _ivory.withValues(alpha: 0.14)),
              ),
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(inset, 42, inset, 44),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 42,
                              width: 42,
                              color: _amber,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.fingerprint_rounded,
                                size: 23,
                                color: Color(0xFF24170B),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TOUCHIN',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      color: _ivory,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                  Text(
                                    'WORKSPACE',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: _ivory.withValues(alpha: 0.64),
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$step  /  04',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _ivory.withValues(alpha: 0.76),
                                letterSpacing: 2.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(width: 29, height: 3, color: _amber),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    'SEU ESPAÇO DE OPERAÇÃO',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: _amber,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Text(
                              headline,
                              style: theme.textTheme.displayMedium?.copyWith(
                                color: _ivory,
                                fontSize: narrow ? 36 : 46,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.8,
                                height: 1.09,
                              ),
                            ),
                            const SizedBox(height: 22),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 500),
                              child: Text(
                                description,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: _ivory.withValues(alpha: 0.83),
                                  height: 1.6,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 34),
                            Container(
                                height: 1,
                                color: _ivory.withValues(alpha: 0.22)),
                            const SizedBox(height: 22),
                            Wrap(
                              spacing: 9,
                              runSpacing: 9,
                              children: [
                                for (final tag in tags)
                                  _AuthHighlightTag(label: tag)
                              ],
                            ),
                            const SizedBox(height: 29),
                            Text(
                              'TOUCHIN  /  PLATAFORMA CORPORATIVA',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _ivory.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuthHighlightTag extends StatelessWidget {
  const _AuthHighlightTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF11100D).withValues(alpha: 0.23),
        border:
            Border.all(color: const Color(0xFFF8F4E9).withValues(alpha: 0.27)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: const Color(0xFFF8F4E9),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
