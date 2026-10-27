import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page_widgets.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

void main() {
  testWidgets(
      'workspace header omits blank copy and stays semantic at 200% text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: WorkspaceHeader(
                title: 'Administrar projetos',
                description: '',
                actions: <Widget>[
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Criar projeto'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.text('Administrar projetos'))
          .flagsCollection
          .isHeader,
      isTrue,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == '',
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('workspace metric card keeps icon, value and helper readable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: WorkspaceMetricCard(
                icon: Icons.groups_rounded,
                label: 'Colaboradores',
                value: '14',
                helper: 'Perfis cadastrados na empresa.',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
    expect(find.text('Colaboradores'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('Perfis cadastrados na empresa.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('audit copy action meets the 48 pixel target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: AuditTechnicalId(
              value: 'event-id',
              copyLabel: 'ID do evento',
            ),
          ),
        ),
      ),
    );

    final copyButton = find.byTooltip('Copiar ID do evento');
    expect(copyButton, findsOneWidget);
    expect(tester.getSize(copyButton), const Size(48, 48));
  });
}
