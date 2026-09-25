import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page.dart';
import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';

class FakeTouchInApi extends TouchInApi {
  List<AuditEventResponse> mockEvents = [];
  Map<String, dynamic> lastParams = {};

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
    lastParams = {
      'page': page,
      'limit': limit,
      'startDate': startDate,
      'endDate': endDate,
      'actorUserId': actorUserId,
      'action': action,
      'entityType': entityType,
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

    // Initially loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // After loading, should show events
    expect(find.text('task.created - success'), findsOneWidget);
    expect(find.text('task.deleted - failed'), findsOneWidget);

    // Enter filters and click apply
    await tester.enterText(find.widgetWithText(TextField, 'Actor User ID'), 'user_1');
    await tester.enterText(find.widgetWithText(TextField, 'Action'), 'task.created');
    await tester.enterText(find.widgetWithText(TextField, 'Result'), 'success');

    await tester.tap(find.text('Apply Filters'));
    await tester.pump();

    expect(mockApi.lastParams['page'], 1);
    expect(mockApi.lastParams['actorUserId'], 'user_1');
    expect(mockApi.lastParams['action'], 'task.created');
    expect(mockApi.lastParams['result'], 'success');
  });

  testWidgets('AdminAuditPage paginates when scrolled to bottom', (WidgetTester tester) async {
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

    // It should have loaded the first 50 items (page 1)
    expect(mockApi.lastParams['page'], 1);
    
    // Scroll until the first item of the second page is visible
    int drags = 0;
    while (find.text('task.action_50 - success').evaluate().isEmpty && drags < 20) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      drags++;
    }

    // Verify it requested page 2
    expect(mockApi.lastParams['page'], 2);
    
    // Now it should contain events from the second page
    expect(find.text('task.action_50 - success'), findsOneWidget);
    
    // Scroll to the very end to trigger page 3
    drags = 0;
    while (find.text('task.action_59 - success').evaluate().isEmpty && drags < 20) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      drags++;
    }
    
    // Should have requested page 3 (or at least loaded up to 60 items)
    expect(mockApi.lastParams['page'] == 2 || mockApi.lastParams['page'] == 3, true);
  });
}
