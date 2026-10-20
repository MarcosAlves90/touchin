import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page.dart';
import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/network/api_client.dart';

class FakeTouchInApi extends TouchInApi {
  List<AuditEventResponse> mockEvents = [];
  Object? firstError;
  Map<String, dynamic> lastParams = {};
  List<int> requestedPages = [];

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
    
    // Simulate pagination
    int start = (page - 1) * limit;
    if (start >= mockEvents.length) {
      return [];
    }
    int end = start + limit;
    if (end > mockEvents.length) {
      end = mockEvents.length;
    }
    return mockEvents.sublist(start, end);
  }
}

void main() {
  testWidgets('audit events render without an inherited Scaffold or Material',
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

    // The authenticated audit route renders the page directly, without a
    // Scaffold or Material supplied by its parent.
    await tester.pumpWidget(MaterialApp(home: AdminAuditPage(api: api)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('task.created - success'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('audit filter button lays out with the production button theme',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final api = FakeTouchInApi();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ),
      home: Scaffold(body: AdminAuditPage(api: api)),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    final applyButton = find.widgetWithText(ElevatedButton, 'Apply Filters');
    expect(applyButton, findsOneWidget);
    expect(tester.getSize(applyButton).width, lessThan(1280));
    await tester.tap(applyButton);
    await tester.pump();
    expect(api.requestedPages, [1, 1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid audit response does not show parser details', (tester) async {
    final api = FakeTouchInApi()
      ..firstError = ApiException('Contrato invalido na resposta de audit events: expected list');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAuditPage(api: api))));
    await tester.pumpAndSettle();
    expect(find.text('O serviço de auditoria retornou uma resposta inválida.'), findsOneWidget);
    expect(find.textContaining('expected list'), findsNothing);
  });

  testWidgets('audit error keeps status understandable and retry recovers', (tester) async {
    final api = FakeTouchInApi()..firstError = ApiException('Proxy error', statusCode: 404);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminAuditPage(api: api))));
    await tester.pumpAndSettle();
    expect(find.text('O serviço de auditoria não foi encontrado.'), findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(api.requestedPages, [1, 1]);
    expect(find.text('Nenhum evento de auditoria encontrado.'), findsOneWidget);
  });

  testWidgets('AdminAuditPage loads events and shows filters', (WidgetTester tester) async {
    final mockApi = FakeTouchInApi();

    mockApi.mockEvents = [
      AuditEventResponse(
        id: 'evt_1',
        timestamp: DateTime.utc(2026, 9, 25, 12, 0, 0),
        companyId: 'company_1',
        actorUserId: 'user_1',
        projectId: 'proj_1',
        action: 'task.created',
        entityType: 'task',
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
        action: 'task.deleted',
        entityType: 'task',
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

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('task.created - success'), findsOneWidget);
    expect(find.text('task.deleted - failed'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Actor User ID'), 'user_1');
    await tester.enterText(find.widgetWithText(TextField, 'Action'), 'task.created');
    await tester.enterText(find.widgetWithText(TextField, 'Entity ID'), 'task_1');
    await tester.enterText(find.widgetWithText(TextField, 'Result'), 'success');

    mockApi.requestedPages.clear();
    await tester.tap(find.text('Apply Filters'));
    await tester.pump();

    expect(mockApi.requestedPages, [1]);
    expect(mockApi.lastParams['actorUserId'], 'user_1');
    expect(mockApi.lastParams['action'], 'task.created');
    expect(mockApi.lastParams['entityId'], 'task_1');
    expect(mockApi.lastParams['result'], 'success');
  });

  testWidgets('AdminAuditPage paginates correctly without gaps or duplicates and stops on short page', (WidgetTester tester) async {
    final mockApi = FakeTouchInApi();

    // Create 60 items
    mockApi.mockEvents = List.generate(60, (index) => AuditEventResponse(
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
    
    // Scroll through the list to force loading page 2
    int drags = 0;
    while (find.text('task.action_50 - success').evaluate().isEmpty && drags < 40) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      drags++;
    }

    // Must have requested exactly page 1 and page 2
    expect(mockApi.requestedPages, [1, 2]);
    expect(find.text('task.action_50 - success'), findsOneWidget);
    
    // Continue scrolling to 59
    while (find.text('task.action_59 - success').evaluate().isEmpty && drags < 40) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      drags++;
    }
    expect(find.text('task.action_59 - success'), findsOneWidget);
    
    // Attempt another scroll past the end to ensure it DOES NOT request page 3
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    
    expect(mockApi.requestedPages, [1, 2]); // Should still only have requested pages 1 and 2

    // Validate explicitly that the collection has exactly 60 events loaded
    // Since _hasMore becomes false, the itemCount should be exactly 60
    final listView = tester.widget<ListView>(find.byType(ListView));
    final delegate = listView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.estimatedChildCount, 60);
  });
}
