import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/core/theme/theme_mode_controller.dart';

void main() {
  test('theme changes remain immediate while secure writes are pending',
      () async {
    final store = _ControlledThemeStore();
    final controller = ThemeModeController(store: store);
    await controller.load();

    final light = controller.setThemeMode(ThemeMode.light);
    expect(controller.mode, ThemeMode.light);
    expect(store.saved, 'dark');
    await _flushEvents();
    expect(store.writes, hasLength(1));

    final system = controller.setThemeMode(ThemeMode.system);
    expect(controller.mode, ThemeMode.system);
    expect(store.writes, hasLength(1), reason: 'writes must be serialized');

    store.succeedNext();
    await light;
    await _flushEvents();
    expect(store.saved, 'light');
    expect(controller.mode, ThemeMode.system);
    expect(store.writes, hasLength(2));

    store.succeedNext();
    await system;
    expect(store.saved, 'system');
    expect(controller.mode, ThemeMode.system);
    expect(controller.hasPersistenceError, isFalse);
  });

  test('failed write restores last confirmed preference and reports error',
      () async {
    final store = _ControlledThemeStore();
    final controller = ThemeModeController(store: store);
    await controller.load();

    final write = controller.setThemeMode(ThemeMode.light);
    expect(controller.mode, ThemeMode.light);
    await _flushEvents();
    store.failNext();
    await write;

    expect(store.saved, 'dark');
    expect(controller.mode, ThemeMode.dark);
    expect(controller.hasPersistenceError, isTrue);

    final retry = controller.setThemeMode(ThemeMode.light);
    await _flushEvents();
    store.succeedNext();
    await retry;
    expect(controller.mode, ThemeMode.light);
    expect(store.saved, 'light');
    expect(controller.hasPersistenceError, isFalse);
  });

  test('failed later write rolls back to the last successful write', () async {
    final store = _ControlledThemeStore();
    final controller = ThemeModeController(store: store);
    await controller.load();

    final first = controller.setThemeMode(ThemeMode.light);
    final second = controller.setThemeMode(ThemeMode.system);
    await _flushEvents();
    store.succeedNext();
    await first;
    await _flushEvents();
    store.failNext();
    await second;

    expect(controller.mode, ThemeMode.light);
    expect(store.saved, 'light');
    expect(controller.hasPersistenceError, isTrue);
  });

  test('stale failed write does not undo a newer selection of the same mode',
      () async {
    final store = _ControlledThemeStore();
    final controller = ThemeModeController(store: store);
    await controller.load();

    final first = controller.setThemeMode(ThemeMode.light);
    final second = controller.setThemeMode(ThemeMode.system);
    final third = controller.setThemeMode(ThemeMode.light);
    await _flushEvents();
    store.failNext();
    await first;
    expect(controller.mode, ThemeMode.light,
        reason: 'first failed selection must not undo the third selection');
    await _flushEvents();
    store.succeedNext();
    await second;
    await _flushEvents();
    store.succeedNext();
    await third;
    expect(controller.mode, ThemeMode.light);
    expect(store.saved, 'light');
    expect(controller.hasPersistenceError, isFalse);
  });

  test('failed secure preference read leaves usable dark default', () async {
    final store = _ControlledThemeStore()..failRead = true;
    final controller = ThemeModeController(store: store);
    await controller.load();

    expect(controller.mode, ThemeMode.dark);
    expect(controller.hasPersistenceError, isTrue);
  });
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

class _ControlledThemeStore implements ThemePreferenceStore {
  String saved = 'dark';
  bool failRead = false;
  final List<({ThemeMode mode, Completer<void> complete})> writes = [];
  int _completed = 0;

  @override
  Future<String?> readThemeMode() async {
    if (failRead) throw StateError('simulated read failure');
    return saved;
  }

  @override
  Future<void> writeThemeMode(ThemeMode mode) {
    final complete = Completer<void>();
    writes.add((mode: mode, complete: complete));
    return complete.future.then((_) => saved = mode.name);
  }

  void succeedNext() => writes[_completed++].complete.complete();

  void failNext() => writes[_completed++]
      .complete
      .completeError(StateError('simulated write failure'));
}
