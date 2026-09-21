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
    'Kanban rendering probe isolates board subtree',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectKanbanPage(api: _FakeKanbanApi()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KanbanBoardView), findsNothing);
      expect(find.text('Diagnóstico do quadro'), findsOneWidget);
      expect(find.text('Colunas carregadas: 1'), findsOneWidget);
      expect(find.text('Cards carregados: 1'), findsOneWidget);

      final shell = tester.widget<WorkspaceScaffold>(
        find.byType(WorkspaceScaffold),
      );
      expect(shell.contentScrollable, isFalse);
    },
  );

  testWidgets(
    'dedicated Kanban page renders outside workspace vertical scrolling',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectKanbanPage(api: _FakeKanbanApi()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProjectKanbanPage), findsOneWidget);
      expect(find.byType(KanbanBoardView), findsNothing);
      expect(find.text('Projeto principal'), findsWidgets);
      expect(find.text('Diagnóstico do quadro'), findsOneWidget);

      final shell = tester.widget<WorkspaceScaffold>(
        find.byType(WorkspaceScaffold),
      );
      expect(shell.contentScrollable, isFalse);
      expect(
        find.ancestor(
          of: find.text('Diagnóstico do quadro'),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'diagnostic probe contains no Kanban board viewport subtree',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectKanbanPage(api: _FakeKanbanApi()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KanbanBoardView), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.byType(ListView), findsNothing);
      expect(find.text('Diagnóstico do quadro'), findsOneWidget);
    },
  );

  testWidgets(
    'dedicated Kanban page remains bounded on narrow viewport',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectKanbanPage(api: _FakeKanbanApi()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KanbanBoardView), findsNothing);
      expect(find.text('Diagnóstico do quadro'), findsOneWidget);
      expect(find.text('Colunas carregadas: 1'), findsOneWidget);
      expect(find.text('Cards carregados: 1'), findsOneWidget);
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
