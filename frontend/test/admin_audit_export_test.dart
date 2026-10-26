import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page.dart';

class FakeAuditExportApi extends TouchInApi {
  FakeAuditExportApi({this.events = const []});

  final List<AuditEventResponse> events;
  Map<String, dynamic>? listParams;
  Map<String, dynamic>? exportParams;
  Completer<List<AuditEventResponse>>? listResponse;
  Completer<AuditCsvExport>? exportResponse;
  Object? listError;
  Object? exportError;
  int listCalls = 0;
  int exportCalls = 0;

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
    listCalls++;
    listParams = {
      'startDate': startDate,
      'endDate': endDate,
      'actorUserId': actorUserId,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'projectId': projectId,
      'result': result,
    };
    if (listError case final error?) {
      throw error;
    }
    if (listResponse != null) {
      return listResponse!.future;
    }
    return events;
  }

  @override
  Future<AuditCsvExport> exportAuditEvents({
    DateTime? startDate,
    DateTime? endDate,
    String? actorUserId,
    String? action,
    String? entityType,
    String? entityId,
    String? projectId,
    String? result,
  }) async {
    exportCalls++;
    exportParams = {
      'startDate': startDate,
      'endDate': endDate,
      'actorUserId': actorUserId,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'projectId': projectId,
      'result': result,
    };
    if (exportError case final error?) {
      throw error;
    }
    if (exportResponse != null) {
      return exportResponse!.future;
    }
    return AuditCsvExport(
      filename: 'audit-events.csv',
      bytes: Uint8List.fromList([1, 2, 3]),
      rowCount: events.length,
    );
  }
}

AuditEventResponse event(
  int index, {
  String action = 'card.moved',
  String result = 'success',
  String actorUserId = 'user_1',
  String? projectId,
  Map<String, dynamic>? metadataPayload,
}) {
  return AuditEventResponse(
    id: 'evt_$index',
    timestamp:
        DateTime.utc(2026, 10, 20, 12, 30, 15).add(Duration(minutes: index)),
    companyId: 'company_1',
    actorUserId: actorUserId,
    projectId: projectId,
    action: action,
    entityType: 'card',
    entityId: 'card_$index',
    result: result,
    metadataPayload: metadataPayload,
  );
}

