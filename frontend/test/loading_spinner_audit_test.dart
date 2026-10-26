import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _indicatorTokens = <String>[
  'CircularProgressIndicator',
  'LinearProgressIndicator',
  'RefreshProgressIndicator',
  'CupertinoActivityIndicator',
];

const _migratedSources = <String>[
  'lib/main.dart',
  'lib/features/projects/presentation/project_kanban_page.dart',
  'lib/features/projects/presentation/project_tasks_page.dart',
  'lib/features/admin/presentation/admin_audit_page.dart',
  'lib/features/admin/presentation/admin_employees_page.dart',
  'lib/features/time_tracking/presentation/time_clock_page.dart',
  'lib/features/time_tracking/presentation/work_log_dialog.dart',
];

void main() {
  test('only the cold-start splash keeps a progress indicator', () {
    final hits = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final content = file.readAsStringSync();
      for (final token in _indicatorTokens) {
        if (content.contains(token)) {
          final occurrences = token.allMatches(content).length;
          hits.add('${file.path}: $token x$occurrences');
        }
      }
    }

    expect(
      hits,
      <String>['lib/main.dart: CircularProgressIndicator x1'],
      reason:
          'Only the startup "Aguardando o servidor" view may keep an indicator; '
          'ordinary content and action states must use skeletons or status text.',
    );
  });

  test('the remaining indicator lives inside the startup splash', () {
    final main = File('lib/main.dart').readAsStringSync();
    final splashStateIndex = main.indexOf('class _StartupSplashState');
    final indicatorIndex = main.indexOf('CircularProgressIndicator');
    final nextClassIndex = main.indexOf(RegExp(r'^class ', multiLine: true),
        splashStateIndex + 'class _StartupSplashState'.length);

    expect(splashStateIndex, greaterThanOrEqualTo(0));
    expect(indicatorIndex, greaterThan(splashStateIndex));
    if (nextClassIndex != -1) {
      expect(indicatorIndex, lessThan(nextClassIndex));
    }
    expect('Aguardando o servidor'.allMatches(main).length, greaterThan(0));
  });

  test('every migrated surface composes the shared skeleton region', () {
    for (final path in _migratedSources) {
      final content = File(path).readAsStringSync();
      expect(
        content,
        contains('WorkspaceSkeletonRegion'),
        reason: '$path must render pending content through the shared region',
      );
    }
  });

  test('action submissions expose pending text instead of a skeleton', () {
    for (final path in <String>[
      'lib/features/shared/presentation/widgets/workspace_editor_dialog.dart',
      'lib/features/auth/presentation/widgets/auth_form_widgets.dart',
    ]) {
      final content = File(path).readAsStringSync();
      expect(content, contains('liveRegion: true'), reason: path);
      expect(content, isNot(contains('WorkspaceSkeletonRegion(')),
          reason: 'action states must not render a content skeleton: $path');
    }
  });

  test('no source file depends on an animated image shimmer package', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final dependency in <String>[
      'shimmer',
      'skeletonizer',
      'skeleton_loader',
    ]) {
      expect(pubspec, isNot(contains(dependency)));
    }
  });
}
