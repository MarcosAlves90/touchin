import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page.dart';
import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_skeleton.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

class FakeTouchInApi extends TouchInApi {
  List<AuditEventResponse> mockEvents = [];
  Object? firstError;
  Object? secondPageError;
  Map<String, dynamic> lastParams = {};
  List<int> requestedPages = [];
  Completer<List<AuditEventResponse>>? secondPageResponse;

  @override
  Future<List<AuditEventResponse>> listAuditEvents({
    DateTime? startDate,
    DateTime? endDate,
    String? actorUserId,
    String? action,
    String? entityType,
    String? entityId,
    String? projectId,
    String? result,
    int page = 1,
    int limit = 50,
  }) async {
    requestedPages.add(page);
    if (firstError case final error?) {
      firstError = null;
      throw error;
    }
    lastParams = {
      'page': page,
      'limit': limit,
      'startDate': startDate,
      'endDate': endDate,
      'actorUserId': actorUserId,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'projectId': projectId,
      'result': result,
    };

    if (page == 2 && secondPageResponse != null) {
      return secondPageResponse!.future;
    }
    if (page == 2 && secondPageError != null) {
      final error = secondPageError!;
      secondPageError = null;
      throw error;
    }

    final start = (page - 1) * limit;
    if (start >= mockEvents.length) {
      return [];
    }
    var end = start + limit;
    if (end > mockEvents.length) {
      end = mockEvents.length;
    }
    return mockEvents.sublist(start, end);
  }
}

