import 'dart:async';

import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_page.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_editor_dialog.dart';
import 'package:touchin_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'project creation uses standard dialog and blocks pending actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _ProjectSaveApi();
    await tester.pumpWidget(MaterialApp(home: ProjectTasksPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo projeto'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(WorkspaceEditorDialog), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome'),
      'Projeto novo',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'Descrição do projeto novo',
    );
    await tester.tap(find.text('Criar projeto').last);
    await tester.pump();

    expect(api.createAttempts, 1);
    expect(find.text('Salvando projeto…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar'))
            .onPressed,
        isNull);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.tapAt(const Offset(5, 5));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(WorkspaceEditorDialog), findsOneWidget);
    expect(api.createAttempts, 1);

    api.createGate.complete(_savedProject(name: 'Projeto novo'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceEditorDialog), findsNothing);
    expect(find.text('Projeto criado.'), findsOneWidget);
    expect(find.text('Projeto novo'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project edit keeps entered values after API error and retries',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _ProjectSaveApi();
    await tester.pumpWidget(MaterialApp(home: ProjectTasksPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar projeto'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome'),
      'Projeto editado',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'Descrição preservada após erro',
    );
    await tester.tap(find.text('Salvar').last);
    await tester.pump();

    expect(api.updateAttempts, 1);
    expect(find.text('Salvando projeto…'), findsOneWidget);
    api.updateGates[0].completeError(
      ApiException(
        'SQL constraint details with private row contents',
        statusCode: 409,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceEditorDialog), findsOneWidget);
    expect(find.text('Projeto editado'), findsOneWidget);
    expect(find.text('Descrição preservada após erro'), findsOneWidget);
    expect(
      find.text(
          'O projeto mudou desde que foi aberto. Recarregue e tente novamente.'),
      findsOneWidget,
    );
    expect(
      find.text('SQL constraint details with private row contents'),
      findsNothing,
    );
    expect(find.text('Projeto atualizado.'), findsNothing);

    await tester.tap(find.text('Salvar').last);
    await tester.pump();
    expect(api.updateAttempts, 2);
    api.updateGates[1].complete(_savedProject(name: 'Projeto editado'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceEditorDialog), findsNothing);
    expect(find.text('Projeto atualizado.'), findsOneWidget);
    expect(find.text('Projeto editado'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project edit preserves capacity guidance for a 409',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _ProjectSaveApi();
    await tester.pumpWidget(MaterialApp(home: ProjectTasksPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar projeto'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome'),
      'Projeto com limite reduzido',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'Rascunho deve permanecer',
    );
    await tester.tap(find.text('Salvar').last);
    await tester.pump();

    api.updateGates.single.completeError(
      ApiException(
        'O limite por tarefa não pode ser menor que a quantidade de '
        'funcionários já associados a uma tarefa. Remova participantes antes '
        'de reduzir o limite.',
        statusCode: 409,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceEditorDialog), findsOneWidget);
    expect(find.text('Projeto com limite reduzido'), findsOneWidget);
    expect(find.text('Rascunho deve permanecer'), findsOneWidget);
    expect(
      find.textContaining('Remova participantes antes de reduzir o limite.'),
      findsOneWidget,
    );
    expect(
      find.text(
          'O projeto mudou desde que foi aberto. Recarregue e tente novamente.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tasks create retains draft on 403/500 and succeeds on retry',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _DelayedCreateProjectTasksApi();
    await tester.pumpWidget(MaterialApp(home: ProjectTasksPage(api: api)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nova tarefa'));
    await tester.tap(find.text('Nova tarefa'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'), 'Tarefa recuperável');
    await tester.enterText(find.widgetWithText(TextFormField, 'Descrição'),
        'Descrição preservada para retry');

    for (final status in <int>[403, 500]) {
      await tester.tap(find.text('Criar tarefa').last);
      await tester.pump();
      final attempts = api.drafts.length;
      expect(attempts, status == 403 ? 1 : 2);

      await tester.tap(find.text('Criar tarefa').last);
      await tester.tap(find.text('Cancelar').last);
      await tester.pump();
      expect(api.drafts.length, attempts);
      expect(find.text('Tarefa recuperável'), findsOneWidget);

      api.gates.last.completeError(
        ApiException('Criação rejeitada $status', statusCode: status),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tarefa recuperável'), findsOneWidget);
      expect(find.text('Descrição preservada para retry'), findsOneWidget);
      expect(find.text('Criação rejeitada $status'), findsOneWidget);
      expect(find.text('Tarefa criada.'), findsNothing);
    }

    await tester.tap(find.text('Criar tarefa').last);
    await tester.pump();
    expect(api.drafts.length, 3);
    expect(api.drafts.every((draft) => draft.name == 'Tarefa recuperável'),
        isTrue);
    expect(api.drafts.first.creationKey, isNotNull);
    expect(
        api.drafts.every(
            (draft) => draft.creationKey == api.drafts.first.creationKey),
        isTrue);
    api.gates.last.complete();
    await tester.pumpAndSettle();
    expect(find.text('Criar tarefa'), findsNothing);
    expect(find.text('Tarefa recuperável'), findsWidgets);
    expect(find.text('Tarefa criada.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tasks pending save blocks dismissal and preserves draft on 409',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _DelayedProjectTasksApi();
    await tester.pumpWidget(MaterialApp(home: ProjectTasksPage(api: api)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Editar tarefa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar tarefa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'),
        'Edição Tasks ainda pendente');
    await tester.tap(find.text('Salvar').last);
    await tester.pump();
    expect(api.attempts, 1);
    await tester.tap(find.text('Cancelar').last);
    await tester.pump();
    expect(find.text('Edição Tasks ainda pendente'), findsOneWidget);
    api.pending.completeError(ApiException('Conflito Tasks',
        statusCode: 409, code: 'task_version_conflict'));
    await tester.pumpAndSettle();
    expect(find.text('Edição Tasks ainda pendente'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('task-editor-copy-draft')), findsOneWidget);
    expect(find.text('Tarefa atualizada.'), findsNothing);
  });
  testWidgets('Tasks edit conflict keeps original draft available for copying',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _ConflictProjectTasksApi();
    await tester.pumpWidget(MaterialApp(home: ProjectTasksPage(api: api)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Editar tarefa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar tarefa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'),
        'Rascunho Tasks preservado');
    await tester.enterText(find.widgetWithText(TextFormField, 'Descrição'),
        'Descrição que não deve desaparecer');
    await tester.tap(find.text('Salvar').last);
    await tester.pumpAndSettle();
    expect(api.attempts, 1);
    expect(find.text('Rascunho Tasks preservado'), findsOneWidget);
    expect(find.text('Descrição que não deve desaparecer'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('task-editor-copy-draft')), findsOneWidget);
    expect(find.text('Tarefa atualizada.'), findsNothing);
  });
  testWidgets('manager sees project and task management actions',
      (tester) async {
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
            widget is TextField && widget.decoration?.labelText == 'Descrição',
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
            widget is TextField && widget.decoration?.labelText == 'Descrição',
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
  testWidgets('task editor reuses workspace dialog and standard inputs',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: ProjectTasksPage(
          api: _FakeProjectTasksApi(role: 'manager', employeeId: 'emp-02'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final newTask = find.text('Nova tarefa');
    await tester.ensureVisible(newTask);
    await tester.tap(newTask);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(WorkspaceEditorDialog), findsOneWidget);
    final dialogFinder = find.byType(Dialog);
    expect(dialogFinder, findsOneWidget);
    final dialog = tester.widget<Dialog>(dialogFinder);
    final shape = dialog.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.zero);
    expect(find.text('Detalhes da tarefa'), findsOneWidget);
    expect(find.text('Projeto atual'), findsNothing);
    final taskNameField = tester.widget<InputDecorator>(
      find.byWidgetPredicate(
        (widget) =>
            widget is InputDecorator && widget.decoration.labelText == 'Nome',
      ),
    );
    final taskDescriptionField = tester.widget<InputDecorator>(
      find.byWidgetPredicate(
        (widget) =>
            widget is InputDecorator &&
            widget.decoration.labelText == 'Descrição',
      ),
    );
    expect(taskNameField.decoration.prefixIcon, isNull);
    expect(taskDescriptionField.decoration.prefixIcon, isNull);
    expect(tester.getRect(dialogFinder).width, lessThanOrEqualTo(390));
    expect(tester.takeException(), isNull);
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
  Future<List<ProjectMemberSummary>> listProjectMembers(
      String projectId) async {
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

class _DelayedCreateProjectTasksApi extends _FakeProjectTasksApi {
  _DelayedCreateProjectTasksApi()
      : super(role: 'manager', employeeId: 'emp-02');

  final List<TaskDraft> drafts = <TaskDraft>[];
  final List<Completer<void>> gates = <Completer<void>>[];

  @override
  Future<TaskRecord> createTask(String projectId, TaskDraft draft) async {
    drafts.add(draft);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return TaskRecord(
      id: 'task-created',
      projectId: projectId,
      parentTaskId: draft.parentTaskId,
      name: draft.name,
      description: draft.description,
      type: draft.type,
      createdAt: DateTime(2026, 10, 18),
      updatedAt: DateTime(2026, 10, 18),
    );
  }
}

class _ConflictProjectTasksApi extends _FakeProjectTasksApi {
  _ConflictProjectTasksApi() : super(role: 'manager', employeeId: 'emp-02');

  int attempts = 0;

  @override
  Future<TaskRecord> updateTask(
      String projectId, String taskId, TaskDraft draft,
      {DateTime? expectedUpdatedAt, int? expectedRevision}) async {
    attempts++;
    throw ApiException(
      'Este card foi alterado em outra sessão.',
      statusCode: 409,
      code: 'task_version_conflict',
    );
  }
}

class _DelayedProjectTasksApi extends _FakeProjectTasksApi {
  _DelayedProjectTasksApi() : super(role: 'manager', employeeId: 'emp-02');

  final pending = Completer<TaskRecord>();
  int attempts = 0;

  @override
  Future<TaskRecord> updateTask(
      String projectId, String taskId, TaskDraft draft,
      {DateTime? expectedUpdatedAt, int? expectedRevision}) {
    attempts++;
    return pending.future;
  }
}

class _ProjectSaveApi extends _FakeProjectTasksApi {
  _ProjectSaveApi() : super(role: 'manager', employeeId: 'emp-02');

  final createGate = Completer<ProjectSummary>();
  final List<Completer<ProjectSummary>> updateGates =
      <Completer<ProjectSummary>>[];
  int createAttempts = 0;
  int updateAttempts = 0;

  @override
  Future<ProjectSummary> createProject(ProjectDraft draft) {
    createAttempts++;
    return createGate.future;
  }

  @override
  Future<ProjectSummary> updateProject(String projectId, ProjectDraft draft) {
    updateAttempts++;
    final gate = Completer<ProjectSummary>();
    updateGates.add(gate);
    return gate.future;
  }
}

ProjectSummary _savedProject({
  required String name,
  String id = 'project-01',
}) {
  return ProjectSummary(
    id: id,
    name: name,
    description: 'Descrição salva',
    taskEmployeeLimit: 2,
    status: ProjectStatus.active,
    createdAt: DateTime(2026, 9, 9),
    updatedAt: DateTime(2026, 10, 25),
  );
}