Future<void> pumpPage(
  WidgetTester tester,
  FakeAuditExportApi api, {
  Size size = const Size(1280, 800),
  Future<void> Function(String filename, Uint8List bytes)? saveAuditExport,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: AdminAuditPage(
        api: api,
        saveAuditExport: saveAuditExport ?? (_, __) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openFilters(WidgetTester tester) async {
  final button = find.byKey(const ValueKey<String>('audit-filters-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> applyFilters(WidgetTester tester) async {
  final button = find.byKey(const ValueKey<String>('audit-apply-filters'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> enterFilter(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.widgetWithText(TextField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

void main() {
  testWidgets('desktop renders an aligned table and opens event details', (
    tester,
  ) async {
    final api = FakeAuditExportApi(
      events: [
        event(1, metadataPayload: {'from': 'todo', 'to': 'doing'}),
        event(2, result: 'failed', actorUserId: 'user_2', projectId: 'proj_1'),
      ],
    );

    await pumpPage(tester, api);

    expect(
      find.byKey(const ValueKey<String>('audit-events-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('audit-events-cards')),
      findsNothing,
    );
    for (final heading in [
      'Data/hora (local)',
      'Evento',
      'Resultado',
      'Ator',
      'Recurso',
      'Projeto',
    ]) {
      expect(find.text(heading), findsOneWidget);
    }
    expect(find.text('Tarefa movida'), findsNWidgets(2));
    expect(find.text('Sucesso'), findsOneWidget);
    expect(find.text('Falha'), findsOneWidget);
    expect(find.text('user_1'), findsOneWidget);
    expect(find.text('proj_1'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('audit-event-row-evt_1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('audit-event-details')),
      findsOneWidget,
    );
    expect(find.text('Detalhes do evento'), findsOneWidget);
    expect(find.textContaining('"from": "todo"'), findsOneWidget);
    expect(find.byTooltip('Copiar ID do evento'), findsOneWidget);
    expect(find.text('2026-10-20T12:31:15Z'), findsOneWidget);

    await tester.tap(find.byTooltip('Fechar detalhes'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes do evento'), findsNothing);
  });

  testWidgets('mobile renders cards and opens the dedicated filter panel', (
    tester,
  ) async {
    final api = FakeAuditExportApi(events: [event(1)]);

    await pumpPage(tester, api, size: const Size(360, 760));

    expect(
      find.byKey(const ValueKey<String>('audit-events-cards')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('audit-events-table')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('audit-event-card-evt_1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await openFilters(tester);
    expect(
      find.byKey(const ValueKey<String>('audit-filter-sheet')),
      findsOneWidget,
    );

    await enterFilter(tester, 'ID do usuário (ator)', 'mobile-user');
    await applyFilters(tester);

    expect(api.listParams!['actorUserId'], 'mobile-user');
    expect(find.text('Ator: mobile-user'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('audit-filter-sheet')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text switches to cards and remains usable', (
    tester,
  ) async {
    final api = FakeAuditExportApi(events: [event(1)]);

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          );
        },
        home: AdminAuditPage(api: api, saveAuditExport: (_, __) async {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('audit-events-cards')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('audit-events-table')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('audit-event-card-evt_1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial loading uses a skeleton instead of a circular spinner', (
    tester,
  ) async {
    final api = FakeAuditExportApi()
      ..listResponse = Completer<List<AuditEventResponse>>();

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AdminAuditPage(api: api)));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('audit-loading-skeleton')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    api.listResponse!.complete([event(1)]);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('audit-loading-skeleton')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('audit-event-row-evt_1')),
      findsOneWidget,
    );
  });

  testWidgets('export sends the applied filter snapshot and saves the file', (
    tester,
  ) async {
    final api = FakeAuditExportApi(events: [event(1), event(2)]);
    String? savedFilename;
    Uint8List? savedBytes;

    await pumpPage(
      tester,
      api,
      saveAuditExport: (filename, bytes) async {
        savedFilename = filename;
        savedBytes = bytes;
      },
    );

    await openFilters(tester);
    await enterFilter(tester, 'ID do usuário (ator)', 'applied-user');
    await enterFilter(tester, 'Ação', 'card.moved');
    await enterFilter(tester, 'Tipo de entidade', 'card');
    await enterFilter(tester, 'ID da entidade', 'card-9');
    await enterFilter(tester, 'ID do projeto', 'proj-9');
    await enterFilter(tester, 'Resultado', 'success');
    await tester.tap(find.text('Data inicial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await applyFilters(tester);

    final listParams = Map<String, dynamic>.from(api.listParams!);
    expect(find.text('Ator: applied-user'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('audit-export-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('audit-export-button')));
    await tester.pumpAndSettle();

    expect(api.exportCalls, 1);
    expect(api.exportParams, listParams);
    expect(savedFilename, 'audit-events.csv');
    expect(savedBytes, Uint8List.fromList([1, 2, 3]));
    expect(
      find.text('Exportação concluída: 2 registros em UTC.'),
      findsOneWidget,
    );
    expect(find.textContaining('timestamps em UTC'), findsWidgets);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('export ignores unapplied drafts and warns about the scope', (
    tester,
  ) async {
    final api = FakeAuditExportApi(events: [event(1)]);

    await pumpPage(tester, api);

    await openFilters(tester);
    await enterFilter(tester, 'ID do usuário (ator)', 'applied-user');
    await applyFilters(tester);

    await openFilters(tester);
    await enterFilter(tester, 'ID do usuário (ator)', 'draft-user');
    await tester.pump();

    expect(
      find.text(
        'Alterações nos filtros ainda não aplicadas. A lista e o CSV usam os filtros aplicados.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('audit-export-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('audit-export-button')));
    await tester.pumpAndSettle();

    expect(api.exportParams!['actorUserId'], 'applied-user');
    expect(api.exportParams!['actorUserId'], isNot('draft-user'));
  });

  testWidgets('export shows progress, completion and no circular spinner', (
    tester,
  ) async {
    final api = FakeAuditExportApi(events: [event(1), event(2), event(3)])
      ..exportResponse = Completer<AuditCsvExport>();
    String? savedFilename;

    await pumpPage(
      tester,
      api,
      saveAuditExport: (filename, _) async {
        savedFilename = filename;
      },
    );

    await tester.tap(find.byKey(const ValueKey<String>('audit-export-button')));
    await tester.pump();

    expect(find.text('Exportando...'), findsOneWidget);
    expect(find.text('Exportando registros...'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('audit-export-progress')),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('audit-export-button')),
    );
    expect(button.onPressed, isNull);

    api.exportResponse!.complete(
      AuditCsvExport(
        filename: 'audit-events.csv',
        bytes: Uint8List.fromList([1, 2, 3]),
        rowCount: 3,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Exportando...'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('audit-export-progress')),
      findsNothing,
    );
    expect(
      find.text('Exportação concluída: 3 registros em UTC.'),
      findsOneWidget,
    );
    expect(savedFilename, 'audit-events.csv');
  });

  testWidgets('export feedback is suppressed after applied filters change', (
    tester,
  ) async {
    final api = FakeAuditExportApi(events: [event(1)])
      ..exportResponse = Completer<AuditCsvExport>();
    var saved = 0;

    await pumpPage(
      tester,
      api,
      saveAuditExport: (_, __) async {
        saved++;
      },
    );

    await tester.tap(find.byKey(const ValueKey<String>('audit-export-button')));
    await tester.pump();
    expect(find.text('Exportando...'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey<String>('audit-filters-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await enterFilter(tester, 'ID do usuário (ator)', 'new-user');
    await tester.tap(
      find.byKey(const ValueKey<String>('audit-apply-filters')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ator: new-user'), findsOneWidget);

    api.exportResponse!.complete(
      AuditCsvExport(
        filename: 'audit-events.csv',
        bytes: Uint8List.fromList([1, 2, 3]),
        rowCount: 1,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(saved, 1);
    expect(find.textContaining('Exportação concluída'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('audit-export-progress')),
      findsNothing,
    );
    expect(find.text('Exportando...'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty export reports no data without saving a file', (
    tester,
  ) async {
    final api = FakeAuditExportApi();
    var saved = false;

    await pumpPage(
      tester,
      api,
      saveAuditExport: (_, __) async {
        saved = true;
      },
    );

    await tester.tap(find.byKey(const ValueKey<String>('audit-export-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum registro corresponde aos filtros aplicados.'),
      findsOneWidget,
    );
    expect(saved, isFalse);
  });

  testWidgets('export failure is announced and can be retried', (tester) async {
    final api = FakeAuditExportApi(events: [event(1)])
      ..exportError = ApiException('Upstream error', statusCode: 503);
    var saved = 0;

    await pumpPage(
      tester,
      api,
      saveAuditExport: (_, __) async {
        saved++;
      },
    );

    await tester.tap(find.byKey(const ValueKey<String>('audit-export-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Serviço temporariamente indisponível. Tente novamente.'),
      findsOneWidget,
    );
    final failure = find.textContaining('Serviço temporariamente indisponível');
    final liveRegion = find.ancestor(
      of: failure,
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(liveRegion, findsWidgets);
    expect(saved, 0);

    api.exportError = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(api.exportCalls, 2);
    expect(saved, 1);
    expect(
      find.text('Exportação concluída: 1 registro em UTC.'),
      findsOneWidget,
    );
  });

  testWidgets('successful export status clears when the filter draft changes', (
    tester,
  ) async {
    final api = FakeAuditExportApi(events: [event(1)]);

    await pumpPage(tester, api);

    await tester.tap(find.byKey(const ValueKey<String>('audit-export-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Exportação concluída: 1 registro em UTC.'),
      findsOneWidget,
    );

    await openFilters(tester);
    await enterFilter(tester, 'ID do usuário (ator)', 'changed');
    await tester.pump();

    expect(
      find.text('Exportação concluída: 1 registro em UTC.'),
      findsNothing,
    );
    expect(
      find.text(
        'Alterações nos filtros ainda não aplicadas. A lista e o CSV usam os filtros aplicados.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancelling mobile filters keeps a completed export status', (
    tester,
  ) async {
    final api = FakeAuditExportApi(events: [event(1)]);

    await pumpPage(tester, api, size: const Size(360, 760));
    await tester.tap(find.byKey(const ValueKey<String>('audit-export-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Exportação concluída: 1 registro em UTC.'),
      findsOneWidget,
    );

    await openFilters(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('audit-cancel-filters')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('audit-cancel-filters')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('audit-filter-sheet')),
      findsNothing,
    );
    expect(
      find.text('Exportação concluída: 1 registro em UTC.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty, error and end-of-list states are explicit', (
    tester,
  ) async {
    final emptyApi = FakeAuditExportApi();
    await pumpPage(tester, emptyApi);
    expect(
      find.byKey(const ValueKey<String>('audit-empty-state')),
      findsOneWidget,
    );
    expect(find.text('Nenhum evento de auditoria encontrado.'), findsOneWidget);

    final errorApi = FakeAuditExportApi()
      ..listError = ApiException('Upstream error', statusCode: 503);
    await tester.pumpWidget(
      MaterialApp(home: AdminAuditPage(key: UniqueKey(), api: errorApi)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('audit-error-state')),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);

    final listApi = FakeAuditExportApi(events: [event(1)]);
    await tester.pumpWidget(
      MaterialApp(home: AdminAuditPage(key: UniqueKey(), api: listApi)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('audit-end-of-list')),
      findsOneWidget,
    );
    expect(find.text('Todos os eventos carregados.'), findsOneWidget);
  });

  testWidgets('active filters are shown and can be cleared', (tester) async {
    final api = FakeAuditExportApi(events: [event(1)]);

    await pumpPage(tester, api);
    await openFilters(tester);
    await enterFilter(tester, 'ID do usuário (ator)', 'filter-user');
    await applyFilters(tester);

    expect(find.text('Ator: filter-user'), findsOneWidget);
    expect(api.listParams!['actorUserId'], 'filter-user');

    await tester.tap(
      find.byKey(const ValueKey<String>('audit-clear-filters')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ator: filter-user'), findsNothing);
    expect(api.listParams!['actorUserId'], isNull);
    expect(
      find.text('Nenhum filtro aplicado — todos os eventos da empresa.'),
      findsOneWidget,
    );
  });

  testWidgets('non-web platform reports the download limitation', (
    tester,
  ) async {
    final api = FakeAuditExportApi(events: [event(1)]);

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AdminAuditPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('audit-export-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('O download de arquivos está disponível apenas na versão web.'),
      findsOneWidget,
    );
  });

  testWidgets('desktop and mobile preserve the export entry point', (
    tester,
  ) async {
    for (final size in [const Size(1280, 800), const Size(360, 760)]) {
      await tester.binding.setSurfaceSize(size);
      final api = FakeAuditExportApi(events: [event(1)]);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAuditPage(
            key: UniqueKey(),
            api: api,
            saveAuditExport: (_, __) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exportButton = find.byKey(
        const ValueKey<String>('audit-export-button'),
      );
      await tester.ensureVisible(exportButton);
      expect(exportButton, findsOneWidget);
      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Exportação concluída: 1 registro em UTC.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
