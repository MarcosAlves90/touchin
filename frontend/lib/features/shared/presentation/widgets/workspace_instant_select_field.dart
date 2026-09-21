import 'package:flutter/material.dart';

class WorkspaceSelectOption<T> {
  const WorkspaceSelectOption({required this.value, required this.label});

  final T value;
  final String label;
}

class WorkspaceInstantSelectField<T> extends StatefulWidget {
  const WorkspaceInstantSelectField({
    super.key,
    required this.value,
    required this.options,
    required this.decoration,
    required this.onChanged,
  });

  final T? value;
  final List<WorkspaceSelectOption<T>> options;
  final InputDecoration decoration;
  final ValueChanged<T?>? onChanged;

  @override
  State<WorkspaceInstantSelectField<T>> createState() =>
      _WorkspaceInstantSelectFieldState<T>();
}

class _WorkspaceInstantSelectFieldState<T>
    extends State<WorkspaceInstantSelectField<T>> {
  final GlobalKey _anchorKey = GlobalKey();
  bool _menuOpen = false;

  bool get _enabled => widget.onChanged != null && widget.options.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = _selectedOption();

    return Semantics(
      button: true,
      enabled: _enabled,
      expanded: _menuOpen,
      label: widget.decoration.labelText,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: InkWell(
          key: _anchorKey,
          onTap: _enabled ? _openMenu : null,
          child: InputDecorator(
            isEmpty: selected == null,
            isFocused: _menuOpen,
            decoration: widget.decoration.copyWith(
              enabled: _enabled,
              suffixIcon: Icon(
                _menuOpen
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                color: _enabled
                    ? colorScheme.onSurfaceVariant
                    : theme.disabledColor,
              ),
            ),
            child: Text(
              selected?.label ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  WorkspaceSelectOption<T>? _selectedOption() {
    for (final option in widget.options) {
      if (option.value == widget.value) {
        return option;
      }
    }
    return null;
  }

  Future<void> _openMenu() async {
    final anchorContext = _anchorKey.currentContext;
    final anchor = anchorContext?.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (anchor is! RenderBox || overlay is! RenderBox || !anchor.hasSize) {
      return;
    }

    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    setState(() => _menuOpen = true);
    final selected = await showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomRight.dy,
        overlay.size.width - bottomRight.dx,
        overlay.size.height - bottomRight.dy,
      ),
      constraints: BoxConstraints(
        minWidth: anchor.size.width,
        maxWidth: anchor.size.width,
      ),
      color: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      popUpAnimationStyle: AnimationStyle.noAnimation,
      items: widget.options
          .map(
            (option) => PopupMenuItem<T>(
              value: option.value,
              height: 44,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (option.value == widget.value) ...<Widget>[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(),
    );

    if (!mounted) {
      return;
    }
    setState(() => _menuOpen = false);
    if (selected != null && selected != widget.value) {
      widget.onChanged?.call(selected);
    }
  }
}
