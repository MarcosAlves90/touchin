import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/contracts/task_recommendations.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_editor_dialog.dart';
import 'package:touchin_flutter/features/time_tracking/application/punch_location_service.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_controller.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_page.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

class _WorkLogApi extends TouchInApi {
  _WorkLogApi({
    this.status = ShiftStatus.working,
    this.projectsCompleter,
    this.recommendationCompleter,
    this.recommendationCompleters = const <Completer<TaskRecommendations>>[],
    this.recommendationResult = const TaskRecommendations(
      status: 'available',
      items: <TaskRecommendation>[
        TaskRecommendation(taskId: 'task-a', taskName: 'Tarefa A'),
      ],
    ),
  });

  final ShiftStatus status;
  final Completer<List<ProjectSummary>>? projectsCompleter;
  final Completer<TaskRecommendations>? recommendationCompleter;
  final List<Completer<TaskRecommendations>> recommendationCompleters;
  final TaskRecommendations recommendationResult;
  Map<String, dynamic>? lastPunchJson;
  int listProjectsCalls = 0;
  final List<String> recommendationProjects = <String>[];

  final List<ProjectSummary> projects = <ProjectSummary>[
    _project('project-a', 'Projeto A'),
    _project('project-b', 'Projeto B'),
  ];

  final Map<String, List<TaskRecord>> tasks = <String, List<TaskRecord>>{
    'project-a': <TaskRecord>[
      _task('task-a', 'project-a', 'Tarefa A'),
      _task('task-extra', 'project-a', 'Tarefa adicional'),
    ],
    'project-b': <TaskRecord>[_task('task-b', 'project-b', 'Tarefa B')],
  };

  @override
  Future<TimeClockState> getMyTimeClockState({
    int page = 1,
    int limit = 4,
  }) async {
    return TimeClockState(
      employee: const TimeClockEmployeeSummary(
        id: 'emp-01',
        name: 'Marina Silva',
        unit: 'Operações',
        status: EmployeeStatus.active,
        workMode: EmployeeWorkMode.onsite,
        requiresLocationOnPunch: true,
        trustedDeviceRequired: false,
      ),
      currentStatus: status,
      todayWorkedMinutes: 240,
      todayBreakMinutes: status == ShiftStatus.onBreak ? 20 : 0,
      firstCheckInAt: DateTime.parse('2026-05-24T08:00:00Z'),
      lastPunchAt: DateTime.parse('2026-05-24T12:00:00Z'),
      records: const <PunchRecord>[],
      recordsPage: 1,
      recordsPageSize: 4,
      recordsTotal: 0,
      recordsTotalPages: 1,
      recordsHasPrevious: false,
      recordsHasNext: false,
    );
  }

  @override
  Future<List<ProjectSummary>> listProjects({ProjectStatus? status}) async {
    listProjectsCalls += 1;
    if (projectsCompleter != null) {
      return projectsCompleter!.future;
    }
    return projects;
  }

  @override
  Future<List<ProjectSummary>> listEmployeeProjects(String employeeId) async {
    expect(employeeId, 'emp-01');
    // Both fixture projects are associated with the current employee.
    return listProjects(status: ProjectStatus.active);
  }

  @override
  Future<List<TaskRecord>> listTasks(String projectId) async {
    return tasks[projectId] ?? const <TaskRecord>[];
  }

  @override
  Future<TaskRecommendations> recommendTasks({
    required String projectId,
    required String description,
  }) async {
    final requestIndex = recommendationProjects.length;
    recommendationProjects.add(projectId);
    if (requestIndex < recommendationCompleters.length) {
      return recommendationCompleters[requestIndex].future;
    }
    if (recommendationCompleter != null) {
      return recommendationCompleter!.future;
    }
    return recommendationResult;
  }

  @override
  Future<PunchRecord> createPunch({required CreatePunchRequest request}) async {
    lastPunchJson = request.toApiJson();
    return PunchRecord(
      type: request.type,
      timestamp: DateTime.parse('2026-05-24T13:30:00Z'),
      detail: 'registrado',
      location: request.location,
    );
  }
}

class _ReadyLocationService extends PunchLocationService {
  const _ReadyLocationService();

  PunchLocationResult get _result => PunchLocationResult.ready(
        snapshot: PunchLocationSnapshot(
          latitude: -23.55052,
          longitude: -46.63331,
          accuracyMeters: 8,
          capturedAt: DateTime.parse('2026-05-24T13:29:00Z'),
        ),
      );

