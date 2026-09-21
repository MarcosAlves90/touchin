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
    'uses a standard Scaffold with a lazily mounted navigation drawer',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(home: ProjectKanbanPage(api: _FakeKanbanApi())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceScaffold), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isA<WorkspaceNavigationDrawer>());
      expect(find.byType(WorkspaceNavigationDrawer), findsNothing);

      expect(find.byType(KanbanBoardView), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
    },
  );

  testWidgets(
    'empty board keeps valid geometry below the AppBar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectKanbanPage(
            api: _FakeKanbanApi(includeCard: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final appBar = find.byType(AppBar);
      final intro = find.text(
        'Acompanhe e mova os cards do projeto selecionado.',
      );
      final board = find.byType(KanbanBoardView);
      final lane = find.text('A fazer (0)');
      final emptySlot = find.text('Solte um card aqui');

      expect(appBar, findsOneWidget);
      expect(intro, findsOneWidget);
      expect(board, findsOneWidget);
      expect(lane, findsOneWidget);
      expect(emptySlot, findsOneWidget);

      final appBarRect = tester.getRect(appBar);
      final introRect = tester.getRect(intro);
      final boardRect = tester.getRect(board);
      final laneRect = tester.getRect(lane);
      final emptySlotRect = tester.getRect(emptySlot);

      expect(introRect.top, greaterThanOrEqualTo(appBarRect.bottom + 20));
      expect(boardRect.top, greaterThan(introRect.bottom));
      expect(boardRect.width, greaterThan(0));
      expect(boardRect.height, greaterThan(0));
      expect(laneRect.width, greaterThan(0));
      expect(laneRect.height, greaterThan(0));
      expect(emptySlotRect.width, greaterThan(0));
      expect(emptySlotRect.height, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'visible board controls receive taps at their painted coordinates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(home: ProjectKanbanPage(api: _FakeKanbanApi())),
      );
      await tester.pumpAndSettle();

      final createColumn = find.text('Coluna');
      expect(createColumn, findsOneWidget);

      await tester.tap(createColumn);
      await tester.pumpAndSettle();

      expect(find.text('Nova coluna'), findsOneWidget);
      expect(find.text('Nome da coluna'), findsOneWidget);
    },
  );

  testWidgets(
    'real workspace drawer navigation settles before asserting destination',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScaffold(
            sidebar: const SizedBox.shrink(),
            contentBuilder: (_, __) => const SizedBox.shrink(),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      final kanbanEntry = find.text('Kanban');
      expect(kanbanEntry, findsOneWidget);

      await tester.tap(kanbanEntry);
      await tester.pumpAndSettle();

      expect(find.byType(ProjectKanbanPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'normal replacement navigation settles on ProjectKanbanPage',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProjectKanbanPage(),
                      ),
                    );
                  },
                  child: const Text('Abrir Kanban'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Kanban'));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectKanbanPage), findsOneWidget);
      expect(tester.takeException(), isNull);
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
  _FakeKanbanApi({this.includeCard = true});

  final bool includeCard;

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
    if (!includeCard) {
      return <TaskRecord>[];
    }

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
          cards: includeCard
              ? <KanbanCard>[
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
                ]
              : <KanbanCard>[],
          createdAt: DateTime(2026, 9, 9),
          updatedAt: DateTime(2026, 9, 9),
        ),
      ],
    );
  }
}
