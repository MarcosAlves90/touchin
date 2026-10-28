import 'package:flutter/material.dart';

class AccessibilityTools extends StatefulWidget {
  const AccessibilityTools({super.key, required this.child});

  final Widget child;

  @override
  State<AccessibilityTools> createState() => _AccessibilityToolsState();
}

class _AccessibilityToolsState extends State<AccessibilityTools> {
  double _textScale = 1;
  bool _reduceAnimations = false;
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(media.textScaler.scale(1) * _textScale),
        disableAnimations: media.disableAnimations || _reduceAnimations,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: <Widget>[
            widget.child,
            Align(
              alignment: Alignment.bottomRight,
              child: SafeArea(
                minimum: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (_isOpen) ...<Widget>[
                      SizedBox(
                        width: constraints.maxWidth < 384
                            ? constraints.maxWidth - 24
                            : 360,
                        child: _buildPanel(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Semantics(
                      container: true,
                      explicitChildNodes: true,
                      button: true,
                      label: _isOpen ? 'Fechar acessibilidade' : 'Acessibilidade',
                      onTap: () => setState(() => _isOpen = !_isOpen),
                      child: ExcludeSemantics(
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton.filledTonal(
                            tooltip: null,
                            icon: Icon(
                              _isOpen
                                  ? Icons.close_rounded
                                  : Icons.accessibility_new_rounded,
                            ),
                            onPressed: () => setState(() => _isOpen = !_isOpen),
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

  Widget _buildPanel() {
    return Card(
      key: const ValueKey<String>('accessibility-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                'Acessibilidade',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Tamanho do texto'),
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Reduzir texto',
                  onPressed: _textScale <= 0.8
                      ? null
                      : () => _updateTextScale(-0.1),
                  icon: const Icon(Icons.text_decrease),
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    label: 'Tamanho do texto: ${(_textScale * 100).round()}%',
                    child: Text(
                      '${(_textScale * 100).round()}%',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Aumentar texto',
                  onPressed: _textScale >= 1.4
                      ? null
                      : () => _updateTextScale(0.1),
                  icon: const Icon(Icons.text_increase),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reduzir animações'),
              value: _reduceAnimations,
              onChanged: (value) => setState(() => _reduceAnimations = value),
            ),
            TextButton(
              onPressed: () => setState(() {
                _textScale = 1;
                _reduceAnimations = false;
              }),
              child: const Text('Restaurar padrão'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateTextScale(double adjustment) {
    setState(() => _textScale = (_textScale + adjustment).clamp(0.8, 1.4));
  }
}
