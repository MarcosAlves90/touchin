part of 'auth_shell.dart';

class AuthFormFrame extends StatelessWidget {
  const AuthFormFrame({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 920;
    final compactShort = compact && MediaQuery.sizeOf(context).height < 700;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 32,
          vertical: compactShort ? 12 : 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              const AuthCompactBrandBadge(key: Key('auth-mobile-masthead')),
              SizedBox(height: compactShort ? 8 : 24),
            ],
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: Color.lerp(Theme.of(context).scaffoldBackgroundColor,
                  colors.surfaceContainerHighest, 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: EdgeInsets.all(compactShort
                    ? 12
                    : compact
                        ? 20
                        : 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PORTAL CORPORATIVO',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        )),
                    SizedBox(height: compactShort ? 8 : 20),
                    child,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: colors.onSurfaceVariant, size: 17),
                const SizedBox(width: 9),
                Expanded(
                    child: Text('TOUCHIN  /  ÁREA EMPRESARIAL',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            letterSpacing: 1.0))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AuthPageHeading extends StatelessWidget {
  const AuthPageHeading({
    super.key,
    required this.title,
    this.onBack,
  });

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    if (onBack == null) {
      return WorkspaceHeader(title: title, description: '');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Voltar',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: WorkspaceHeader(title: title, description: ''),
        ),
      ],
    );
  }
}

class AuthPasswordVisibilityButton extends StatelessWidget {
  const AuthPasswordVisibilityButton({
    super.key,
    required this.isObscured,
    required this.fieldName,
    required this.onPressed,
  });

  final bool isObscured;
  final String fieldName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '${isObscured ? 'Mostrar' : 'Ocultar'} $fieldName',
      onPressed: onPressed,
      icon: Icon(
        isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }
}

class AuthFormValidationMessage extends StatelessWidget {
  const AuthFormValidationMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          'Confira os campos destacados e tente novamente.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

class AuthSubmissionIndicator extends StatelessWidget {
  const AuthSubmissionIndicator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
