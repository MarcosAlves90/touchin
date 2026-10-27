import 'dart:async';

import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_page.dart';

/// A repeatable visual-review entry point for the issue #121 loading state.
/// Run with `flutter build web --release -t test/issue121_visual_entrypoint.dart`.
///
/// The API call intentionally stays pending so the production page renders its
/// real loading composition without account data or a live backend.
void main() {
  runApp(
    MaterialApp(
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF8B3A00),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF765A00),
          onSecondary: Color(0xFFFFFFFF),
          error: Color(0xFFBA1A1A),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFFFF8F3),
          onSurface: Color(0xFF201A17),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8F3),
        useMaterial3: true,
      ),
      home: ProjectTasksPage(api: _PendingLoadingApi()),
    ),
  );
}

class _PendingLoadingApi extends TouchInApi {
  @override
  Future<List<ProjectSummary>> listProjects({ProjectStatus? status}) =>
      Completer<List<ProjectSummary>>().future;
}
