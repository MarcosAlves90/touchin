import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/projects/presentation/project_kanban_page.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/kanban_board.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';

void main() {
  testWidgets(
    'bypasses the workspace compositor on wide viewports',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(home: ProjectKanbanPage(api: _FakeKanbanApi())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceScaffold), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(WorkspaceNavigationDrawer), findsOneWidget);
      expect(find.byType(KanbanBoardView), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
    },
  );

  testWidgets(
    'virtualizes columns and card slots with direct drag handles',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(home: ProjectKanbanPage(api: _FakeKanbanApi())),
      );
      await tester.pumpAndSettle();

      final board = find.byType(KanbanBoardView);
      expect(board, findsOneWidget);
      expect(find.text('A fazer (1)'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Implementar tela'), findsOneWidget);

      final listViews = tester.widgetList<ListView>(
        find.descendant(of: board, matching: find.byType(ListView)),
      );
      expect(
        listViews.any((list) => list.scrollDirection == Axis.horizontal),
        isTrue,
      );
      expect(
        listViews.any((list) => list.scrollDirection == Axis.vertical),
        isTrue,
      );
      expect(
        find.descendant(
          of: board,
          matching: find.byType(Draggable<KanbanCard>),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: board,
          matching: find.byType(DragTarget<KanbanCard>),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: board,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: board,
          matching: find.byType(ReorderableListView),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: board,
          matching: find.byType(LongPressDraggable<KanbanCard>),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'dedicated Kanban remains bounded on narrow viewport',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(home: ProjectKanbanPage(api: _FakeKanbanApi())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KanbanBoardView), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeKanbanApi extends TouchInApi {
  @override
  Future<AuthContext> getAuthContext() async {
    return AuthContext(
      company: const AuthCompanySummary(
        id: 'company-01',
        legalName: 'TouchIn Tecnologia LTDA',
        tradeName: 'TouchIn',
        cnpjMasked: '12.***.***/****-90',
        emailMasked: 'co*****@touchin.com',
        phoneMasked: '11*****0000',
      ),
      user: const AuthUserSummary(
        id: 'user-01',
        email: 'gestor@touchin.com',
        role: 'manager',
        employeeId: 'emp-01',
      ),
    );
  }

  @override
  Future<List<ProjectSummary>> listProjects({ProjectStatus? status}) async {
    return <ProjectSummary>[
      ProjectSummary(
        id: 'project-01',
        name: 'Projeto principal',
        description: 'Projeto usado pelo Kanban',
        taskEmployeeLimit: 3,
        status: ProjectStatus.active,
        createdAt: DateTime(2026, 9, 9),
        updatedAt: DateTime(2026, 9, 9),
      ),
    ];
  }

  @override
  Future<List<EmployeeProfile>> listEmployees() async => <EmployeeProfile>[];

  @override
  Future<List<ProjectMemberSummary>> listProjectMembers(String projectId) async {
    return <ProjectMemberSummary>[
      ProjectMemberSummary(
        employeeId: 'emp-01',
        projectId: projectId,
        employeeName: 'Gestor TouchIn',
        createdAt: DateTime(2026, 9, 9),
      ),
    ];
  }

  @override
  Future<List<TaskRecord>> listTasks(String projectId) async {
    return <TaskRecord>[
      TaskRecord(
        id: 'task-01',
        projectId: projectId,
        name: 'Implementar tela',
        description: 'Descrição da tarefa',
        type: TaskType.feature,
        parentTaskId: null,
        cardNumber: 1,
        kanbanColumnId: 'column-01',
        kanbanPosition: 0,
        createdAt: DateTime(2026, 9, 9),
        updatedAt: DateTime(2026, 9, 9),
      ),
    ];
  }

  @override
  Future<List<TaskMemberSummary>> listTaskMembers(
    String projectId,
    String taskId,
  ) async => <TaskMemberSummary>[];

  @override
  Future<KanbanBoard> getKanbanBoard(String projectId) async {
    return KanbanBoard(
      projectId: projectId,
      kanbanVersion: 1,
      columns: <KanbanColumn>[
        KanbanColumn(
          id: 'column-01',
          projectId: projectId,
          name: 'A fazer',
          position: 0,
          cards: <KanbanCard>[
            KanbanCard(
              id: 'task-01',
              projectId: projectId,
              parentTaskId: null,
              cardNumber: 1,
              kanbanColumnId: 'column-01',
              kanbanPosition: 0,
              name: 'Implementar tela',
              description: 'Descrição da tarefa',
              type: TaskType.feature,
              assignees: const <TaskMemberSummary>[],
              createdAt: DateTime(2026, 9, 9),
              updatedAt: DateTime(2026, 9, 9),
            ),
          ],
          createdAt: DateTime(2026, 9, 9),
          updatedAt: DateTime(2026, 9, 9),
        ),
      ],
    );
  }
}