Future<void> openAuditFilters(WidgetTester tester) async {
  final button = find.byKey(const ValueKey<String>('audit-filters-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> enterAuditFilter(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.widgetWithText(TextField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> applyAuditFilters(WidgetTester tester) async {
  final button = find.byKey(const ValueKey<String>('audit-apply-filters'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> selectAuditFilter(
  WidgetTester tester,
  String key,
  String optionLabel,
) async {
  final field = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  final option = find.text(optionLabel).last;
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  AuditEventResponse pageEvent(int index) => AuditEventResponse(
        id: 'evt_$index',
        timestamp: DateTime.utc(2026, 10, 20),
        companyId: 'company_1',
        actorUserId: 'user_1',
        projectId: null,
        action: 'task.action_$index',
        entityType: 'task',
        entityId: 'task_$index',
        result: 'success',
        metadataPayload: null,
      );

  testWidgets(
      'audit filters and known event values are presented in pt-BR while requests keep technical IDs',
      (tester) async {
    final api = FakeTouchInApi()
      ..mockEvents = [
        AuditEventResponse(
          id: 'evt_reordered',
          timestamp: DateTime.utc(2026, 10, 20),
          companyId: 'company_1',
          actorUserId: 'user_1',
          projectId: 'project_1',
          action: 'card.reordered',
          entityType: 'card',
          entityId: 'card_1',
          result: 'success',
          metadataPayload: null,
        ),
      ];
    await tester.pumpWidget(MaterialApp(home: AdminAuditPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceHeader), findsOneWidget);
    expect(find.text('Tarefa reordenada'), findsOneWidget);
    expect(find.text('Sucesso'), findsOneWidget);
    expect(find.text('card.reordered'), findsOneWidget);
    expect(find.text('success'), findsNothing);

    await openAuditFilters(tester);
    expect(find.text('ID do usuário (ator)'), findsOneWidget);
    expect(find.text('Ação'), findsOneWidget);
    expect(find.text('Tipo de entidade'), findsOneWidget);
    expect(find.text('ID da entidade'), findsOneWidget);
    expect(find.text('ID do projeto'), findsOneWidget);
    expect(find.text('Resultado'), findsOneWidget);
    expect(find.text('Aplicar filtros'), findsOneWidget);
    expect(find.text('Limpar filtros'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('audit-action-filter')),
      findsOneWidget,
      reason: 'audit_filter_dropdowns_pt_br',
    );
    expect(
      find.byKey(const ValueKey<String>('audit-entity-type-filter')),
      findsOneWidget,
      reason: 'audit_filter_dropdowns_pt_br',
    );
    expect(
      find.byKey(const ValueKey<String>('audit-result-filter')),
      findsOneWidget,
      reason: 'audit_filter_dropdowns_pt_br',
    );

    await selectAuditFilter(tester, 'audit-action-filter', 'Projeto criado');
    await selectAuditFilter(tester, 'audit-entity-type-filter', 'Projeto');
    await selectAuditFilter(tester, 'audit-result-filter', 'Sucesso');
    await enterAuditFilter(tester, 'ID do usuário (ator)', 'ser_');
    await enterAuditFilter(tester, 'ID da entidade', 'ard_');
    await enterAuditFilter(tester, 'ID do projeto', 'roject_');
    await applyAuditFilters(tester);

    expect(api.lastParams['actorUserId'], 'ser_');
    expect(api.lastParams['entityId'], 'ard_');
    expect(api.lastParams['projectId'], 'roject_');
    expect(api.lastParams['action'], 'project.created');
    expect(api.lastParams['entityType'], 'project');
    expect(api.lastParams['result'], 'success');
    expect(find.text('Ação: Projeto criado'), findsOneWidget);
    expect(find.text('Tipo: Projeto'), findsOneWidget);
    expect(find.text('Resultado: Sucesso'), findsOneWidget);
  });

  testWidgets(
      'localized known and unknown audit events remain readable on desktop and mobile',
      (tester) async {
    final api = FakeTouchInApi()
      ..mockEvents = [
        AuditEventResponse(
          id: 'evt_known',
          timestamp: DateTime.utc(2026, 10, 20),
          companyId: 'company_1',
          actorUserId: 'user_1',
          projectId: null,
          action: 'card.reordered',
          entityType: 'card',
          entityId: 'card_1',
          result: 'success',
          metadataPayload: null,
        ),
        AuditEventResponse(
          id: 'evt_unknown',
          timestamp: DateTime.utc(2026, 10, 20),
          companyId: 'company_1',
          actorUserId: 'user_1',
          projectId: null,
          action: 'future.action',
          entityType: 'future_entity',
          entityId: 'entity_1',
          result: 'future_result',
          metadataPayload: null,
        ),
      ];

    for (final size in [const Size(1280, 800), const Size(360, 760)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(home: AdminAuditPage(key: UniqueKey(), api: api)),
      );
      await tester.pumpAndSettle();

      final known = find.text('Tarefa reordenada');
      final knownStatus = find.text('Sucesso');
      final unknown = find.text('Ação desconhecida (future.action)');
      final unknownStatus = find.text('Resultado desconhecido (future_result)');
      await tester.ensureVisible(known);
      expect(known, findsOneWidget);
      expect(knownStatus, findsOneWidget);

      final scrollable = size.width >= 860
          ? find.descendant(
              of: find.byKey(const ValueKey<String>('audit-events-table')),
              matching: find.byType(Scrollable),
            )
          : find.descendant(
              of: find.byKey(const ValueKey<String>('audit-events-cards')),
              matching: find.byType(Scrollable),
            );
      await tester.scrollUntilVisible(
        unknown,
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(unknown, findsOneWidget);
      expect(unknownStatus, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'audit date picker uses the shared square dialog shape in dark theme on desktop and mobile',
      (tester) async {
    for (final size in [const Size(1280, 800), const Size(360, 760)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: AdminAuditPage(key: UniqueKey(), api: FakeTouchInApi()),
      ));
      await tester.pumpAndSettle();
      await openAuditFilters(tester);
      for (final label in ['Data inicial', 'Data final']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        final dialog = tester.widget<Dialog>(find.byType(Dialog).last);
        expect(
            dialog.shape,
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ));
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
      if (size.width >= 860) {
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('audit-filters-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('audit-filters-button')),
        );
      } else {
        await tester.ensureVisible(find.text('Cancelar'));
        await tester.tap(find.text('Cancelar'));
      }
      await tester.pumpAndSettle();
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('date picker advances month and applies the selected date',
      (tester) async {
    final selectedDate = DateTime.now();
    final expectedDate = DateTime(
      selectedDate.year,
      selectedDate.month + 1,
      15,
    );
    final api = FakeTouchInApi();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: AdminAuditPage(api: api),
    ));
    await tester.pumpAndSettle();
    await openAuditFilters(tester);
    await tester.ensureVisible(find.text('Data inicial'));
    await tester.tap(find.text('Data inicial'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final dateLabel = '${expectedDate.day.toString().padLeft(2, '0')}/'
        '${expectedDate.month.toString().padLeft(2, '0')}/'
        '${expectedDate.year}';
    expect(find.text(dateLabel), findsOneWidget);
    await applyAuditFilters(tester);
    expect(api.lastParams['startDate']?.year, expectedDate.year);
    expect(api.lastParams['startDate']?.month, expectedDate.month);
    expect(api.lastParams['startDate']?.day, expectedDate.day);
  });

  testWidgets('page 2 HTTP 503 shows accessible error and retries page 2',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTouchInApi()
      ..mockEvents = List.generate(51, pageEvent)
      ..secondPageError = ApiException('Upstream error', statusCode: 503);
    await tester.pumpWidget(MaterialApp(home: AdminAuditPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar mais eventos'));
    await tester.pumpAndSettle();
    expect(api.requestedPages, [1, 2]);
    final failure = find.textContaining('Serviço temporariamente indisponível');
    expect(failure, findsOneWidget);
    final liveRegion = find.ancestor(
      of: failure,
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(liveRegion, findsWidgets);
    expect(
      find.text('Ação desconhecida (task.action_0)'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(api.requestedPages, [1, 2, 2]);
    expect(failure, findsNothing);
    final list = tester.widget<ListView>(find.byType(ListView));
    final delegate = list.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.estimatedChildCount, 51);
    expect(
      find.byKey(const ValueKey<String>('audit-end-of-list')),
      findsOneWidget,
    );
    expect(find.text('Todos os eventos carregados.'), findsOneWidget);
  });

  testWidgets('refresh discards pending page 2 failure and resets loading',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending = Completer<List<AuditEventResponse>>();
    final api = FakeTouchInApi()
      ..mockEvents = List.generate(100, pageEvent)
      ..secondPageResponse = pending;
    await tester.pumpWidget(MaterialApp(home: AdminAuditPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar mais eventos'));
    await tester.pump();
    expect(find.text('Carregando mais eventos...'), findsOneWidget);
    api.mockEvents = [pageEvent(999)];
    await openAuditFilters(tester);
    await applyAuditFilters(tester);
    expect(
      find.text('Ação desconhecida (task.action_999)'),
      findsOneWidget,
    );
    expect(find.text('Carregando mais eventos...'), findsNothing);
    pending
        .completeError(ApiException('Stale upstream error', statusCode: 503));
    await tester.pumpAndSettle();
    expect(api.requestedPages, [1, 2, 1]);
    expect(
      find.text('Ação desconhecida (task.action_999)'),
      findsOneWidget,
    );
    expect(find.textContaining('Stale upstream error'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'refresh discards successful page 2 response from obsolete filters',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending = Completer<List<AuditEventResponse>>();
    final api = FakeTouchInApi()
      ..mockEvents = List.generate(100, pageEvent)
      ..secondPageResponse = pending;
    await tester.pumpWidget(MaterialApp(home: AdminAuditPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar mais eventos'));
    await tester.pump();

    final latestEvent = AuditEventResponse(
      id: 'evt_latest_filter',
      timestamp: DateTime.utc(2026, 10, 21),
      companyId: 'company_1',
      actorUserId: 'user_1',
      projectId: null,
      action: 'task.latest',
      entityType: 'task',
      entityId: 'latest',
      result: 'success',
      metadataPayload: null,
    );
    api.mockEvents = [latestEvent];
    await openAuditFilters(tester);
    await applyAuditFilters(tester);
    expect(find.text('Ação desconhecida (task.latest)'), findsOneWidget);

    pending.complete([pageEvent(999)]);
    await tester.pumpAndSettle();
    expect(find.text('Ação desconhecida (task.latest)'), findsOneWidget);
    expect(find.text('Ação desconhecida (task.action_999)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('audit events have Material and remain visible in direct route',
      (tester) async {
    final api = FakeTouchInApi()
      ..mockEvents = [
        AuditEventResponse(
          id: 'evt_material',
          timestamp: DateTime.utc(2026, 10, 20),
          companyId: 'company_1',
          actorUserId: 'user_1',
          projectId: 'project_1',
          action: 'task.created',
          entityType: 'task',
          entityId: 'task_1',
          result: 'success',
          metadataPayload: null,
        ),
      ];
    await tester.pumpWidget(MaterialApp(home: AdminAuditPage(api: api)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Tarefa criada'), findsOneWidget);
    expect(find.byType(Material), findsWidgets);
  });

  testWidgets('filter button keeps finite width with production button style',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeTouchInApi();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ),
      home: AdminAuditPage(api: api),
    ));
    await tester.pumpAndSettle();
    await openAuditFilters(tester);
    expect(tester.takeException(), isNull);
    final button = find.widgetWithText(FilledButton, 'Aplicar filtros');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).width, lessThan(1280));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(api.requestedPages, [1, 1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid audit response hides parsing details', (tester) async {
    final api = FakeTouchInApi()
      ..firstError = ApiException(
          'Contrato invalido na resposta de audit events: expected list');
    await tester.pumpWidget(MaterialApp(home: AdminAuditPage(api: api)));
    await tester.pumpAndSettle();
    expect(
        find.textContaining(
            'O serviço de auditoria retornou uma resposta inválida.'),
        findsOneWidget);
    expect(find.textContaining('expected list'), findsNothing);
  });

  testWidgets('404 error permits retry without exposing exception',
      (tester) async {
    final api = FakeTouchInApi()
      ..firstError = ApiException('Proxy error', statusCode: 404);
    await tester.pumpWidget(MaterialApp(home: AdminAuditPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('O serviço de auditoria não foi encontrado.'),
        findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(api.requestedPages, [1, 1]);
    expect(find.text('Nenhum evento de auditoria encontrado.'), findsOneWidget);
  });

  for (final additionalEvents in [50, 1]) {
    testWidgets('keyboard focus survives page of $additionalEvents events',
        (tester) async {
      final mockApi = FakeTouchInApi()
        ..secondPageResponse = Completer<List<AuditEventResponse>>()
        ..mockEvents = List.generate(
          50 + additionalEvents,
          (index) => AuditEventResponse(
            id: 'evt_$index',
            timestamp: DateTime.utc(2026, 9, 25),
            companyId: 'company_1',
            actorUserId: 'user_1',
            projectId: null,
            action: 'task.action_$index',
            entityType: 'task',
            entityId: 'task_1',
            result: 'success',
            metadataPayload: null,
          ),
        );

      await tester.binding.setSurfaceSize(const Size(1200, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: AdminAuditPage(api: mockApi)));
      await tester.pumpAndSettle();

      final loadMoreFinder =
          find.widgetWithText(OutlinedButton, 'Carregar mais eventos');
      final loadMoreFocus =
          tester.widget<OutlinedButton>(loadMoreFinder).focusNode!;
      loadMoreFocus.requestFocus();
      await tester.pump();
      expect(loadMoreFocus.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(mockApi.requestedPages, [1, 2]);
      expect(loadMoreFocus.hasFocus, isTrue);
      expect(find.text('Carregando mais eventos...'), findsOneWidget);

      mockApi.secondPageResponse!.complete(
        mockApi.mockEvents.skip(50).toList(),
      );
      await tester.pumpAndSettle();
      expect(mockApi.requestedPages, [1, 2]);
      expect(tester.widget<ListView>(find.byType(ListView)).childrenDelegate,
          isA<SliverChildBuilderDelegate>());

      if (additionalEvents == 50) {
        expect(loadMoreFinder, findsOneWidget);
        expect(loadMoreFocus.hasFocus, isTrue);
        expect(
          find.byKey(const ValueKey<String>('audit-end-of-list')),
          findsNothing,
        );
      } else {
        expect(loadMoreFinder, findsNothing);
        final endLabel = find.text('Todos os eventos carregados.');
        expect(endLabel, findsOneWidget);
        expect(Focus.of(tester.element(endLabel)).hasFocus, isTrue);
        final focusedDecoration = tester
            .widget<Container>(
              find
                  .ancestor(of: endLabel, matching: find.byType(Container))
                  .first,
            )
            .decoration! as BoxDecoration;
        expect(
            (focusedDecoration.border! as Border).top.color,
            AppTheme.adminColors(Theme.of(tester.element(endLabel)))
                .selectedIndicator);
      }

      final focusedAtCompletion = FocusManager.instance.primaryFocus;
      expect(focusedAtCompletion, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(FocusManager.instance.primaryFocus, isNot(focusedAtCompletion));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('AdminAuditPage keeps filters usable in a narrow viewport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester
        .pumpWidget(MaterialApp(home: AdminAuditPage(api: FakeTouchInApi())));
    await tester.pumpAndSettle();

    await openAuditFilters(tester);
    final actor = find.widgetWithText(TextField, 'ID do usuário (ator)');
    final action = find.byKey(const ValueKey<String>('audit-action-filter'));
    expect(actor, findsOneWidget);
    expect(action, findsOneWidget);
    expect(
      tester.widget<DropdownButtonFormField<String>>(action),
      isA<DropdownButtonFormField<String>>(),
    );
    expect(tester.getTopLeft(actor).dx, tester.getTopLeft(action).dx);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('audit-result-filter')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Abrir menu'), findsOneWidget);
  });

  testWidgets('AdminAuditPage loads events and shows filters',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final mockApi = FakeTouchInApi();

    mockApi.mockEvents = [
      AuditEventResponse(
        id: 'evt_1',
        timestamp: DateTime.utc(2026, 9, 25, 12, 0, 0),
        companyId: 'company_1',
        actorUserId: 'user_1',
        projectId: 'proj_1',
        action: 'card.created',
        entityType: 'card',
        entityId: 'task_1',
        result: 'success',
        metadataPayload: null,
      ),
      AuditEventResponse(
        id: 'evt_2',
        timestamp: DateTime.utc(2026, 9, 25, 12, 5, 0),
        companyId: 'company_1',
        actorUserId: 'user_2',
        projectId: 'proj_1',
        action: 'card.deleted',
        entityType: 'card',
        entityId: 'task_1',
        result: 'failed',
        metadataPayload: null,
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminAuditPage(api: mockApi),
      ),
    ));

    expect(
      find.byKey(const ValueKey<String>('audit-loading-skeleton')),
      findsOneWidget,
    );
    final auditSkeleton = find.byKey(
      const ValueKey<String>('audit-loading-skeleton'),
    );
    final auditRegion = find.ancestor(
      of: auditSkeleton,
      matching: find.byType(WorkspaceSkeletonRegion),
    );
    expect(auditRegion, findsOneWidget);
    expect(
      find.descendant(
        of: auditRegion,
        matching: find.byType(WorkspaceSkeleton),
      ),
      findsAtLeastNWidgets(1),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();

    expect(find.text('Tarefa criada'), findsOneWidget);
    expect(find.text('Tarefa excluída'), findsOneWidget);
    expect(find.text('Sucesso'), findsOneWidget);
    expect(find.text('Falha'), findsOneWidget);

    await openAuditFilters(tester);
    await enterAuditFilter(tester, 'ID do usuário (ator)', 'user_1');
    await selectAuditFilter(
      tester,
      'audit-action-filter',
      'Tarefa criada',
    );
    await selectAuditFilter(
      tester,
      'audit-entity-type-filter',
      'Tarefa',
    );
    await enterAuditFilter(tester, 'ID da entidade', 'task_1');
    await selectAuditFilter(tester, 'audit-result-filter', 'Sucesso');

    mockApi.requestedPages.clear();
    await applyAuditFilters(tester);

    expect(mockApi.requestedPages, [1]);
    expect(mockApi.lastParams['actorUserId'], 'user_1');
    expect(mockApi.lastParams['action'], 'card.created');
    expect(mockApi.lastParams['entityType'], 'card');
    expect(mockApi.lastParams['entityId'], 'task_1');
    expect(mockApi.lastParams['result'], 'success');
  });

  testWidgets(
      'AdminAuditPage paginates correctly without gaps or duplicates and stops on short page',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final mockApi = FakeTouchInApi();

    mockApi.mockEvents = List.generate(
        60,
        (index) => AuditEventResponse(
              id: 'evt_$index',
              timestamp: DateTime.utc(2026, 9, 25, 12, 0, 0),
              companyId: 'company_1',
              actorUserId: 'user_1',
              projectId: 'proj_1',
              action: 'task.action_$index',
              entityType: 'task',
              entityId: 'task_1',
              result: 'success',
              metadataPayload: null,
            ));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminAuditPage(api: mockApi),
      ),
    ));

    await tester.pumpAndSettle();

    expect(mockApi.requestedPages, [1]);
    final list = find.byType(ListView);

    var drags = 0;
    while (mockApi.requestedPages.length < 2 && drags < 40) {
      await tester.drag(list, const Offset(0, -500));
      await tester.pumpAndSettle();
      drags++;
    }

    expect(mockApi.requestedPages, [1, 2]);

    await tester.drag(list, const Offset(0, 20000));
    await tester.pumpAndSettle();
    drags = 0;
    while (find.text('Ação desconhecida (task.action_50)').evaluate().isEmpty &&
        drags < 40) {
      await tester.drag(list, const Offset(0, -500));
      await tester.pumpAndSettle();
      drags++;
    }
    expect(
      find.text('Ação desconhecida (task.action_50)'),
      findsOneWidget,
    );
    drags = 0;

    while (find.text('Ação desconhecida (task.action_59)').evaluate().isEmpty &&
        drags < 40) {
      await tester.drag(list, const Offset(0, -500));
      await tester.pumpAndSettle();
      drags++;
    }
    expect(
      find.text('Ação desconhecida (task.action_59)'),
      findsOneWidget,
    );

    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(mockApi.requestedPages, [1, 2]);

    final listView = tester.widget<ListView>(list);
    final delegate = listView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.estimatedChildCount, 60);
  });
}
