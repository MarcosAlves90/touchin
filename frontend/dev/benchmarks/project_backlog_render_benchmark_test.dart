// Optional local workload check. Run explicitly with:
// flutter test --no-pub dev/benchmarks/project_backlog_render_benchmark_test.dart
// Times include test-framework scheduling/layout and are not production frame timings.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_backlog_view.dart';

void main() {
  for (final count in <int>[100, 1000, 5000]) {
    testWidgets('profile Backlog with $count cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final board = _board(count);
      final initial = Stopwatch()..start();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProjectBacklogView(
          board: board,
          projectName: 'Projeto de medição',
          projectMembers: const <ProjectMemberSummary>[],
          canManageStructure: false,
          canManageCards: true,
          canManageAssignees: false,
          canMoveCards: true,
          isBusy: false,
          onManageColumns: () {},
          onCreateColumn: () {},
          onCreateCard: (_) {},
          onMoveCard: (_, __, ___) {},
          onEditCard: (_) {},
          onDeleteCard: (_) {},
          onManageAssignees: (_) {},
          onOpenDetails: (_) {},
        )),
      ));
      initial.stop();
      expect(find.byType(DataTable), findsOneWidget);
      final initialRss = ProcessInfo.currentRss;

      final sort = Stopwatch()..start();
      await tester.tap(find.byKey(const ValueKey('backlog-header-title')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ordenar crescente'));
      await tester.pump();
      sort.stop();

      final search = Stopwatch()..start();
      await tester.enterText(
          find.byKey(const ValueKey('backlog-search')), 'card 1');
      await tester.pump();
      search.stop();
      final afterRss = ProcessInfo.currentRss;

      // RSS measures the entire test process and may include earlier runs.
      // The timings are comparative local measurements, not FPS benchmarks.
      // ignore: avoid_print
      print(
          'BACKLOG_PROFILE cards=$count build_ms=${initial.elapsedMilliseconds} '
          'sort_ms=${sort.elapsedMilliseconds} search_ms=${search.elapsedMilliseconds} '
          'rss_after_build_mib=${(initialRss / 1048576).toStringAsFixed(1)} '
          'rss_after_search_mib=${(afterRss / 1048576).toStringAsFixed(1)}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}

KanbanBoard _board(int count) {
  final now = DateTime.utc(2026, 10, 12);
  final columns = <KanbanColumn>[];
  for (var column = 0; column < 2; column++) {
    final cards = <KanbanCard>[];
    for (var index = column; index < count; index += 2) {
      cards.add(KanbanCard(
        id: 'task-$index',
        projectId: 'project-1',
        parentTaskId: index % 5 == 0 ? null : 'task-${index - 1}',
        cardNumber: index + 1,
        kanbanColumnId: 'column-$column',
        kanbanPosition: cards.length,
        name: 'Card $index',
        description: 'Descrição do card $index',
        type: TaskType.feature,
        assignees: const <TaskMemberSummary>[],
        createdAt: now,
        updatedAt: now,
      ));
    }
    columns.add(KanbanColumn(
      id: 'column-$column',
      projectId: 'project-1',
      name: column == 0 ? 'A fazer' : 'Concluído',
      position: column,
      cards: cards,
      createdAt: now,
      updatedAt: now,
    ));
  }
  return KanbanBoard(
      projectId: 'project-1', kanbanVersion: 1, columns: columns);
}