  @override
  Future<PunchLocationResult> requestPermission() async => _result;

  @override
  Future<PunchLocationResult> captureForPunch() async => _result;
}

class _TestTimeClockController extends TimeClockController {
  _TestTimeClockController({
    required super.api,
    required super.punchLocationService,
  });

  @override
  Future<void> start() async {
    await loadTimeClockState(page: recordsPage, limit: recordsPageSize);
  }
}

ProjectSummary _project(String id, String name) {
  final timestamp = DateTime.parse('2026-05-24T08:00:00Z');
  return ProjectSummary(
    id: id,
    name: name,
    description: null,
    taskEmployeeLimit: 2,
    status: ProjectStatus.active,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

TaskRecord _task(String id, String projectId, String name) {
  final timestamp = DateTime.parse('2026-05-24T08:00:00Z');
  return TaskRecord(
    id: id,
    projectId: projectId,
    parentTaskId: null,
    name: name,
    description: 'desc',
    type: TaskType.feature,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

Future<_WorkLogApi> _pumpPage(
  WidgetTester tester, {
  ThemeData? theme,
  ShiftStatus status = ShiftStatus.working,
  Completer<List<ProjectSummary>>? projectsCompleter,
  Completer<TaskRecommendations>? recommendationCompleter,
  List<Completer<TaskRecommendations>> recommendationCompleters =
      const <Completer<TaskRecommendations>>[],
  TaskRecommendations recommendationResult = const TaskRecommendations(
    status: 'available',
    items: <TaskRecommendation>[
      TaskRecommendation(taskId: 'task-a', taskName: 'Tarefa A'),
    ],
  ),
}) async {
  final api = _WorkLogApi(
    status: status,
    projectsCompleter: projectsCompleter,
    recommendationCompleter: recommendationCompleter,
    recommendationCompleters: recommendationCompleters,
    recommendationResult: recommendationResult,
  );
  final controller = _TestTimeClockController(
    api: api,
    punchLocationService: const _ReadyLocationService(),
  );

  await tester.binding.setSurfaceSize(const Size(1400, 1800));
  addTearDown(() {
    controller.dispose();
    tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: TimeClockPage(controller: controller),
  ));
  await tester.pumpAndSettle();
  return api;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

Future<void> _openProject(
  WidgetTester tester,
  String projectName,
) async {
  await _tapVisible(tester, find.byKey(const Key('work-log-project')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(projectName).last);
  await tester.pumpAndSettle();
}

Future<void> _selectTask(WidgetTester tester, String taskName) async {
  final search = find.byKey(const Key('work-log-task-search-field'));
  await tester.enterText(search, taskName);
  await tester.pumpAndSettle();
  await tester.tap(find.text(taskName).last);
  await tester.pumpAndSettle();
}

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

({Color? checkmark, bool show, bool? selected, Color background})
    _selectedChipRenderState(WidgetTester tester, Finder chipFinder) {
  final renderFinder = find.descendant(
    of: chipFinder,
    matching: find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_ChipRenderWidget',
    ),
  );
  final renderObject = tester.renderObject<RenderBox>(renderFinder);
  final dynamic chipRender = renderObject;
  // ignore: avoid_dynamic_calls
  final Color? checkmark = chipRender.theme.checkmarkColor as Color?;
  // ignore: avoid_dynamic_calls
  final bool show = chipRender.theme.showCheckmark as bool;
  // ignore: avoid_dynamic_calls
  final bool? selected = chipRender.value as bool?;

  final theme = Theme.of(tester.element(chipFinder));
  final material = tester.widget<Material>(
    find.ancestor(of: renderFinder, matching: find.byType(Material)).first,
  );
  final selectedColor =
      theme.chipTheme.selectedColor ?? theme.colorScheme.secondaryContainer;
  return (
    checkmark: checkmark,
    show: show,
    selected: selected,
    background: Color.alphaBlend(
      selectedColor,
      material.color ?? theme.colorScheme.surface,
    ),
  );
}

Future<({Finder chipFinder, ThemeData theme})> _selectAiSuggestion(
  WidgetTester tester,
  Brightness brightness,
) async {
  final theme = AppTheme.offlineTheme(brightness);
  await _pumpPage(tester, theme: theme);
  await tester.tap(find.text('Iniciar pausa'));
  await tester.pumpAndSettle();
  await _openProject(tester, 'Projeto A');
  await tester.enterText(
    find.byKey(const Key('work-log-description')),
    'Corrigi o problema de sessão',
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();

  final chipFinder = find.byKey(const Key('work-log-task-suggestion-task-a'));
  await tester.ensureVisible(chipFinder);
  await tester.pumpAndSettle();
  await tester.tap(chipFinder, warnIfMissed: false);
  await tester.pumpAndSettle();
  return (chipFinder: chipFinder, theme: theme);
}

void main() {
  testWidgets('selected task delete retains keyboard focus and tooltip',
      (tester) async {
    final theme = AppTheme.highContrastTheme(
      AppTheme.offlineTheme(Brightness.dark),
    );
    await _pumpPage(tester, theme: theme);
    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await _openProject(tester, 'Projeto A');
    await _selectTask(tester, 'Tarefa A');

    final chip = find.byKey(const Key('work-log-selected-task-task-a'));
    final icon = find.descendant(of: chip, matching: find.byIcon(Icons.clear));
    final deleteControl =
        find.ancestor(of: icon, matching: find.byType(InkWell)).first;
    expect(tester.widget<InkWell>(deleteControl).onTap, isNotNull);
    final tooltip =
        MaterialLocalizations.of(tester.element(icon)).deleteButtonTooltip;
    expect(find.byTooltip(tooltip), findsOneWidget);

    final focus = Focus.of(tester.element(icon));
    expect(focus.canRequestFocus, isTrue);
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(focus.hasPrimaryFocus, isTrue);
    expect(IconTheme.of(tester.element(icon)).color,
        Theme.of(tester.element(chip)).colorScheme.onSurface);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final highContrast in [false, true]) {
      testWidgets(
          'selected task delete icon contrasts in $brightness highContrast=$highContrast',
          (tester) async {
        final base = AppTheme.offlineTheme(brightness);
        final theme = highContrast ? AppTheme.highContrastTheme(base) : base;
        await _pumpPage(tester, theme: theme);
        await tester.tap(find.text('Iniciar pausa'));
        await tester.pumpAndSettle();
        await _openProject(tester, 'Projeto A');
        await _selectTask(tester, 'Tarefa A');
        final chip = find.byKey(const Key('work-log-selected-task-task-a'));
        final icon =
            find.descendant(of: chip, matching: find.byIcon(Icons.clear));
        expect(icon, findsOneWidget);
        await tester.ensureVisible(icon);
        final localTheme = Theme.of(tester.element(chip));
        final background = Color.alphaBlend(
          localTheme.chipTheme.selectedColor!,
          localTheme.colorScheme.surface,
        );
        void expectContrast() {
          final iconTheme = IconTheme.of(tester.element(icon));
          final foreground = Color.alphaBlend(
            iconTheme.color!.withValues(alpha: iconTheme.opacity ?? 1),
            background,
          );
          final a = foreground.computeLuminance();
          final b = background.computeLuminance();
          expect((a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05)),
              greaterThanOrEqualTo(3));
          expect(iconTheme.color, localTheme.colorScheme.onSurface);
        }

        expectContrast();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: tester.getCenter(icon));
        await tester.pumpAndSettle();
        expectContrast();
        await mouse.removePointer();
        await tester.tap(icon);
        await tester.pumpAndSettle();
        expect(chip, findsNothing);
      });
    }
  }

  testWidgets('working break requires work log before punch submission',
      (tester) async {
    final api = await _pumpPage(tester);

    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();

    expect(api.lastPunchJson, isNull);
    expect(find.text('Registrar atividades'), findsOneWidget);
  });

  testWidgets('working checkout requires work log before punch submission',
      (tester) async {
    final api = await _pumpPage(tester);

    await tester.tap(find.text('Registrar saída'));
    await tester.pumpAndSettle();

    expect(api.lastPunchJson, isNull);
    expect(find.text('Registrar atividades'), findsOneWidget);
  });

  testWidgets('cancelled work log does not submit punch', (tester) async {
    final api = await _pumpPage(tester);

    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(api.lastPunchJson, isNull);
  });

  testWidgets('work-log preparation ignores repeated punch taps',
      (tester) async {
    final projectsCompleter = Completer<List<ProjectSummary>>();
    final api = await _pumpPage(
      tester,
      projectsCompleter: projectsCompleter,
    );

    await tester.tap(find.text('Iniciar pausa'));
    await tester.tap(find.text('Iniciar pausa'));

    expect(api.listProjectsCalls, 1);

    projectsCompleter.complete(api.projects);
    await tester.pumpAndSettle();

    expect(find.text('Registrar atividades'), findsOneWidget);
  });

  testWidgets('work log uses the standard workspace editor modal',
      (tester) async {
    await _pumpPage(tester);

    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();

    expect(
      find.byType(WorkspaceEditorDialog),
      findsOneWidget,
      reason: 'WORK_LOG_DIALOG_MUST_USE_SHARED_EDITOR_DIALOG',
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Registrar atividades'), findsOneWidget);
    expect(find.text('Registre sua atividade e, se aplicável, as tarefas.'),
        findsOneWidget);
    expect(
      find.text(
        'Descreva o trabalho realizado. Se selecionar um projeto, escolha ao menos uma tarefa.',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Fechar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Continuar'),
      findsOneWidget,
    );
  });

  testWidgets('incomplete work log cannot be submitted', (tester) async {
    final api = await _pumpPage(tester);

    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await _openProject(tester, 'Projeto A');
    await tester.enterText(
      find.byKey(const Key('work-log-description')),
      'Atividade sem tarefa selecionada',
    );
    await tester.pump();

    final submit = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar'));
    expect(submit.onPressed, isNull);
    expect(api.lastPunchJson, isNull);
  });

  testWidgets(
      'with projects available the employee must choose a project or Nenhum',
      (tester) async {
    await _pumpPage(tester);
    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('work-log-description')),
      'Descrição sem seleção',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar'))
          .onPressed,
      isNull,
    );
    await _openProject(tester, 'Nenhum');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
      'employee without projects sees Nenhum selected and can submit only a description',
      (tester) async {
    final api = await _pumpPage(tester);
    api.projects.clear();

    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();

    expect(find.text('Registrar atividades'), findsOneWidget);
    expect(find.text('Nenhum'), findsOneWidget);
    expect(find.byKey(const Key('work-log-task-search-field')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar'))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('work-log-description')),
      '  Atendimento interno  ',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar'))
          .onPressed,
      isNotNull,
    );
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    await tester.pumpAndSettle();

    expect(api.lastPunchJson?['type'], 'breakStart');
    expect(api.lastPunchJson?.containsKey('projectId'), isTrue);
    expect(api.lastPunchJson?['projectId'], isNull);
    expect(api.lastPunchJson?['workLog'], <String, dynamic>{
      'description': 'Atendimento interno',
      'taskIds': <String>[],
    });
  });

  testWidgets(
      'Nenhum clears selected project tasks and requires only description',
      (tester) async {
    final api = await _pumpPage(tester);
    await tester.tap(find.text('Registrar saída'));
    await tester.pumpAndSettle();
    await _openProject(tester, 'Projeto A');
    await _selectTask(tester, 'Tarefa A');
    await tester.pump();
    await _openProject(tester, 'Nenhum');

    expect(find.byKey(const Key('work-log-task-search-field')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('work-log-description')),
      'Suporte sem projeto',
    );
    await tester.pump();
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    await tester.pumpAndSettle();

    expect(api.lastPunchJson?['projectId'], isNull);
    expect(api.lastPunchJson?['workLog'], <String, dynamic>{
      'description': 'Suporte sem projeto',
      'taskIds': <String>[],
    });
  });

  testWidgets('valid work log reaches punch API with project and tasks',
      (tester) async {
    final api = await _pumpPage(tester);

    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await _openProject(tester, 'Projeto A');
    await tester.enterText(
      find.byKey(const Key('work-log-description')),
      'Corrigi o fluxo de ponto',
    );
    await _selectTask(tester, 'Tarefa A');
    await tester.pump();
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    await tester.pumpAndSettle();

    expect(api.lastPunchJson?['type'], 'breakStart');
    expect(api.lastPunchJson?['projectId'], 'project-a');
    expect(api.lastPunchJson?['workLog'], <String, dynamic>{
      'description': 'Corrigi o fluxo de ponto',
      'taskIds': <String>['task-a'],
    });
  });

  testWidgets('changing project clears tasks selected in previous project',
      (tester) async {
    final api = await _pumpPage(tester);

    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await _openProject(tester, 'Projeto A');
    await _selectTask(tester, 'Tarefa A');
    await tester.pump();
    await _openProject(tester, 'Projeto B');

    expect(
      find.byKey(const Key('work-log-selected-task-task-a')),
      findsNothing,
    );
    final search = find.byKey(const Key('work-log-task-search-field'));
    expect(search, findsOneWidget);
    await tester.enterText(search, 'Tarefa B');
    await tester.pumpAndSettle();
    expect(find.text('Tarefa B'), findsNWidgets(2));
    expect(api.lastPunchJson, isNull);
  });

  testWidgets('work-log task search filters and selects multiple tasks',
      (tester) async {
    final api = await _pumpPage(tester);
    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await _openProject(tester, 'Projeto A');

    final search = find.byKey(const Key('work-log-task-search-field'));
    expect(
      search,
      findsOneWidget,
      reason: 'WORK_LOG_TASK_SEARCH_MUST_FILTER_AND_SELECT',
    );
    await tester.enterText(search, 'adicional');
    await tester.pumpAndSettle();
    expect(find.text('Tarefa adicional'), findsOneWidget);
    expect(find.text('Tarefa A'), findsNothing);
    await tester.tap(find.text('Tarefa adicional'));
    await tester.pumpAndSettle();

    await tester.enterText(search, 'Tarefa A');
    await tester.pumpAndSettle();
    expect(find.text('Tarefa A'), findsNWidgets(2));
    await tester.tap(find.text('Tarefa A').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('work-log-selected-task-task-extra')),
        findsOneWidget);
    expect(
        find.byKey(const Key('work-log-selected-task-task-a')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('work-log-description')),
      'Atendimento e correção',
    );
    await tester.pump();
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    await tester.pumpAndSettle();

    expect(
      api.lastPunchJson?['workLog']?['taskIds'],
      unorderedEquals(<String>['task-extra', 'task-a']),
    );
  });

  testWidgets(
      'AI suggestions are clearly grouped and require explicit selection',
      (tester) async {
    final api = await _pumpPage(tester);
    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await _openProject(tester, 'Projeto A');
    await tester.enterText(
      find.byKey(const Key('work-log-description')),
      'Corrigi o problema de sessão',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(api.recommendationProjects, <String>['project-a']);
    expect(find.byKey(const Key('work-log-task-suggestion-task-a')),
        findsOneWidget);
    expect(
      find.byKey(const Key('work-log-ai-suggestions')),
      findsOneWidget,
      reason: 'WORK_LOG_AI_SUGGESTIONS_MUST_BE_CLEARLY_GROUPED',
    );
    expect(find.text('Sugestões da IA'), findsOneWidget);
    expect(
      find.text(
        'Revise as sugestões e selecione as tarefas que deseja adicionar. Nada é selecionado automaticamente.',
      ),
      findsOneWidget,
    );
    expect(
        find.byKey(const Key('work-log-selected-task-task-a')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar'))
          .onPressed,
      isNull,
    );

    await _tapVisible(
      tester,
      find.byKey(const Key('work-log-task-suggestion-task-a')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('work-log-selected-task-task-a')),
      findsOneWidget,
    );
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    await tester.pumpAndSettle();

    expect(api.lastPunchJson?['workLog'], <String, dynamic>{
      'description': 'Corrigi o problema de sessão',
      'taskIds': <String>['task-a'],
    });
  });

  testWidgets(
      'selected AI suggestion shows a visible contrasting indicator in light and dark themes',
      (tester) async {
    for (final brightness in Brightness.values) {
      final selected = await _selectAiSuggestion(tester, brightness);
      final chipFinder = selected.chipFinder;

      final chip = tester.widget<FilterChip>(chipFinder);
      expect(chip.selected, isTrue,
          reason: 'suggestion must be selected in $brightness');

      final context = tester.element(chipFinder);
      final theme = Theme.of(context);
      final chipTheme = theme.chipTheme;
      final showCheckmark = chip.showCheckmark ?? chipTheme.showCheckmark ?? true;
      expect(showCheckmark, isTrue,
          reason: 'selected AI suggestion must show a checkmark in $brightness');

      final checkmarkColor = chip.checkmarkColor ?? chipTheme.checkmarkColor;
      expect(checkmarkColor, isNotNull,
          reason: 'selected AI suggestion checkmark color must be explicit in $brightness');

      final selectedColor = chip.selectedColor ??
          chipTheme.selectedColor ??
          theme.colorScheme.secondaryContainer;
      final effectiveSelected = Color.alphaBlend(
        selectedColor,
        theme.colorScheme.surfaceContainerLow,
      );
      expect(
        _contrastRatio(checkmarkColor!, effectiveSelected),
        greaterThanOrEqualTo(3.0),
        reason:
            'selected AI suggestion checkmark must contrast in $brightness',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
      'selected AI suggestion renders an effective contrasting checkmark in light and dark themes',
      (tester) async {
    for (final brightness in Brightness.values) {
      final selected = await _selectAiSuggestion(tester, brightness);
      final chipFinder = selected.chipFinder;
      final theme = selected.theme;

      final chip = tester.widget<FilterChip>(chipFinder);
      expect(chip.selected, isTrue,
          reason: 'suggestion must be selected in $brightness');

      final state = _selectedChipRenderState(tester, chipFinder);
      expect(state.show, isTrue,
          reason: 'checkmark must be drawn in $brightness');
      expect(state.selected, isTrue,
          reason: 'selected chip state must reach the painter in $brightness');
      expect(state.checkmark, AppTheme.adminColors(theme).selectedForeground,
          reason:
              'effective painted checkmark must use the amber contrast color in $brightness');
      expect(state.checkmark, isNot(theme.chipTheme.checkmarkColor),
          reason:
              'explicit suggestion color must win over the global chip theme in $brightness');
      expect(_contrastRatio(state.checkmark!, state.background),
          greaterThanOrEqualTo(3.0),
          reason:
              'painted checkmark must contrast with the selected chip in $brightness');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('AI suggestions have clearer vertical spacing', (tester) async {
    await _pumpPage(tester);
    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await _openProject(tester, 'Projeto A');
    await tester.enterText(
      find.byKey(const Key('work-log-description')),
      'Corrigi o problema de sessão',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final descriptionRect =
        tester.getRect(find.byKey(const Key('work-log-description')));
    final suggestionsRect =
        tester.getRect(find.byKey(const Key('work-log-ai-suggestions')));
    final relatedTasksRect = tester.getRect(find.text('Tarefas relacionadas'));

    expect(
      suggestionsRect.top - descriptionRect.bottom,
      lessThan(24),
      reason: 'WORK_LOG_SUGGESTION_DESCRIPTION_GAP_MUST_BE_REDUCED',
    );
    expect(
      relatedTasksRect.top - suggestionsRect.bottom,
      greaterThanOrEqualTo(24),
      reason: 'WORK_LOG_SUGGESTION_TASKS_GAP_MUST_BE_INCREASED',
    );
  });

  testWidgets('out-of-order recommendation responses are discarded',
      (tester) async {
    final older = Completer<TaskRecommendations>();
    final newer = Completer<TaskRecommendations>();
    final api = await _pumpPage(
      tester,
      recommendationCompleters: <Completer<TaskRecommendations>>[older, newer],
    );
    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await _openProject(tester, 'Projeto A');
    final description = find.byKey(const Key('work-log-description'));
    await tester.enterText(description, 'Primeira descrição da tarefa');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(description, 'Descrição atualizada da tarefa');
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.recommendationProjects, <String>['project-a', 'project-a']);
    expect(
        find.bySemanticsLabel('Buscando sugestões de tarefas'), findsOneWidget);

    newer.complete(const TaskRecommendations(
      status: 'available',
      items: <TaskRecommendation>[
        TaskRecommendation(taskId: 'new-task', taskName: 'Sugestão atual'),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sugestão atual'), findsOneWidget);

    older.complete(const TaskRecommendations(
      status: 'available',
      items: <TaskRecommendation>[
        TaskRecommendation(taskId: 'old-task', taskName: 'Sugestão obsoleta'),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sugestão atual'), findsOneWidget);
    expect(find.text('Sugestão obsoleta'), findsNothing);
  });

  testWidgets('break end remains available without work log', (tester) async {
    final api = await _pumpPage(tester, status: ShiftStatus.onBreak);

    final checkoutButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Registrar saída'),
    );
    expect(checkoutButton.onPressed, isNull);

    await tester.tap(find.text('Retomar jornada'));
    await tester.pumpAndSettle();

    expect(api.lastPunchJson?['type'], 'breakEnd');
    expect(api.lastPunchJson?['workLog'], isNull);
  });
}
