import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page_widgets.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/theme/app_theme.dart';
import 'package:touchin_flutter/features/auth/presentation/widgets/auth_shell.dart';

void main() {
  testWidgets('page header auth shares workspace typography and back action', (tester) async {
    var backs = 0;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      const WorkspaceHeader(title: 'Workspace', description: ''),
      AuthPageHeading(title: 'Autenticação', onBack: () => backs++),
    ]))));
    expect(tester.widget<Text>(find.text('Autenticação')).style,
        tester.widget<Text>(find.text('Workspace')).style);
    expect(find.ancestor(of: find.text('Autenticação'), matching: find.byType(WorkspaceHeader)), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    expect(backs, 1);
  });
  testWidgets('page header kicker contrast in both themes', (tester) async {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final header = Function.apply(WorkspaceHeader.new, [], {
        #kicker: 'EQUIPE', #title: 'Título', #description: '',
      }) as Widget;
      await tester.pumpWidget(MaterialApp(theme: theme, home: Scaffold(body: header)));
      await tester.pumpAndSettle();
      final foreground = tester.widget<Text>(find.text('EQUIPE')).style!.color!;
      final background = theme.scaffoldBackgroundColor;
      final l1 = foreground.computeLuminance();
      final l2 = background.computeLuminance();
      final ratio = (l1 > l2 ? l1 + .05 : l2 + .05) / (l1 > l2 ? l2 + .05 : l1 + .05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });
  testWidgets('page header typography and buttons are consistent', (tester) async {
    for (final compact in [false, true]) {
      final header = Function.apply(WorkspaceHeader.new, [], {
        #kicker: 'EQUIPE', #title: 'Título', #description: 'Descrição', #compact: compact,
        #actions: <Widget>[FilledButton(onPressed: () {}, child: const Text('Criar')),
          OutlinedButton(onPressed: () {}, child: const Text('Filtrar'))],
      }) as Widget;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: header)));
      final context = tester.element(find.text('Título'));
      final theme = Theme.of(context);
      expect(tester.widget<Text>(find.text('Título')).style!.fontSize, theme.textTheme.headlineMedium!.fontSize);
      expect(tester.widget<Text>(find.text('Descrição')).style!.fontSize, theme.textTheme.bodyLarge!.fontSize);
      expect(tester.widget<Text>(find.text('EQUIPE')).style!.color, isNotNull);
      expect(tester.getSize(find.byType(FilledButton)).height, 48);
      expect(tester.getSize(find.byType(OutlinedButton)).height, 48);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('page header aligns desktop actions', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      width: 800,
      child: WorkspaceHeader(title: 'Administrar equipe', description: 'Acompanhe a equipe e gerencie cadastros e registros de ponto para toda a sua empresa.', maxContentWidth: 620,
        actions: [SizedBox(width: 210, child: FilledButton(onPressed: () {}, child: const Text('Novo funcionário')))]),
    ))));
    expect(tester.getTopRight(find.text('Novo funcionário')).dy,
        lessThan(tester.getBottomLeft(find.text('Acompanhe a equipe e gerencie cadastros e registros de ponto para toda a sua empresa.')).dy),
        reason: 'page_header_alignment');
    expect(tester.getTopRight(find.byType(FilledButton)).dx, 800,
        reason: 'page_header_alignment');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'redesign cards use rounded surfaces and vertical metric hierarchy',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: const MediaQuery(
          data: MediaQueryData(
              size: Size(320, 800), textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(children: [
                WorkspaceSectionCard(child: Text('Seção')),
                WorkspaceMetricCard(
                  icon: Icons.groups_rounded,
                  label: 'Colaboradores',
                  value: '14',
                  helper: 'Perfis cadastrados',
                ),
              ]),
            ),
          ),
        ),
      ));
      final surface = tester.widget<Material>(find
          .descendant(
            of: find.byType(WorkspaceSectionCard),
            matching: find.byType(Material),
          )
          .first);
      final shape = surface.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, isNot(BorderRadius.zero),
          reason: 'workspace_redesign_surface');
      expect(find.text('Seção'), findsOneWidget);
      expect(find.byKey(const ValueKey('workspace-metric-icon-tile')),
          findsOneWidget);
      expect(tester.getTopLeft(find.text('14')).dy,
          greaterThan(tester.getTopLeft(find.text('Colaboradores')).dy));
      expect(tester.takeException(), isNull);
    }
  });

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
