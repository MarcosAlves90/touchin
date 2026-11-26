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
  testWidgets('audit table shows the actor name above the id', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAuditRow(
      tester,
      authorEvent(actorUserId: 'user_42', actorName: 'Marina Costa'),
      mobile: false,
    );

    final name = find.text('Marina Costa');
    final id = find.text('user_42');
    expect(name, findsOneWidget);
    expect(id, findsOneWidget);
    expect(
      tester.getTopLeft(name).dy,
      lessThan(tester.getTopLeft(id).dy),
      reason: 'audit_author_name_above_id',
    );
    expect(
      tester.getTopLeft(name).dx,
      closeTo(tester.getTopLeft(id).dx, 1),
      reason: 'audit_author_name_and_id_left_aligned',
    );

    final style = tester.widget<Text>(id).style!;
    final colors = Theme.of(tester.element(name)).colorScheme;
    expect(style.color, colors.onSurfaceVariant,
        reason: 'audit_author_id_uses_muted_style');
    expect(style.fontFamily, 'monospace',
        reason: 'audit_author_id_uses_technical_id_style');
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

  testWidgets('mobile audit card keeps the same author hierarchy',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await pumpAuditRow(
        tester,
        authorEvent(actorUserId: 'user_42', actorName: 'Marina Costa'),
        mobile: true,
        theme: theme,
      );
      final name = find.text('Marina Costa');
      final id = find.text('user_42');
      expect(name, findsOneWidget);
      expect(id, findsOneWidget);
      expect(
        tester.getTopLeft(name).dy,
        lessThan(tester.getTopLeft(id).dy),
        reason: 'audit_author_card_name_above_id',
      );
      expect(
        tester.getTopLeft(name).dx,
        closeTo(tester.getTopLeft(id).dx, 1),
        reason: 'audit_author_card_name_and_id_left_aligned',
      );
      expect(tester.takeException(), isNull);
    }
  });
}
