import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page_widgets.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

AuditEventResponse authorEvent({
  required String? actorUserId,
  required String? actorName,
}) =>
    AuditEventResponse(
      id: 'event_1',
      timestamp: DateTime.utc(2026, 11, 18, 12),
      companyId: 'company_1',
      actorUserId: actorUserId,
      actorName: actorName,
      projectId: 'project_1',
      action: 'task.update',
      entityType: 'task',
      entityId: 'task_1',
      result: 'success',
      metadataPayload: null,
    );

Future<void> pumpAuditRow(
  WidgetTester tester,
  AuditEventResponse event, {
  required bool mobile,
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(Size(mobile ? 360 : 1280, 800));
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    home: Scaffold(
      body: Center(
        child: mobile
            ? AuditEventCard(
                event: event,
                actionLabel: 'Tarefa atualizada',
                resultLabel: 'Sucesso',
                onTap: () {},
              )
            : AuditEventTableRow(
                event: event,
                actionLabel: 'Tarefa atualizada',
                resultLabel: 'Sucesso',
                onTap: () {},
              ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('audit table prioritizes names rather than technical IDs',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAuditRow(
      tester,
      authorEvent(actorUserId: 'user_42', actorName: 'Marina Costa')
          .copyWith(entityName: 'Revisar checklist', projectName: 'Atlas'),
      mobile: false,
    );

    expect(find.text('Marina Costa'), findsOneWidget);
    expect(find.text('Revisar checklist'), findsOneWidget);
    expect(find.text('Atlas'), findsOneWidget);
    for (final id in ['user_42', 'task_1', 'project_1']) {
      expect(find.text(id), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown and system actors keep their labels and optional id',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpAuditRow(
      tester,
      authorEvent(actorUserId: 'user_removed', actorName: null),
      mobile: false,
    );
    expect(find.text('Usuário desconhecido'), findsOneWidget);
    expect(find.text('user_removed'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Usuário desconhecido')).dy,
      lessThan(tester.getTopLeft(find.text('user_removed')).dy),
      reason: 'audit_unknown_author_name_above_id',
    );

    await pumpAuditRow(
      tester,
      authorEvent(actorUserId: null, actorName: null),
      mobile: false,
    );
    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('user_removed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile audit card shows names in light and dark',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await pumpAuditRow(
        tester,
        authorEvent(actorUserId: 'user_42', actorName: 'Marina Costa')
            .copyWith(entityName: 'Revisar checklist', projectName: 'Atlas'),
        mobile: true,
        theme: theme,
      );
      expect(find.text('Marina Costa'), findsOneWidget);
      expect(find.text('Revisar checklist'), findsOneWidget);
      expect(find.text('Atlas'), findsOneWidget);
      for (final id in ['user_42', 'task_1', 'project_1']) {
        expect(find.text(id), findsNothing);
      }
      expect(tester.takeException(), isNull);
    }
  });
}
