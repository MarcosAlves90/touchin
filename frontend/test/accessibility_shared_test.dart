import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_instant_select_field.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';

void main() {
  testWidgets('select exposes its label, value and keyboard-accessible action',
      (tester) async {
    final semantics = tester.ensureSemantics();
    String? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceInstantSelectField<String>(
            value: null,
            options: const [
              WorkspaceSelectOption(value: 'one', label: 'Primeiro projeto'),
            ],
            decoration: const InputDecoration(labelText: 'Projeto'),
            onChanged: (selected) => value = selected,
          ),
        ),
      ),
    );

    final accessibleSelect = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Projeto' &&
          widget.properties.value == 'Nenhuma opção selecionada' &&
          widget.properties.onTap != null,
    );
    expect(accessibleSelect, findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Projeto')), findsOneWidget);

    await tester.tap(find.byType(WorkspaceInstantSelectField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Primeiro projeto').last);
    await tester.pumpAndSettle();
    expect(value, 'one');
    semantics.dispose();
  });

  testWidgets('compact workspace menu has an accessible name', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScaffold(
          sidebar: const WorkspaceSidebar(
            title: 'Resumo da jornada',
            description: 'Descrição',
            summaryChildren: [],
            highlightChips: [],
          ),
          contentBuilder: (context, isWide) => const WorkspaceHeader(
              title: 'Área principal', description: 'Detalhes'),
        ),
      ),
    );

    expect(find.byTooltip('Abrir menu'), findsOneWidget);
    final headings = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.header == true,
    );
    expect(headings, findsWidgets);
    semantics.dispose();
  });

  testWidgets('workspace select opens and selects using the keyboard',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WorkspaceInstantSelectField<String>(
          value: selected,
          options: const [
            WorkspaceSelectOption(value: 'first', label: 'Primeiro projeto'),
          ],
          decoration: const InputDecoration(labelText: 'Projeto'),
          onChanged: (value) => selected = value,
        ),
      ),
    ));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 'first');
  });
}
