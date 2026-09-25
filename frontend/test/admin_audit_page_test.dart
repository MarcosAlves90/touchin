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
    };
    return mockEvents;
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
        result: 'success',
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
    expect(find.text('task.deleted - success'), findsOneWidget);
    expect(find.textContaining('user_1'), findsOneWidget);
    expect(find.textContaining('user_2'), findsOneWidget);

    // Enter filters and click apply
    await tester.enterText(find.widgetWithText(TextField, 'Actor User ID'), 'user_1');
    await tester.enterText(find.widgetWithText(TextField, 'Action'), 'task.created');

    await tester.tap(find.text('Apply Filters'));
    await tester.pump();

    expect(mockApi.lastParams['page'], 1);
    expect(mockApi.lastParams['actorUserId'], 'user_1');
    expect(mockApi.lastParams['action'], 'task.created');
  });
}
