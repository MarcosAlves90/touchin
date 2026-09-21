import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_page.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/kanban_board.dart';
import 'package:touchin_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manager sees project and task management actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectTasksPage(
          api: _FakeProjectTasksApi(role: 'manager', employeeId: 'emp-02'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administrar projetos'), findsOneWidget);
    expect(find.text('Projetos'), findsWidgets);
    expect(find.text('Tarefas'), findsWidgets);
    expect(find.text('Acessos'), findsWidgets);
    expect(find.text('Ocupação'), findsOneWidget);
    expect(find.text('Projeto principal'), findsWidgets);
    expect(find.text('Implementar tela'), findsWidgets);
    expect(find.text('Novo projeto'), findsOneWidget);
    expect(find.text('Nova tarefa'), findsOneWidget);
    expect(find.text('Acesso ao projeto'), findsOneWidget);
    expect(find.text('Adicionar ao projeto'), findsOneWidget);
    expect(find.text('Entrar na tarefa'), findsOneWidget);
    expect(find.text('Adicionar membro'), findsOneWidget);
    expect(find.text('Kanban'), findsNothing);
    expect(find.text('#1'), findsNothing);
    expect(find.text('Coluna'), findsNothing);
  });

  testWidgets('kanban workspace is isolated from project tasks rendering',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectTasksPage(
          api: _FakeProjectTasksApi(role: 'manager', employeeId: 'emp-02'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(KanbanBoardView), findsNothing);
    expect(find.text('Projeto principal'), findsWidgets);
    expect(find.text('Implementar tela'), findsWidgets);
  });

  testWidgets('selected project list icon keeps accent contrast in dark theme',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: ProjectTasksPage(
          api: _FakeProjectTasksApi(role: 'employee', employeeId: 'emp-04'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final projectIcon = find.byIcon(Icons.folder_open_rounded);

    expect(projectIcon, findsOneWidget);
    expect(
      tester.widget<Icon>(projectIcon).color,
      AppTheme.accent,
    );
  });

  testWidgets('employee can access tasks without project editing actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectTasksPage(
          api: _FakeProjectTasksApi(role: 'employee', employeeId: 'emp-04'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Projeto principal'), findsWidgets);
    expect(find.text('Implementar tela'), findsWidgets);
    expect(find.text('Novo projeto'), findsNothing);
    expect(find.text('Nova tarefa'), findsNothing);
    expect(find.text('Adicionar ao projeto'), findsNothing);
    expect(find.text('Entrar na tarefa'), findsOneWidget);
    expect(find.text('Adicionar membro'), findsNothing);
    expect(find.byTooltip('Remover da tarefa'), findsNothing);
    expect(find.text('Kanban'), findsNothing);
    expect(find.text('#1'), findsNothing);
    expect(find.text('Coluna'), findsNothing);
    expect(find.text('Responsáveis'), findsNothing);
  });

  testWidgets('project and task editors mirror backend text limits',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectTasksPage(
          api: _FakeProjectTasksApi(role: 'manager', employeeId: 'emp-02'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Novo projeto'));
    await tester.pumpAndSettle();

    final projectNameField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Nome',
      ),
    );
    final projectDescriptionField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Descrição',
      ),
    );
    expect(projectNameField.maxLength, projectNameMaxLength);
    expect(projectDescriptionField.maxLength, projectDescriptionMaxLength);
    expect(
      find.textContaining('Ao reduzir, o limite não pode ficar abaixo'),
      findsNothing,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    final newTaskButton = find.text('Nova tarefa');
    await tester.ensureVisible(newTaskButton);
    await tester.tap(newTaskButton);
    await tester.pumpAndSettle();

    final taskNameField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Nome',
      ),
    );
    final taskDescriptionField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Descrição',
      ),
    );
    expect(taskNameField.maxLength, taskNameMaxLength);
    expect(taskDescriptionField.maxLength, taskDescriptionMaxLength);
  });


  testWidgets('editing project explains the occupied-task limit constraint',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectTasksPage(
          api: _FakeProjectTasksApi(role: 'manager', employeeId: 'emp-02'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar projeto'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Ao reduzir, o limite não pode ficar abaixo da quantidade de funcionários',
      ),
      findsOneWidget,
    );
  });

  testWidgets('full task does not offer join action', (tester) async {
    final api = _FakeProjectTasksApi(
      role: 'employee',
      employeeId: 'emp-04',
      taskInitiallyFull: true,
    );
    await tester.pumpWidget(MaterialApp(home: ProjectTasksPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('2 de 2 vaga(s) ocupada(s).'), findsOneWidget);
    expect(find.text('Entrar na tarefa'), findsNothing);
    expect(find.text('Sair da tarefa'), findsNothing);
    expect(api.joinCalls, 0);
  });

  testWidgets('joining a task refreshes membership state', (tester) async {
    final api = _FakeProjectTasksApi(role: 'employee', employeeId: 'emp-04');
    await tester.pumpWidget(MaterialApp(home: ProjectTasksPage(api: api)));
    await tester.pumpAndSettle();

    final joinButton = find.text('Entrar na tarefa');
    await tester.ensureVisible(joinButton);
    await tester.tap(joinButton);
    await tester.pumpAndSettle();

    expect(api.joinCalls, 1);
    expect(find.text('Sair da tarefa'), findsOneWidget);
    expect(find.text('1 de 2 vaga(s) ocupada(s).'), findsOneWidget);
  });
}

