import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

const _indicatorTokens = <String>[
  'CircularProgressIndicator',
  'LinearProgressIndicator',
  'RefreshProgressIndicator',
  'CupertinoActivityIndicator',
];

const _startupSplashSource = 'lib/main.dart';
const _auditPageSource =
    'lib/features/admin/presentation/admin_audit_page.dart';

/// The #113 audit-export action is a linear progress indicator, not a loading
/// spinner. It is the only non-startup indicator that may remain.
const _auditExportContext = 'Exportando registros de auditoria';

const _migratedSources = <String>[
  'lib/main.dart',
  'lib/features/projects/presentation/project_kanban_page.dart',
  'lib/features/projects/presentation/project_tasks_page.dart',
  'lib/features/admin/presentation/admin_audit_page.dart',
  'lib/features/admin/presentation/admin_employees_page.dart',
  'lib/features/time_tracking/presentation/time_clock_page.dart',
  'lib/features/time_tracking/presentation/work_log_dialog.dart',
];

class _IndicatorHit {
  const _IndicatorHit({
    required this.path,
    required this.token,
    required this.context,
  });

  final String path;
  final String token;
  final String context;

  String get label => '$path: $token';

  bool get isStartupSplash =>
      path == _startupSplashSource && token == 'CircularProgressIndicator';

  bool get isAuditExportProgress =>
      path == _auditPageSource &&
      token == 'LinearProgressIndicator' &&
      context.contains('_isExporting') &&
      context.contains(_auditExportContext);
}

String _relativeSourcePath(String path, {String? workingDirectory}) {
  final cwd =
      (workingDirectory ?? Directory.current.path).replaceAll('\\', '/');
  var normalized = path.replaceAll('\\', '/');
  if (normalized.startsWith('$cwd/')) {
    normalized = normalized.substring(cwd.length + 1);
  }
  return normalized;
}

List<_IndicatorHit> _indicatorHits() {
  final hits = <_IndicatorHit>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  for (final file in files) {
    final path = _relativeSourcePath(file.path);
    final content = file.readAsStringSync();
    for (final token in _indicatorTokens) {
      for (final match in token.allMatches(content)) {
        final start = math.max(0, match.start - 400);
        final end = math.min(content.length, match.end + 400);
        hits.add(
          _IndicatorHit(
            path: path,
            token: token,
            context: content.substring(start, end),
          ),
        );
      }
    }
  }
  return hits;
}

void main() {
  test('indicator inventory paths are stable on Windows and POSIX', () {
    expect(_relativeSourcePath(r'lib\main.dart'), 'lib/main.dart');
    expect(_relativeSourcePath('lib/main.dart'), 'lib/main.dart');
    expect(
      _relativeSourcePath(
        r'C:\repo\frontend\lib\main.dart',
        workingDirectory: r'C:\repo\frontend',
      ),
      'lib/main.dart',
    );
  });

  test('permits only the #113 audit-export linear indicator', () {
    final exportContext = 'if (_isExporting) const LinearProgressIndicator('
        'semanticsLabel: $_auditExportContext)';

    expect(
      const _IndicatorHit(
        path: _auditPageSource,
        token: 'LinearProgressIndicator',
        context: '',
      ).isAuditExportProgress,
      isFalse,
      reason:
          'A linear indicator without the export context is content loading.',
    );
    expect(
      _IndicatorHit(
        path: _auditPageSource,
        token: 'LinearProgressIndicator',
        context: exportContext,
      ).isAuditExportProgress,
      isTrue,
    );
    expect(
      _IndicatorHit(
        path: 'lib/features/projects/presentation/project_kanban_page.dart',
        token: 'LinearProgressIndicator',
        context: exportContext,
      ).isAuditExportProgress,
      isFalse,
    );
    expect(
      _IndicatorHit(
        path: _auditPageSource,
        token: 'CircularProgressIndicator',
        context: exportContext,
      ).isAuditExportProgress,
      isFalse,
    );
  });

  test('only startup and the #113 export progress keep an indicator', () {
    final hits = _indicatorHits();
    final startup = hits.where((hit) => hit.isStartupSplash).toList();
    final export = hits.where((hit) => hit.isAuditExportProgress).toList();
    final forbidden = hits
        .where((hit) => !hit.isStartupSplash && !hit.isAuditExportProgress)
        .toList();

    expect(
      forbidden.map((hit) => hit.label),
      isEmpty,
      reason:
          'Only the startup "Aguardando o servidor" circular spinner may remain. '
          'The #113 audit export LinearProgressIndicator is allowed only inside '
          'its exporting branch ($_auditPageSource).',
    );
    expect(
      startup,
      hasLength(1),
      reason: 'The startup splash must keep exactly one spinner.',
    );
    expect(
      export.length,
      lessThanOrEqualTo(1),
      reason: 'The audit export must not stack progress indicators.',
    );
  });

  test('the remaining indicator lives inside the startup splash', () {
    final main = File(_startupSplashSource).readAsStringSync();
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
