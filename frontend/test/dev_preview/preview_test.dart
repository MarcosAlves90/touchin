import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/dev_preview/preview_api.dart';
import 'package:touchin_flutter/dev_preview/preview_controller.dart';
import 'package:touchin_flutter/dev_preview/preview_fixtures.dart';
import 'package:touchin_flutter/dev_preview/preview_launcher.dart';
import 'package:touchin_flutter/dev_preview/preview_workspace.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:touchin_flutter/features/projects/presentation/project_kanban_page.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_page.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_skeleton.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_page.dart';

void main() {
  if (!developerPreviewAvailable) {
    test('preview scenarios need TOUCHIN_FRONTEND_DEV_MODE=true', () {},
        skip: 'Run with --dart-define=TOUCHIN_FRONTEND_DEV_MODE=true.');
    return;
  }

  late PreviewController controller;
  late PreviewFixtures fixtures;
  late PreviewTokenStorage storage;
  late PreviewApi api;

  setUp(() {
    controller = PreviewController();
    fixtures = PreviewFixtures();
    storage = PreviewTokenStorage(controller, fixtures);
    api = PreviewApi(controller, fixtures, storage);
    FlutterSecureStorage.setMockInitialValues(
        {'access_token': 'previous-real-session'});
  });
  tearDown(() {
    if (!controller.isDisposed) controller.dispose();
  });

  test('unsupported AI settings never enqueue simulated requests', () async {
    controller.timing = PreviewTiming.pending;
    await expectLater(
      api.getCompanyAISettings(),
      throwsA(isA<ApiException>().having(
        (error) => error.code,
        'code',
        'preview_unsupported',
      )),
    );
    expect(controller.pendingCount, 0);
  });

  test('fixtures are deterministic, linked and parsed by normal API contracts',
      () async {
    final projects = await api.listProjects();
    final employees = await api.listEmployees();
    expect(employees.length, greaterThan(8));
    expect(projects.length, 3);
    for (final project in projects) {
      final board = await api.getKanbanBoard(project.id);
      final tasks = await api.listTasks(project.id);
      expect(board.taskRecords.map((t) => t.id).toSet(),
          tasks.map((t) => t.id).toSet());
      final members = await api.listProjectMembers(project.id);
      expect(members.every((m) => employees.any((e) => e.id == m.employeeId)),
          isTrue);
      for (final task in tasks) {
        expect(board.columns.any((c) => c.id == task.kanbanColumnId), isTrue);
        if (task.parentTaskId != null) {
          expect(tasks.any((t) => t.id == task.parentTaskId), isTrue);
        }
        expect(
            (await api.listTaskMembers(project.id, task.id))
                .every((m) => members.any((p) => p.employeeId == m.employeeId)),
            isTrue);
      }
    }
    expect(await api.listAuditEvents(), hasLength(50));
    expect(await api.listAuditEvents(page: 2), hasLength(12));
    expect((await api.getMyTimeClockState()).recordsTotal, 8);
    final state = await api.getMyTimeClockState(page: 2);
    expect(state.recordsPage, 2);
    expect(state.recordsHasPrevious, isTrue);
    expect(state.employee.requiresLocationOnPunch, isFalse);
    expect(PreviewFixtures().tasks, fixtures.tasks);
  });

  test('memory mutations stay coherent across tasks, board, members and reset',
      () async {
    final project = (await api.listProjects()).first;
    final created = await api.createTask(
        project.id,
        const TaskDraft(
            name: 'Nova tarefa fictícia',
            description: 'Local',
            type: TaskType.bug));
    expect(
        (await api.getKanbanBoard(project.id))
            .taskRecords
            .any((t) => t.id == created.id),
        isTrue);
    var board = await api.getKanbanBoard(project.id);
    final target = board.columns.last.id;
    final layout = {
      for (final column in board.columns)
        column.id: column.cards
            .where((t) => t.id != created.id)
            .map((t) => t.id)
            .toList()
    };
    layout[target]!.add(created.id);
    board = await api.reorderKanbanCards(project.id,
        expectedVersion: board.kanbanVersion, columnTaskIds: layout);
    expect(board.columns.last.cards.any((t) => t.id == created.id), isTrue);
    expect(
        (await api.listTasks(project.id))
            .firstWhere((t) => t.id == created.id)
            .kanbanColumnId,
        target);
    await api.addTaskMember(project.id, created.id, 'preview-employee-2');
    expect(await api.listTaskMembers(project.id, created.id), hasLength(1));
    await api.deleteTask(project.id, created.id);
    expect(
        (await api.getKanbanBoard(project.id))
            .taskRecords
            .any((t) => t.id == created.id),
        isFalse);
    final newProject = await api.createProject(const ProjectDraft(
        name: 'Local', description: 'Fictício', taskEmployeeLimit: 3));
    expect((await api.getKanbanBoard(newProject.id)).columns, hasLength(1));
    await api.createPunch(
        request: const CreatePunchRequest(type: PunchType.checkIn));
    expect(
        (await api.getMyTimeClockState()).currentStatus, ShiftStatus.working);
    fixtures.reset();
    controller.reset();
    expect(await api.listProjects(), hasLength(3));
    expect(fixtures.tasks, PreviewFixtures().tasks);
    expect(await TokenStorage().readAccessToken(), 'previous-real-session');
  });

  test(
      'preview cannot persist identity or fall back for unsupported API operations',
      () async {
    expect((await storage.readAuthSession()).tokenType, 'preview');
    await expectLater(
        storage.saveAccessToken('anything'), throwsUnsupportedError);
    await expectLater(
        api.login(
            credentials: const LoginCredentials(
                email: 'fake@example.invalid', password: 'local')),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'preview_unsupported')));
    await expectLater(api.exportAuditEvents(), throwsA(isA<ApiException>()));
    expect(await TokenStorage().readAccessToken(), 'previous-real-session');
    controller.setPersona(PreviewPersona.employee);
    expect((await api.getAuthContext()).user.role, 'employee');
    await expectLater(
        api.listEmployees(),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
    expect(await api.listProjects(), isNotEmpty);
  });

  testWidgets(
      'pending and delayed requests are cancelled without stale writes or timers',
      (tester) async {
    controller.configure(timing: PreviewTiming.pending);
    final pending = api.createProject(const ProjectDraft(
        name: 'Stale', description: '', taskEmployeeLimit: 2));
    final cancelled = expectLater(pending, throwsA(isA<ApiException>()));
    await tester.pump();
    expect(controller.pendingCount, 1);
    controller.configure(
        timing: PreviewTiming.delayed, delay: const Duration(seconds: 1));
    await cancelled;
    final delayed = api.listEmployees();
    final disposed = expectLater(delayed, throwsA(isA<ApiException>()));
    await tester.pump();
    controller.dispose();
    await disposed;
    await tester.pump(const Duration(seconds: 5));
    expect(controller.pendingCount, 0);
    expect(fixtures.projects, hasLength(3));
  });

  Future<void> mount(WidgetTester tester,
      {String path = '/projects', Size size = const Size(1400, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.defaultRouteNameTestValue = path;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    });
    await tester
        .pumpWidget(PreviewWorkspace(controller: controller, onExit: () {}));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
      'all principal deep links use fake APIs and preserve existing stored session',
      (tester) async {
    final trap = _NetworkTrap();
    final previous = HttpOverrides.current;
    HttpOverrides.global = trap;
    addTearDown(() => HttpOverrides.global = previous);
    await mount(tester);
    expect(find.byType(ProjectTasksPage), findsOneWidget);
    final router = WorkspaceRouterScope.maybeOf(
        tester.element(find.byType(ProjectTasksPage)))!;
    for (final entry in <String, Type>{
      '/kanban': ProjectKanbanPage,
      '/admin/employees': AdminEmployeesPage,
      '/admin/audit': AdminAuditPage,
      '/time-clock': TimeClockPage,
      '/projects': ProjectTasksPage,
    }.entries) {
      router.navigate(entry.key);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(entry.value), findsOneWidget);
      expect(find.textContaining('[Prévia] Erro'), findsNothing);
      expect(tester.takeException(), isNull);
    }
    expect(trap.attempts, 0);
    expect(await TokenStorage().readAccessToken(), 'previous-real-session');
    await unmount(tester);
  });

  testWidgets(
      'actual startup wait, unavailable retry and page skeleton are independent',
      (tester) async {
    controller.server = PreviewServer.delayed;
    controller.delay = const Duration(seconds: 2);
    controller.timing = PreviewTiming.pending;
    await mount(tester);
    expect(find.text('Aguardando o servidor'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(find.text('Aguardando o servidor'), findsNothing);
    expect(find.byType(WorkspaceSkeletonRegion), findsWidgets);
    controller.configure(timing: PreviewTiming.instant);
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byType(WorkspaceSkeletonRegion), findsNothing);
    expect(find.textContaining('Portal Aurora'), findsWidgets);
    controller.restartServer(PreviewServer.retrySuccess);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('Não foi possível validar sua sessão'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    expect(find.text('Não foi possível validar sua sessão'), findsNothing);
    expect(find.byType(ProjectTasksPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
      'page skeleton reaches empty/error/retry, preserves route and safely resets pending',
      (tester) async {
    await mount(tester);
    controller.configure(
        timing: PreviewTiming.delayed,
        delay: const Duration(milliseconds: 250),
        data: PreviewData.empty);
    await tester.pump();
    await tester.pump();
    expect(find.byType(WorkspaceSkeletonRegion), findsWidgets);
    expect(find.text('Aguardando o servidor'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byType(WorkspaceSkeletonRegion), findsNothing);
    expect(find.textContaining('Portal Aurora'), findsNothing);
    controller.configure(
        timing: PreviewTiming.instant, data: PreviewData.error);
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(
        find.textContaining('[Prévia] Erro de dados simulado.'), findsWidgets);
    await tester.tap(find.text('Tentar novamente').first);
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(
        find.textContaining('[Prévia] Erro de dados simulado.'), findsWidgets);
    controller.configure(data: PreviewData.populated);
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.textContaining('Portal Aurora'), findsWidgets);
    controller.configure(timing: PreviewTiming.pending);
    await tester.pump();
    await tester.pump();
    expect(controller.pendingCount, greaterThan(0));
    controller.reset();
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    expect(controller.pendingCount, 0);
    expect(find.textContaining('Portal Aurora'), findsWidgets);
    await unmount(tester);
  });

  testWidgets(
      'narrow controls dismiss without obscuring content and exit without real logout',
      (tester) async {
    var exited = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
        PreviewWorkspace(controller: controller, onExit: () => exited = true));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('preview-controls')));
    await tester.pumpAndSettle();
    expect(find.text('Controles de desenvolvimento'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Fechar controles'));
    await tester.pumpAndSettle();
    expect(find.text('Controles de desenvolvimento'), findsNothing);
    await tester.tap(find.byTooltip('Sair da prévia'));
    expect(exited, isTrue);
    expect(await TokenStorage().readAccessToken(), 'previous-real-session');
    await unmount(tester);
  });

  testWidgets(
      'launcher entry is explicit and exiting preview returns to safe choice',
      (tester) async {
    await tester.pumpWidget(const PreviewLauncher());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar na prévia de desenvolvimento'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.textContaining('PRÉVIA LOCAL'), findsOneWidget);
    await tester.tap(find.byTooltip('Sair da prévia'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir login normal'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('preview never reads or mutates secure session keys',
      (tester) async {
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final sessionOperations = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      final args = call.arguments as Map<dynamic, dynamic>?;
      if (args?['key'] == 'access_token' ||
          args?['key'] == 'auth_session' ||
          call.method == 'deleteAll' ||
          call.method == 'readAll') {
        sessionOperations.add(call.method);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const PreviewLauncher());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar na prévia de desenvolvimento'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    await tester.tap(find.byTooltip('Sair da prévia'));
    await tester.pumpAndSettle();
    expect(sessionOperations, isEmpty);
    await unmount(tester);
  });

  testWidgets(
      'navigation cancels pending page operations and disposal releases timers',
      (tester) async {
    controller.timing = PreviewTiming.pending;
    await mount(tester, path: '/admin/employees');
    expect(controller.pendingCount, greaterThan(0));
    final router = WorkspaceRouterScope.maybeOf(
        tester.element(find.byType(AdminEmployeesPage)))!;
    router.navigate('/settings');
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(controller.pendingCount, 0);
    controller.configure(timing: PreviewTiming.delayed);
    for (var i = 0; i < 2; i++) {
      await tester.pump();
    }
    await unmount(tester);
    expect(controller.pendingCount, 0);
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset during delayed cold start cannot restore stale bootstrap',
      (tester) async {
    controller.server = PreviewServer.delayed;
    controller.delay = const Duration(seconds: 5);
    await mount(tester);
    expect(find.text('Aguardando o servidor'), findsOneWidget);
    controller.reset();
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    expect(controller.pendingCount, 0);
    expect(find.byType(ProjectTasksPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets(
      'preview dropdowns open without Navigator assertion on mobile and desktop',
      (tester) async {
    final trap = _NetworkTrap();
    final previousHttp = HttpOverrides.current;
    HttpOverrides.global = trap;
    addTearDown(() => HttpOverrides.global = previousHttp);

    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final sessionOperations = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      final args = call.arguments as Map<dynamic, dynamic>?;
      if (args?['key'] == 'access_token' ||
          args?['key'] == 'auth_session' ||
          call.method == 'deleteAll' ||
          call.method == 'readAll') {
        sessionOperations.add(call.method);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/projects';
    addTearDown(() {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    });

    var exited = false;
    const drawerTitle = 'Controles de desenvolvimento';
    const reason = 'preview dropdowns open without Navigator assertion';

    bool drawerOpen() => find.text(drawerTitle).evaluate().isNotEmpty;

    Future<void> openDrawer() async {
      if (!drawerOpen()) {
        await tester.tap(find.byKey(const ValueKey('preview-controls')));
        await tester.pumpAndSettle();
      }
      expect(find.text(drawerTitle), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$reason: drawer open');
    }

    Future<void> closeDrawer() async {
      if (drawerOpen()) {
        await tester.tap(find.byTooltip('Fechar controles'));
        await tester.pumpAndSettle();
      }
      expect(find.text(drawerTitle), findsNothing);
      expect(tester.takeException(), isNull, reason: '$reason: drawer close');
    }

    Future<void> select(String label, Object currentValue, String option,
        {bool verifyMenuBack = false}) async {
      await openDrawer();
      final dropdown = find.byKey(ValueKey('$label-$currentValue'));
      expect(dropdown, findsOneWidget, reason: 'missing dropdown $label');
      final select = tester.widget<DropdownButton<dynamic>>(
        find.descendant(
          of: dropdown,
          matching: find.byWidgetPredicate(
            (widget) => widget is DropdownButton,
          ),
        ),
      );
      final colors = Theme.of(tester.element(dropdown)).colorScheme;
      expect(select.dropdownColor, colors.surfaceContainerHighest,
          reason: 'preview_dropdown_surface');
      expect(select.borderRadius, BorderRadius.circular(10),
          reason: 'preview_dropdown_radius_10');
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$reason: $label menu');
      expect(find.text(option), findsWidgets, reason: 'options for $label');
      if (verifyMenuBack) {
        expect(await tester.binding.handlePopRoute(), isTrue,
            reason: 'back dismisses the dropdown menu');
        await tester.pumpAndSettle();
        expect(find.text(option), findsNothing, reason: 'menu closed by back');
        expect(tester.takeException(), isNull, reason: '$reason: menu back');
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        expect(find.text(option), findsWidgets, reason: 'menu reopened');
        expect(tester.takeException(), isNull, reason: '$reason: menu reopen');
      }
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: '$reason: $label dismissal');
    }

    for (final size in <Size>[
      const Size(390, 844),
      const Size(1400, 900),
    ]) {
      controller.reset();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(PreviewWorkspace(
          controller: controller, onExit: () => exited = true));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull, reason: '$reason: mount $size');

      await select('Perfil fictício', controller.persona, 'Gestor',
          verifyMenuBack: true);
      expect(controller.persona, PreviewPersona.manager);
      await select('Atraso', controller.delay.inMilliseconds, '250 ms');
      expect(controller.delay, const Duration(milliseconds: 250));
      await select('Dados da página', controller.data, 'Vazios');
      expect(controller.data, PreviewData.empty);
      await select('Tempo das requisições', controller.timing, 'Com atraso');
      expect(controller.timing, PreviewTiming.delayed);
      await select('Inicialização do servidor', controller.server,
          'Inicialização com atraso');
      expect(controller.server, PreviewServer.delayed);

      await openDrawer();
      for (final selected in <String>[
        'Gestor',
        '250 ms',
        'Vazios',
        'Com atraso',
        'Inicialização com atraso',
      ]) {
        expect(find.text(selected), findsWidgets,
            reason: 'persisted value $selected at $size');
      }
      expect(tester.takeException(), isNull, reason: '$reason: persistence');

      if (size.width > 800) {
        await closeDrawer();
        final router = WorkspaceRouterScope.maybeOf(
            tester.element(find.byType(ProjectTasksPage)))!;
        router.navigate('/kanban');
        await tester.pumpAndSettle();
        expect(find.byType(ProjectKanbanPage), findsOneWidget);
        await select('Dados da página', controller.data, 'Preenchidos');
        expect(controller.data, PreviewData.populated);
        await closeDrawer();
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
        expect(find.byType(ProjectTasksPage), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$reason: back');
      } else {
        await closeDrawer();
      }

      await openDrawer();
      await tester.tap(find.text('Sair da prévia').last);
      expect(exited, isTrue, reason: 'drawer exit at $size');
      expect(await TokenStorage().readAccessToken(), 'previous-real-session');
      expect(sessionOperations, isEmpty);
      expect(trap.attempts, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$reason: unmount $size');
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets(
      'browser history messages dismiss dropdowns without losing the destination',
      (tester) async {
    const reason = 'preview pushRouteInformation contract';
    await mount(tester, path: '/projects');
    expect(find.byType(ProjectTasksPage), findsOneWidget);

    final router = WorkspaceRouterScope.maybeOf(
        tester.element(find.byType(ProjectTasksPage)))!;
    router.navigate('/kanban');
    await tester.pumpAndSettle();
    expect(find.byType(ProjectKanbanPage), findsOneWidget);
    final forwardEntry = router.currentConfiguration;

    await tester.tap(find.byKey(const ValueKey('preview-controls')));
    await tester.pumpAndSettle();
    final dropdown =
        find.byKey(ValueKey('Perfil fictício-${controller.persona}'));
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(find.text('Gestor'), findsOneWidget, reason: 'dropdown menu open');

    Future<void> pushRouteInformation(WorkspaceLocation location) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        JSONMethodCodec().encodeMethodCall(MethodCall('pushRouteInformation', {
          'location': location.path,
          'state': location.entryId,
        })),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    // Browser Back: the URL change must close the menu but still reach Router.
    await pushRouteInformation(const WorkspaceLocation('/projects'));
    expect(find.text('Gestor'), findsNothing,
        reason: '$reason: menu dismissed');
    expect(router.currentConfiguration.path, '/projects');
    expect(find.byType(ProjectTasksPage), findsOneWidget);

    // Browser Forward: the existing entry is reachable after Back.
    await pushRouteInformation(forwardEntry);
    expect(find.text('Gestor'), findsNothing, reason: '$reason: forward menu');
    expect(router.currentConfiguration, forwardEntry);
    expect(find.byType(ProjectKanbanPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}

class _NetworkTrap extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Real HTTP client constructed during offline preview');
  }
}