class _FakeProjectTasksApi extends TouchInApi {
  _FakeProjectTasksApi({
    required this.role,
    required this.employeeId,
    this.taskInitiallyFull = false,
  });

  final String role;
  final String? employeeId;
  final bool taskInitiallyFull;
  int joinCalls = 0;
  bool joined = false;

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
      user: AuthUserSummary(
        id: 'user-01',
        email: 'usuario@touchin.com',
        role: role,
        employeeId: employeeId,
      ),
    );
  }

  @override
  Future<List<ProjectSummary>> listProjects({ProjectStatus? status}) async {
    return <ProjectSummary>[
      ProjectSummary(
        id: 'project-01',
        name: 'Projeto principal',
        description: 'Descrição do projeto',
        taskEmployeeLimit: 2,
        status: ProjectStatus.active,
        createdAt: DateTime(2026, 9, 9),
        updatedAt: DateTime(2026, 9, 9),
      ),
    ];
  }

  @override
  Future<List<ProjectMemberSummary>> listProjectMembers(String projectId) async {
    if (employeeId == null) {
      return <ProjectMemberSummary>[];
    }
    return <ProjectMemberSummary>[
      ProjectMemberSummary(
        employeeId: employeeId!,
        projectId: projectId,
        employeeName: role == 'manager' ? 'Caio Martins' : 'João Lima',
        createdAt: DateTime(2026, 9, 9),
      ),
      ProjectMemberSummary(
        employeeId: 'emp-05',
        projectId: projectId,
        employeeName: 'Ana Lima',
        createdAt: DateTime(2026, 9, 9),
      ),
    ];
  }

  @override
  Future<KanbanBoard> getKanbanBoard(String projectId) async {
    return KanbanBoard(
      projectId: projectId,
      kanbanVersion: 0,
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

  @override
  Future<List<TaskRecord>> listTasks(String projectId) async {
    return <TaskRecord>[
      TaskRecord(
        id: 'task-01',
        projectId: projectId,
        parentTaskId: null,
        name: 'Implementar tela',
        description: 'Descrição da tarefa',
        type: TaskType.feature,
        createdAt: DateTime(2026, 9, 9),
        updatedAt: DateTime(2026, 9, 9),
      ),
    ];
  }

  @override
  Future<List<TaskMemberSummary>> listTaskMembers(
    String projectId,
    String taskId,
  ) async {
    if (taskInitiallyFull) {
      return <TaskMemberSummary>[
        TaskMemberSummary(
          employeeId: 'emp-05',
          taskId: taskId,
          employeeName: 'Ana Lima',
          createdAt: DateTime(2026, 9, 9),
        ),
        TaskMemberSummary(
          employeeId: 'emp-06',
          taskId: taskId,
          employeeName: 'Bruno Costa',
          createdAt: DateTime(2026, 9, 9),
        ),
      ];
    }
    if (!joined || employeeId == null) {
      return <TaskMemberSummary>[];
    }
    return <TaskMemberSummary>[
      TaskMemberSummary(
        employeeId: employeeId!,
        taskId: taskId,
        employeeName: 'João Lima',
        createdAt: DateTime(2026, 9, 9),
      ),
    ];
  }

  @override
  Future<List<EmployeeProfile>> listEmployees() async => <EmployeeProfile>[];

  @override
  Future<TaskMemberSummary> joinTask(String projectId, String taskId) async {
    joinCalls += 1;
    joined = true;
    return TaskMemberSummary(
      employeeId: employeeId!,
      taskId: taskId,
      employeeName: 'João Lima',
      createdAt: DateTime(2026, 9, 9),
    );
  }
}
