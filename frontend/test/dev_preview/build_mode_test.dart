import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compile-time value, not the Flutter build mode, controls the guard',
      () async {
    for (final (defines, expected) in [
      (<String>[], 'PREVIEW_BLOCKED'),
      (['-DTOUCHIN_FRONTEND_DEV_MODE=false'], 'PREVIEW_BLOCKED'),
      (['-DTOUCHIN_FRONTEND_DEV_MODE=yes'], 'PREVIEW_BLOCKED'),
      (['-DTOUCHIN_FRONTEND_DEV_MODE=TRUE'], 'PREVIEW_BLOCKED'),
      (['-Ddart.vm.product=true'], 'PREVIEW_BLOCKED'),
      (['-Ddart.vm.profile=true'], 'PREVIEW_BLOCKED'),
      (['-DTOUCHIN_FRONTEND_DEV_MODE=true'], 'PREVIEW_ALLOWED'),
      (
        ['-Ddart.vm.product=true', '-DTOUCHIN_FRONTEND_DEV_MODE=true'],
        'PREVIEW_ALLOWED'
      ),
      (
        ['-Ddart.vm.profile=true', '-DTOUCHIN_FRONTEND_DEV_MODE=true'],
        'PREVIEW_ALLOWED'
      ),
    ]) {
      final result = await Process.run(
        'dart',
        [...defines, 'test/dev_preview/build_mode_probe.dart'],
        runInShell: Platform.isWindows,
      );
      expect(result.exitCode, 0, reason: '$defines: ${result.stderr}');
      expect((result.stdout as String).trim(), expected, reason: '$defines');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
