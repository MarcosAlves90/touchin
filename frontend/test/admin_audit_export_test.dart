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
  Completer<AuditCsvExport>? exportResponse;
  Object? exportError;
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

AuditEventResponse event(int index) => AuditEventResponse(
  id: 'evt_$index',
  timestamp: DateTime.utc(2026, 10, 20),
  companyId: 'company_1',
  actorUserId: 'user_1',
  projectId: null,
  action: 'card.moved',
  entityType: 'card',
  entityId: 'card_$index',
  result: 'success',
  metadataPayload: null,
);

void main() {
  testWidgets(
    'export sends the same active filters as the listing and saves it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final api = FakeAuditExportApi(events: [event(1), event(2)]);
      String? savedFilename;
      Uint8List? savedBytes;

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAuditPage(
            api: api,
            saveAuditExport: (filename, bytes) async {
              savedFilename = filename;
              savedBytes = bytes;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'ID do usuário responsável'),
        'user-9',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Ação'),
        'card.moved',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Tipo de entidade'),
        'card',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'ID da entidade'),
        'card-9',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'ID do projeto'),
        'proj-9',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Resultado'),
        'success',
      );

      await tester.ensureVisible(find.text('Data Inicial'));
      await tester.tap(find.text('Data Inicial'));
      await tester.pumpAndSettle();
      final selectedDay = '15';
      await tester.tap(find.text(selectedDay).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      final listParams = Map<String, dynamic>.from(api.listParams!);

      await tester.ensureVisible(find.text('Exportar CSV'));
      await tester.tap(find.text('Exportar CSV'));
      await tester.pumpAndSettle();

      expect(api.exportCalls, 1);
      expect(api.exportParams, listParams);
      expect(savedFilename, 'audit-events.csv');
      expect(savedBytes, Uint8List.fromList([1, 2, 3]));
      expect(find.text('Exportação concluída: 2 registros.'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('export shows progress, completion and no circular spinner', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final api = FakeAuditExportApi(events: [event(1), event(2), event(3)])
      ..exportResponse = Completer<AuditCsvExport>();
    String? savedFilename;

    await tester.pumpWidget(
      MaterialApp(
        home: AdminAuditPage(
          api: api,
          saveAuditExport: (filename, _) async {
            savedFilename = filename;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exportar CSV'));
    await tester.pump();

    expect(find.text('Exportando...'), findsOneWidget);
    expect(find.text('Exportando registros...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Exportando...'),
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
      ),
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
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Exportação concluída: 3 registros.'), findsOneWidget);
    expect(savedFilename, 'audit-events.csv');

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('empty export reports no data without saving a file', (
    tester,
  ) async {
    final api = FakeAuditExportApi()..exportResponse = null;
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AdminAuditPage(
          api: api,
          saveAuditExport: (_, __) async {
            saved = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum registro corresponde aos filtros.'),
      findsOneWidget,
    );
    expect(saved, isFalse);
    expect(api.exportCalls, 1);
  });

  testWidgets('export failure is announced and can be retried', (tester) async {
    final api = FakeAuditExportApi(events: [event(1)])
      ..exportError = ApiException('Upstream error', statusCode: 503);
    var saved = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AdminAuditPage(
          api: api,
          saveAuditExport: (_, __) async {
            saved++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exportar CSV'));
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
    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();

    expect(api.exportCalls, 2);
    expect(saved, 1);
    expect(find.text('Exportação concluída: 1 registro.'), findsOneWidget);
  });

  testWidgets('non-web platform reports the download limitation', (
    tester,
  ) async {
    final api = FakeAuditExportApi(events: [event(1)]);

    await tester.pumpWidget(MaterialApp(home: AdminAuditPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();

    expect(
      find.text('O download de arquivos está disponível apenas na versão web.'),
      findsOneWidget,
    );
  });

  testWidgets('export control and states fit desktop and mobile layouts', (
    tester,
  ) async {
    for (final size in [const Size(1280, 800), const Size(360, 760)]) {
      await tester.binding.setSurfaceSize(size);
      final api = FakeAuditExportApi(events: [event(1)]);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminAuditPage(api: api, saveAuditExport: (_, __) async {}),
        ),
      );
      await tester.pumpAndSettle();

      final exportButton = find.text('Exportar CSV');
      await tester.ensureVisible(exportButton);
      expect(exportButton, findsOneWidget);
      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      expect(find.text('Exportação concluída: 1 registro.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
