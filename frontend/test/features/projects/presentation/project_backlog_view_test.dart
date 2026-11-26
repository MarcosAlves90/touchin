import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_backlog_view.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_instant_select_field.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

void main() {
  testWidgets('backlog redesign hierarchy', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
      await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ProjectBacklogView(
              board: _board(hierarchical: true),
              projectName: 'Projeto Alpha',
              projectMembers: const [],
              canManageStructure: true,
              canManageCards: true,
              canManageAssignees: true,
              canMoveCards: true,
              isBusy: false,
              onManageColumns: () {},
              onCreateColumn: () {},
              onCreateCard: (_) {},
              onMoveCard: (_, __, ___) {},
              onEditCard: (_) {},
              onDeleteCard: (_) {},
              onManageAssignees: (_) {},
              onOpenDetails: (_) {},
            ),
          )));
      await tester.pumpAndSettle();
      final tableSurface = find.byKey(const ValueKey('backlog-table-surface'));
      expect(tableSurface, findsOneWidget,
          reason: 'backlog_redesign_hierarchy');
      final decoration =
          tester.widget<DecoratedBox>(tableSurface).decoration as BoxDecoration;
      expect(decoration.borderRadius, isNotNull,
          reason: 'backlog_redesign_hierarchy');
      expect(find.byKey(const ValueKey('hierarchy-indicator-task-2')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('backlog-search')), findsOneWidget);
      expect(tester.getTopLeft(find.text('Status').first).dx,
          lessThan(tester.getTopLeft(find.text('Ações')).dx));
      final toolbar = find.byKey(const ValueKey('backlog-toolbar'));
      expect(find.text('Tarefas do projeto'), findsNothing);
      expect(tester.getSize(toolbar).height, lessThanOrEqualTo(112));
      final actions = tester.widget<PopupMenuButton<String>>(
        find.byWidgetPredicate((widget) =>
            widget is PopupMenuButton<String> &&
            widget.tooltip == 'Mais ações para #1'),
      );
      expect(actions.color, theme.colorScheme.surfaceContainerHighest,
          reason: 'backlog_action_menu_surface');
      final shape = actions.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(10),
          reason: 'backlog_action_menu_radius_10');
      expect(shape.side.color, theme.colorScheme.outlineVariant,
          reason: 'backlog_action_menu_border');
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('compact backlog fits without horizontal scrolling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectBacklogView(
          board: _board(),
          projectName: 'Projeto Alpha',
          projectMembers: const <ProjectMemberSummary>[],
          canManageStructure: true,
          canManageCards: true,
          canManageAssignees: true,
          canMoveCards: true,
          isBusy: false,
          onManageColumns: () {},
          onCreateColumn: () {},
          onCreateCard: (_) {},
          onMoveCard: (_, __, ___) {},
          onEditCard: (_) {},
          onDeleteCard: (_) {},
          onManageAssignees: (_) {},
          onOpenDetails: (_) {},
        ),
      ),
    ));

    expect(
      find.byKey(const ValueKey('backlog-horizontal-scrollbar')),
      findsOneWidget,
      reason: 'backlog_horizontal_scrollbar',
    );
    final horizontalScrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('backlog-horizontal-scrollbar')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.right,
        ),
      ),
    );
    Focus.of(
      tester
          .element(find.byKey(const ValueKey('backlog-horizontal-scrollbar'))),
    ).requestFocus();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(horizontalScrollable.position.maxScrollExtent, 0);
  });

  testWidgets('mobile backlog shows task essentials without horizontal scroll',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectBacklogView(
          board: _board(),
          projectName: 'Projeto Alpha',
          projectMembers: const <ProjectMemberSummary>[],
          canManageStructure: true,
          canManageCards: true,
          canManageAssignees: true,
          canMoveCards: true,
          isBusy: false,
          onManageColumns: () {},
          onCreateColumn: () {},
          onCreateCard: (_) {},
          onMoveCard: (_, __, ___) {},
          onEditCard: (_) {},
          onDeleteCard: (_) {},
          onManageAssignees: (_) {},
          onOpenDetails: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('backlog-mobile-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('backlog-table')), findsNothing);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Preparar proposta'), findsOneWidget);
    expect(find.text('A fazer'), findsOneWidget);
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.byTooltip('Mais ações para #1'), findsOneWidget);
    final colors = Theme.of(
      tester.element(find.byKey(const ValueKey('backlog-mobile-list'))),
    ).colorScheme;
    final actions = tester.widget<PopupMenuButton<String>>(
      find.byWidgetPredicate((widget) =>
          widget is PopupMenuButton<String> &&
          widget.tooltip == 'Mais ações para #1'),
    );
    expect(actions.color, colors.surfaceContainerHighest,
        reason: 'backlog_mobile_menu_surface');
    final shape = actions.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(10),
        reason: 'backlog_mobile_menu_radius_10');
    expect(shape.side.color, colors.outlineVariant,
        reason: 'backlog_mobile_menu_border');
    expect(tester.takeException(), isNull);
  });

  testWidgets('backlog puts row controls in a dedicated actions column',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectBacklogView(
          board: _board(),
          projectName: 'Projeto Alpha',
          projectMembers: const <ProjectMemberSummary>[],
          canManageStructure: true,
          canManageCards: true,
          canManageAssignees: true,
          canMoveCards: true,
          isBusy: false,
          onManageColumns: () {},
          onCreateColumn: () {},
          onCreateCard: (_) {},
          onMoveCard: (_, __, ___) {},
          onEditCard: (_) {},
          onDeleteCard: (_) {},
          onManageAssignees: (_) {},
          onOpenDetails: (_) {},
        ),
      ),
    ));

    final table = tester.widget<DataTable>(
      find.byKey(const ValueKey<String>('backlog-table')),
    );
    expect(table.rows, isNotEmpty);
    final actionsColumnIndex = table.columns.indexWhere(
      (column) =>
          column.label is Text && (column.label as Text).data == 'Ações',
    );
    expect(
      actionsColumnIndex,
      4,
      reason: 'backlog_actions_column_order',
    );
    for (final row in table.rows) {
      expect(
        row.cells,
        hasLength(table.columns.length),
        reason: 'backlog_actions_column_order',
      );
      expect(
        row.cells[actionsColumnIndex].child,
        isA<PopupMenuButton<String>>(),
        reason: 'backlog_actions_column_order',
      );
    }
  });

  testWidgets('production themes keep backlog controls compact and responsive',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final theme in <ThemeData>[AppTheme.darkTheme, AppTheme.lightTheme]) {
      for (final size in <Size>[
        const Size(1440, 900),
        const Size(768, 800),
        const Size(360, 800),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ProjectBacklogView(
              board: _board(),
              projectName: 'Projeto Alpha',
              projectMembers: const <ProjectMemberSummary>[],
              canManageStructure: true,
              canManageCards: true,
              canManageAssignees: true,
              canMoveCards: true,
              isBusy: false,
              onManageColumns: () {},
              onCreateColumn: () {},
              onCreateCard: (_) {},
              onMoveCard: (_, __, ___) {},
              onEditCard: (_) {},
              onDeleteCard: (_) {},
              onManageAssignees: (_) {},
              onOpenDetails: (_) {},
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final toolbar = find.byKey(const ValueKey('backlog-toolbar'));
        expect(toolbar, findsOneWidget);
        final toolbarMaterial = tester.widget<Material>(toolbar);
        expect(toolbarMaterial.color, Colors.transparent);
        expect(
          tester.getSize(find.byKey(const ValueKey('backlog-search'))).height,
          48,
          reason: 'workspace_search_control_height',
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('backlog-search')),
              )
              .decoration
              ?.constraints
              ?.minHeight,
          48,
          reason: 'workspace_search_control_height',
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('backlog-search')),
              )
              .decoration
              ?.constraints
              ?.maxHeight,
          48,
          reason: 'workspace_search_control_height',
        );
        expect(
          tester
              .getSize(find
                  .descendant(
                    of: find.byKey(const ValueKey('backlog-search')),
                    matching: find.byType(InputDecorator),
                  )
                  .first)
              .height,
          48,
          reason: 'workspace_search_control_height',
        );

        for (final label in <String>[
          'Gerenciar colunas',
          'Novo status',
          'Novo card',
        ]) {
          final button = find.ancestor(
            of: find.text(label),
            matching:
                find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
          );
          expect(tester.getSize(button).width, lessThan(210));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(
            tester.getRect(button).top,
            greaterThanOrEqualTo(
              tester
                  .getRect(find.byKey(const ValueKey('backlog-search')))
                  .bottom,
            ),
          );
        }
        expect(
            find.byType(WorkspaceInstantSelectField<String>), findsNWidgets(3));
        for (final key in <String>[
          'backlog-status-filter',
          'backlog-assignee-filter',
          'backlog-sort',
        ]) {
          final field = find.byKey(ValueKey<String>(key));
          expect(
            tester.getSize(field).height,
            48,
            reason: 'workspace_search_control_height',
          );
          expect(
            tester
                .widget<WorkspaceInstantSelectField<String>>(field)
                .decoration
                .constraints
                ?.minHeight,
            48,
            reason: 'workspace_search_control_height',
          );
          expect(
            tester
                .widget<WorkspaceInstantSelectField<String>>(field)
                .decoration
                .constraints
                ?.maxHeight,
            48,
            reason: 'workspace_search_control_height',
          );
          expect(
            tester
                .getSize(find
                    .descendant(
                      of: field,
                      matching: find.byType(InputDecorator),
                    )
                    .first)
                .height,
            48,
            reason: 'workspace_search_control_height',
          );

          final select =
              tester.widget<WorkspaceInstantSelectField<String>>(field);
          expect(select.decoration.labelText, isNull);
          expect(select.decoration.prefixIcon, isNotNull);
          expect(select.semanticLabel, isNotEmpty);
          expect(
            tester.getRect(field).top,
            greaterThanOrEqualTo(
              tester
                  .getRect(find.byKey(const ValueKey('backlog-search')))
                  .bottom,
            ),
          );
        }
        if (size.width < 600) {
          expect(find.byKey(const ValueKey('backlog-mobile-list')),
              findsOneWidget);
          expect(find.byKey(const ValueKey('backlog-table')), findsNothing);
        } else {
          expect(
              tester.getSize(find.byKey(const ValueKey('backlog-table'))).width,
              greaterThanOrEqualTo(size.width - 2));
        }
        final rowAction = size.width < 600
            ? find.byTooltip('Mais ações para #1')
            : find.byTooltip('Mais ações para #1');
        expect(rowAction, findsOneWidget);
        expect(tester.getSize(rowAction).width, greaterThanOrEqualTo(40));
        expect(tester.getSize(rowAction).height, greaterThanOrEqualTo(40));
        if (size.width >= 1440) {
          expect(
            tester.getSize(find.text('Preparar proposta')).width,
            greaterThanOrEqualTo(160),
            reason: 'backlog_title_minimum_width',
          );
          final toolbar =
              tester.getRect(find.byKey(const ValueKey('backlog-toolbar')));
          final lastAction = tester.getRect(find.ancestor(
            of: find.text('Novo card'),
            matching: find.byType(FilledButton),
          ));
          expect(lastAction.right, greaterThan(toolbar.right - 24));
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
      'backlog filters and permissions survive narrow and enlarged text',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in <Size>[
      const Size(320, 568),
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1440, 900),
    ]) {
      for (final scale in <double>[1, 1.5]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: ProjectBacklogView(
              board: _board(),
              projectName: 'Projeto Alpha',
              projectMembers: const <ProjectMemberSummary>[],
              canManageStructure: false,
              canManageCards: false,
              canManageAssignees: false,
              canMoveCards: false,
              isBusy: false,
              onManageColumns: () {},
              onCreateColumn: () {},
              onCreateCard: (_) {},
              onMoveCard: (_, __, ___) {},
              onEditCard: (_) {},
              onDeleteCard: (_) {},
              onManageAssignees: (_) {},
              onOpenDetails: (_) {},
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final toolbar = find.byKey(const ValueKey<String>('backlog-toolbar'));
        final search = find.byKey(const ValueKey<String>('backlog-search'));
        expect(toolbar, findsOneWidget);
        expect(tester.getRect(toolbar).left, greaterThanOrEqualTo(0));
        expect(
            tester.getRect(toolbar).right, lessThanOrEqualTo(size.width + 0.1));
        expect(search, findsOneWidget);
        for (final key in <String>[
          'backlog-status-filter',
          'backlog-assignee-filter',
          'backlog-sort',
        ]) {
          final filter = find.byKey(ValueKey<String>(key));
          expect(
              find.descendant(of: toolbar, matching: filter), findsOneWidget);
          expect(tester.getSize(filter).height, 48);
        }
        expect(find.text('Gerenciar colunas'), findsNothing);
        expect(find.text('Novo status'), findsNothing);
        expect(find.text('Novo card'), findsNothing);
        expect(find.byTooltip('Mais ações para #1'), findsOneWidget);

        await tester.enterText(search, 'proposta');
        await tester.pumpAndSettle();
        expect(find.text('Preparar proposta'), findsOneWidget);
        expect(find.text('Corrigir defeito'), findsNothing);
        expect(tester.takeException(), isNull,
            reason: 'backlog permissions and overflow at $size, scale $scale');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('backlog column and card actions remain independent permissions',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    var createColumns = 0;
    var createCards = 0;

    Widget view(
            {required bool canManageStructure, required bool canManageCards}) =>
        MaterialApp(
          home: Scaffold(
            body: ProjectBacklogView(
              board: _board(),
              projectName: 'Projeto Alpha',
              projectMembers: const <ProjectMemberSummary>[],
              canManageStructure: canManageStructure,
              canManageCards: canManageCards,
              canManageAssignees: false,
              canMoveCards: false,
              isBusy: false,
              onManageColumns: () {},
              onCreateColumn: () => createColumns++,
              onCreateCard: (_) => createCards++,
              onMoveCard: (_, __, ___) {},
              onEditCard: (_) {},
              onDeleteCard: (_) {},
              onManageAssignees: (_) {},
              onOpenDetails: (_) {},
            ),
          ),
        );

    await tester
        .pumpWidget(view(canManageStructure: true, canManageCards: false));
    await tester.pumpAndSettle();
    expect(find.text('Gerenciar colunas'), findsOneWidget);
    expect(find.text('Novo status'), findsOneWidget);
    expect(find.text('Novo card'), findsNothing);
    await tester.ensureVisible(find.text('Novo status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo status'));
    expect(createColumns, 1);

    await tester
        .pumpWidget(view(canManageStructure: false, canManageCards: true));
    await tester.pumpAndSettle();
    expect(find.text('Gerenciar colunas'), findsNothing);
    expect(find.text('Novo status'), findsNothing);
    expect(find.text('Novo card'), findsOneWidget);
    await tester.ensureVisible(find.text('Novo card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo card'));
    expect(createCards, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Backlog pagination footer fits at 320 width and 1.5 text scale',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const viewport = Size(320, 568);
    await tester.binding.setSurfaceSize(viewport);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: Scaffold(
        body: ProjectBacklogView(
          board: _boardWithManyCards(55),
          projectName: 'Projeto Alpha',
          projectMembers: const <ProjectMemberSummary>[],
          canManageStructure: false,
          canManageCards: false,
          canManageAssignees: false,
          canMoveCards: false,
          isBusy: false,
          onManageColumns: () {},
          onCreateColumn: () {},
          onCreateCard: (_) {},
          onMoveCard: (_, __, ___) {},
          onEditCard: (_) {},
          onDeleteCard: (_) {},
          onManageAssignees: (_) {},
          onOpenDetails: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final page = find.byKey(const ValueKey<String>('backlog-page-label'));
    final next = find.byKey(const ValueKey<String>('backlog-page-next'));
    expect(find.text('55 de 55 cards'), findsOneWidget);
    expect(find.text('Página 1 de 2'), findsOneWidget);
    expect(tester.getRect(page).right, lessThanOrEqualTo(viewport.width + 0.1));
    expect(tester.getRect(next).right, lessThanOrEqualTo(viewport.width + 0.1));
    expect(tester.takeException(), isNull,
        reason: 'paginated footer must not overflow at enlarged text');

    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Página 2 de 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('backlog-mobile-card-task-51')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows searchable cards and filters by number and status', (
    tester,
  ) async {
    final board = _board();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectBacklogView(
            board: board,
            projectName: 'Projeto Alpha',
            projectMembers: <ProjectMemberSummary>[
              ProjectMemberSummary(
                employeeId: 'emp-1',
                projectId: 'project-1',
                employeeName: 'Ana Souza',
                createdAt: DateTime(2026, 1, 1),
              ),
            ],
            canManageStructure: false,
            canManageCards: false,
            canManageAssignees: false,
            canMoveCards: false,
            isBusy: false,
            onManageColumns: () {},
            onCreateColumn: () {},
            onCreateCard: (_) {},
            onMoveCard: (_, __, ___) {},
            onEditCard: (_) {},
            onDeleteCard: (_) {},
            onManageAssignees: (_) {},
            onOpenDetails: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Preparar proposta'), findsOneWidget);
    expect(find.byTooltip('Preparar proposta\nDescrição detalhada'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('backlog-header-status')), findsOneWidget);
    expect(find.byKey(const ValueKey('backlog-status-task-1')), findsOneWidget);
    expect(find.text('A fazer'), findsOneWidget);
    expect(find.text('Em andamento'), findsOneWidget);
    expect(find.text('Projeto: Projeto Alpha'), findsNothing);
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.byTooltip('Editar #1'), findsNothing);
    expect(find.byTooltip('Excluir #1'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('backlog-search')),
      'proposta',
    );
    await tester.pumpAndSettle();
    expect(find.text('Preparar proposta'), findsOneWidget);
    expect(find.text('Corrigir defeito'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('backlog-search')), '#2');
    await tester.pumpAndSettle();
    expect(find.text('Corrigir defeito'), findsOneWidget);
    expect(find.text('Preparar proposta'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('backlog-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A fazer').last);
    await tester.pumpAndSettle();
    expect(find.text('Corrigir defeito'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('backlog-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos os status'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('backlog-assignee-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Souza').last);
    await tester.pumpAndSettle();
    expect(find.text('Corrigir defeito'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shared filtering disables Backlog reordering on mobile and desktop',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in <Size>[
      const Size(390, 844),
      const Size(1440, 900),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProjectBacklogView(
            board: _board(hierarchical: true),
            matchedCardIds: const <String>{'task-2'},
            sharedSearchField: const TextField(
              key: ValueKey<String>('task-search-shared'),
            ),
            sharedSearchQuery: '#2',
            projectName: 'Projeto Alpha',
            projectMembers: const <ProjectMemberSummary>[],
            canManageStructure: false,
            canManageCards: false,
            canManageAssignees: false,
            canMoveCards: true,
            isBusy: false,
            onManageColumns: () {},
            onCreateColumn: () {},
            onCreateCard: (_) {},
            onMoveCard: (_, __, ___) {},
            onEditCard: (_) {},
            onDeleteCard: (_) {},
            onManageAssignees: (_) {},
            onOpenDetails: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      if (size.width < 600) {
        expect(
          find.byKey(const ValueKey('backlog-mobile-card-task-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('backlog-mobile-card-task-1')),
          findsNothing,
        );
      } else {
        final table = tester.widget<DataTable>(find.byType(DataTable));
        expect(table.rows, hasLength(1));
        expect(
          table.rows.single.key,
          const ValueKey<String>('backlog-card-task-2'),
        );
      }
      expect(find.byTooltip('Mover #2 para baixo no Kanban'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('shared search intersects the local Backlog query',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectBacklogView(
          board: _board(),
          matchedCardIds: const <String>{'task-1'},
          projectName: 'Projeto Alpha',
          projectMembers: const <ProjectMemberSummary>[],
          canManageStructure: false,
          canManageCards: false,
          canManageAssignees: false,
          canMoveCards: false,
          isBusy: false,
          onManageColumns: () {},
          onCreateColumn: () {},
          onCreateCard: (_) {},
          onMoveCard: (_, __, ___) {},
          onEditCard: (_) {},
          onDeleteCard: (_) {},
          onManageAssignees: (_) {},
          onOpenDetails: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final localSearch = find.byKey(const ValueKey('backlog-search'));
    expect(localSearch, findsOneWidget);
    expect(find.text('Preparar proposta'), findsOneWidget);
    expect(find.text('Corrigir defeito'), findsNothing);

    await tester.enterText(localSearch, 'defeito');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum card corresponde aos filtros.'), findsOneWidget);

    await tester.enterText(localSearch, 'proposta');
    await tester.pumpAndSettle();
    expect(find.text('Preparar proposta'), findsOneWidget);
    expect(find.text('Corrigir defeito'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('backlog-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Em andamento').last);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum card corresponde aos filtros.'), findsOneWidget);
    expect(find.text('Preparar proposta'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('backlog-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos os status'));
    await tester.pumpAndSettle();
    expect(find.text('Preparar proposta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared search retains Backlog pagination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectBacklogView(
          board: _boardWithManyCards(120),
          matchedCardIds: <String>{
            for (var index = 1; index <= 51; index++) 'task-$index',
          },
          projectName: 'Projeto Alpha',
          projectMembers: const <ProjectMemberSummary>[],
          canManageStructure: false,
          canManageCards: false,
          canManageAssignees: false,
          canMoveCards: false,
          isBusy: false,
          onManageColumns: () {},
          onCreateColumn: () {},
          onCreateCard: (_) {},
          onMoveCard: (_, __, ___) {},
          onEditCard: (_) {},
          onDeleteCard: (_) {},
          onManageAssignees: (_) {},
          onOpenDetails: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    var table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(50));
    expect(find.text('Página 1 de 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('backlog-page-next')));
    await tester.pumpAndSettle();
    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(1));
    expect(table.rows.single.key, const ValueKey('backlog-card-task-51'));

    await tester.tap(find.byKey(const ValueKey('backlog-header-number')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ordenar decrescente'));
    await tester.pumpAndSettle();
    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(50));
    expect(table.rows.first.key, const ValueKey('backlog-card-task-51'));
    expect(find.text('Página 1 de 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('backlog-page-next')));
    await tester.pumpAndSettle();
    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(1));
    expect(table.rows.single.key, const ValueKey('backlog-card-task-1'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared search resets Backlog pagination when matches change',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final board = _boardWithManyCards(120);
    Widget backlog(Set<String> matches, String sharedSearchQuery) =>
        MaterialApp(
          home: Scaffold(
            body: ProjectBacklogView(
              board: board,
              matchedCardIds: matches,
              sharedSearchQuery: sharedSearchQuery,
              projectName: 'Projeto Alpha',
              projectMembers: const <ProjectMemberSummary>[],
              canManageStructure: false,
              canManageCards: false,
              canManageAssignees: false,
              canMoveCards: false,
              isBusy: false,
              onManageColumns: () {},
              onCreateColumn: () {},
              onCreateCard: (_) {},
              onMoveCard: (_, __, ___) {},
              onEditCard: (_) {},
              onDeleteCard: (_) {},
              onManageAssignees: (_) {},
              onOpenDetails: (_) {},
            ),
          ),
        );

    await tester.pumpWidget(backlog(<String>{
      for (var index = 1; index <= 51; index++) 'task-$index',
    }, 'first query'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('backlog-page-next')));
    await tester.pumpAndSettle();
    expect(find.text('Página 2 de 2'), findsOneWidget);

    await tester.pumpWidget(backlog(<String>{
      for (var index = 52; index <= 111; index++) 'task-$index',
    }, 'second query'));
    await tester.pumpAndSettle();

    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(find.text('Página 1 de 2'), findsOneWidget);
    expect(table.rows, hasLength(50));
    expect(table.rows.first.key, const ValueKey('backlog-card-task-52'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reordering and detail actions use existing card identities', (
    tester,
  ) async {
    String? movedTaskId;
    String? movedColumnId;
    var manageColumnsCalls = 0;
    var createColumnCalls = 0;
    KanbanCard? openedCard;
    int? movedIndex;
    final board = _board(hierarchical: true);

    await tester.binding.setSurfaceSize(const Size(1800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectBacklogView(
            board: board,
            projectName: 'Projeto Alpha',
            projectMembers: const <ProjectMemberSummary>[],
            canManageStructure: true,
            canManageCards: true,
            canManageAssignees: true,
            canMoveCards: true,
            isBusy: false,
            onManageColumns: () => manageColumnsCalls += 1,
            onCreateColumn: () => createColumnCalls += 1,
            onCreateCard: (_) {},
            onMoveCard: (taskId, columnId, index) {
              movedTaskId = taskId;
              movedColumnId = columnId;
              movedIndex = index;
            },
            onEditCard: (_) {},
            onDeleteCard: (_) {},
            onManageAssignees: (_) {},
            onOpenDetails: (card) => openedCard = card,
          ),
        ),
      ),
    );

    expect(find.text('Gerenciar colunas'), findsOneWidget);
    expect(find.text('Novo card'), findsOneWidget);
    expect(find.byTooltip('Mais ações para #1'), findsOneWidget);
    expect(find.byTooltip('Editar #1'), findsNothing);
    expect(find.byTooltip('Excluir #1'), findsNothing);
    expect(find.byTooltip('Mover #1 para cima no Kanban'), findsNothing);
    expect(find.byTooltip('Mais ações para #3'), findsOneWidget);
    expect(find.byTooltip('Mover #2 para baixo no Kanban'), findsNothing);
    await tester.tap(find.text('Novo status'));
    await tester.tap(find.text('Gerenciar colunas'));
    expect(createColumnCalls, 1);
    expect(manageColumnsCalls, 1);
    await tester.tap(find.byTooltip('Mais ações para #1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir detalhes de #1'));
    await tester.pump();
    expect(openedCard?.id, 'task-1');
    expect(openedCard?.cardNumber, 1);

    await tester.tap(find.byTooltip('Mais ações para #3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover para cima'));
    await tester.pumpAndSettle();
    expect(movedTaskId, 'task-3');
    expect(movedColumnId, 'column-2');
    expect(movedIndex, 0);
    await tester.ensureVisible(find.byTooltip('Mais ações para #2'));
    await tester.tap(find.byTooltip('Mais ações para #2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover para baixo'));
    await tester.pumpAndSettle();
    expect(movedTaskId, 'task-2');
    expect(movedColumnId, 'column-2');
    expect(movedIndex, 2);

    final headerMenu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const ValueKey('backlog-header-status')),
    );
    final headerColors = Theme.of(
      tester.element(find.byKey(const ValueKey('backlog-header-status'))),
    ).colorScheme;
    expect(headerMenu.color, headerColors.surfaceContainerHighest,
        reason: 'backlog_header_menu_surface');
    final headerShape = headerMenu.shape! as RoundedRectangleBorder;
    expect(headerShape.borderRadius, BorderRadius.circular(10),
        reason: 'backlog_header_menu_radius_10');
    expect(headerShape.side.color, headerColors.outlineVariant,
        reason: 'backlog_header_menu_border');

    await tester.tap(find.byKey(const ValueKey('backlog-header-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ordenar crescente'));
    await tester.pumpAndSettle();
    final sort = tester.widget<WorkspaceInstantSelectField<String>>(
        find.byKey(const ValueKey('backlog-sort')));
    expect(sort.value, 'status');
    expect(sort.options.any((option) => option.value == 'status'), isTrue);
    expect(find.byTooltip('Mais ações para #3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('backlog-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ordem do Kanban').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mais ações para #3'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('backlog-search')), '#3');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mais ações para #3'), findsOneWidget);
  });

  testWidgets('move actions show directional icons on desktop and mobile',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in <Size>[
      const Size(1440, 900),
      const Size(390, 844),
    ]) {
      await tester.binding.setSurfaceSize(size);
      String? movedTaskId;
      String? movedColumnId;
      int? movedIndex;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProjectBacklogView(
            board: _board(hierarchical: true),
            projectName: 'Projeto Alpha',
            projectMembers: const <ProjectMemberSummary>[],
            canManageStructure: true,
            canManageCards: true,
            canManageAssignees: true,
            canMoveCards: true,
            isBusy: false,
            onManageColumns: () {},
            onCreateColumn: () {},
            onCreateCard: (_) {},
            onMoveCard: (taskId, columnId, index) {
              movedTaskId = taskId;
              movedColumnId = columnId;
              movedIndex = index;
            },
            onEditCard: (_) {},
            onDeleteCard: (_) {},
            onManageAssignees: (_) {},
            onOpenDetails: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final actionMenu = find.byTooltip('Mais ações para #3');
      await tester.ensureVisible(actionMenu);
      await tester.tap(actionMenu);
      await tester.pumpAndSettle();

      final icons = <String, IconData>{
        'Mover para cima': Icons.arrow_upward_rounded,
        'Mover para baixo': Icons.arrow_downward_rounded,
      };
      for (final entry in icons.entries) {
        final item = find.ancestor(
          of: find.text(entry.key),
          matching: find.byWidgetPredicate(
            (widget) => widget is PopupMenuItem,
          ),
        );
        expect(item, findsOneWidget,
            reason: 'move_item_${size.width.toInt()}_${entry.key}');
        expect(
          find.descendant(of: item, matching: find.byIcon(entry.value)),
          findsOneWidget,
          reason: 'move_icon_${size.width.toInt()}_${entry.key}',
        );
      }

      await tester.tap(find.text('Mover para cima'));
      await tester.pumpAndSettle();
      expect(movedTaskId, 'task-3');
      expect(movedColumnId, 'column-2');
      expect(movedIndex, 0);

      final downActionMenu = find.byTooltip('Mais ações para #2');
      await tester.ensureVisible(downActionMenu);
      await tester.tap(downActionMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover para baixo'));
      await tester.pumpAndSettle();
      expect(movedTaskId, 'task-2');
      expect(movedColumnId, 'column-2');
      expect(movedIndex, 2);
    }
  });

  testWidgets('backlog action menus match kanban icons and group dividers',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<List<PopupMenuEntry<String>>> buildMenu(
      Size size, {
      required bool canManageCards,
      required bool canManageAssignees,
      required bool canMoveCards,
    }) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProjectBacklogView(
            board: _board(hierarchical: true),
            projectName: 'Projeto Alpha',
            projectMembers: const <ProjectMemberSummary>[],
            canManageStructure: true,
            canManageCards: canManageCards,
            canManageAssignees: canManageAssignees,
            canMoveCards: canMoveCards,
            isBusy: false,
            onManageColumns: () {},
            onCreateColumn: () {},
            onCreateCard: (_) {},
            onMoveCard: (_, __, ___) {},
            onEditCard: (_) {},
            onDeleteCard: (_) {},
            onManageAssignees: (_) {},
            onOpenDetails: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final finder = find.byWidgetPredicate((widget) =>
          widget is PopupMenuButton<String> &&
          widget.tooltip == 'Mais ações para #3');
      final button = tester.widget<PopupMenuButton<String>>(finder);
      return button.itemBuilder!(tester.element(finder));
    }

    List<String> groupShape(List<PopupMenuEntry<String>> entries) => entries
        .map((entry) => entry is PopupMenuDivider
            ? 'divider'
            : (entry as PopupMenuItem<String>).value ?? '')
        .toList();

    void expectLeadingIcon(
      List<PopupMenuEntry<String>> entries,
      String value,
      IconData icon,
      String reason,
    ) {
      final item = entries.whereType<PopupMenuItem<String>>().firstWhere(
            (entry) => entry.value == value,
          );
      final leading = (item.child as ListTile).leading;
      expect(leading, isA<Icon>(), reason: reason);
      expect((leading as Icon).icon, icon, reason: reason);
    }

    for (final size in <Size>[
      const Size(1440, 900),
      const Size(390, 844),
    ]) {
      final label = 'backlog_menu_${size.width.toInt()}';
      final entries = await buildMenu(
        size,
        canManageCards: true,
        canManageAssignees: true,
        canMoveCards: true,
      );
      expect(
        groupShape(entries),
        <String>[
          'details',
          'divider',
          'up',
          'down',
          'divider',
          'edit',
          'delete',
          'divider',
          'assignees',
        ],
        reason: '${label}_groups',
      );
      for (final expected in <String, IconData>{
        'details': Icons.open_in_new_rounded,
        'up': Icons.arrow_upward_rounded,
        'down': Icons.arrow_downward_rounded,
        'edit': Icons.edit_outlined,
        'delete': Icons.delete_outline_rounded,
        'assignees': Icons.people_outline_rounded,
      }.entries) {
        expectLeadingIcon(
          entries,
          expected.key,
          expected.value,
          '${label}_${expected.key}_icon',
        );
      }

      final withoutManagement = await buildMenu(
        size,
        canManageCards: false,
        canManageAssignees: false,
        canMoveCards: true,
      );
      expect(
        groupShape(withoutManagement),
        <String>['details', 'divider', 'up', 'down'],
        reason: '${label}_without_management_groups',
      );

      final withoutMove = await buildMenu(
        size,
        canManageCards: true,
        canManageAssignees: true,
        canMoveCards: false,
      );
      expect(
        groupShape(withoutMove),
        <String>[
          'details',
          'divider',
          'edit',
          'delete',
          'divider',
          'assignees',
        ],
        reason: '${label}_without_move_groups',
      );
    }
  });

  testWidgets('headers filter and sort while children stay below parents',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProjectBacklogView(
      board: _board(hierarchical: true),
      projectName: 'Projeto Alpha',
      projectMembers: const <ProjectMemberSummary>[],
      canManageStructure: false,
      canManageCards: false,
      canManageAssignees: false,
      canMoveCards: false,
      isBusy: false,
      onManageColumns: () {},
      onCreateColumn: () {},
      onCreateCard: (_) {},
      onMoveCard: (_, __, ___) {},
      onEditCard: (_) {},
      onDeleteCard: (_) {},
      onManageAssignees: (_) {},
      onOpenDetails: (_) {},
    ))));
    for (final field in <String>[
      'number',
      'title',
      'description',
      'status',
      'assignees',
      'project',
      'created',
      'updated'
    ]) {
      expect(find.byKey(ValueKey('backlog-header-$field')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('backlog-header-title')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ordenar crescente'));
    await tester.pumpAndSettle();
    final parent = tester.getRect(find.text('Preparar proposta'));
    final child = tester.getRect(find.text('Corrigir defeito'));
    expect(child.top, greaterThan(parent.top));
    expect(child.left, greaterThan(parent.left));
    expect(find.byTooltip('Subtarefa de Preparar proposta'), findsOneWidget);
    final childArrow = tester.getRect(
      find.byKey(const ValueKey('hierarchy-indicator-task-2')),
    );
    final grandchildArrow = tester.getRect(
      find.byKey(const ValueKey('hierarchy-indicator-task-3')),
    );
    expect(find.byTooltip('Subtarefa de Corrigir defeito'), findsOneWidget);
    expect(grandchildArrow.left, greaterThan(childArrow.left));
    expect(grandchildArrow.top, greaterThan(childArrow.top));
    await tester.tap(find.byKey(const ValueKey('backlog-header-description')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtrar coluna'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'formulário');
    await tester.tap(find.text('Aplicar filtro'));
    await tester.pumpAndSettle();
    expect(find.text('Corrigir defeito'), findsOneWidget);
    expect(find.text('Preparar proposta'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagination limits rendered rows and searches the entire board',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectBacklogView(
          board: _boardWithManyCards(120),
          projectName: 'Projeto Alpha',
          projectMembers: const <ProjectMemberSummary>[],
          canManageStructure: false,
          canManageCards: false,
          canManageAssignees: false,
          canMoveCards: false,
          isBusy: false,
          onManageColumns: () {},
          onCreateColumn: () {},
          onCreateCard: (_) {},
          onMoveCard: (_, __, ___) {},
          onEditCard: (_) {},
          onDeleteCard: (_) {},
          onManageAssignees: (_) {},
          onOpenDetails: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    var table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows.length, 50);
    expect(table.rows.first.key, const ValueKey('backlog-card-task-1'));
    expect(find.text('Página 1 de 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('backlog-page-next')));
    await tester.pumpAndSettle();
    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows.length, 50);
    expect(table.rows.first.key, const ValueKey('backlog-card-task-51'));
    expect(find.text('Página 2 de 3'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('backlog-search')), '#120');
    await tester.pumpAndSettle();
    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows.length, 1);
    expect(table.rows.single.key, const ValueKey('backlog-card-task-120'));
    expect(find.text('#120'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('backlog-page-next')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('backlog-search')), '');
    await tester.pumpAndSettle();
    expect(find.text('Página 1 de 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('backlog-header-number')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ordenar decrescente'));
    await tester.pumpAndSettle();
    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows.first.key, const ValueKey('backlog-card-task-120'));
    expect(find.text('Página 1 de 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('backlog-header-project')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ordenar crescente'));
    await tester.pumpAndSettle();
    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows.first.key, const ValueKey('backlog-card-task-1'));
    await tester.tap(find.byKey(const ValueKey('backlog-page-next')));
    await tester.pumpAndSettle();
    table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows.first.key, const ValueKey('backlog-card-task-51'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagination clamps stored page when board shrinks and grows',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget view(int count) => MaterialApp(
          home: Scaffold(
              body: ProjectBacklogView(
            board: _boardWithManyCards(count),
            projectName: 'Projeto Alpha',
            projectMembers: const <ProjectMemberSummary>[],
            canManageStructure: false,
            canManageCards: false,
            canManageAssignees: false,
            canMoveCards: false,
            isBusy: false,
            onManageColumns: () {},
            onCreateColumn: () {},
            onCreateCard: (_) {},
            onMoveCard: (_, __, ___) {},
            onEditCard: (_) {},
            onDeleteCard: (_) {},
            onManageAssignees: (_) {},
            onOpenDetails: (_) {},
          )),
        );

    await tester.pumpWidget(view(101));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('backlog-page-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('backlog-page-next')));
    await tester.pumpAndSettle();
    expect(find.text('Página 3 de 3'), findsOneWidget);

    await tester.pumpWidget(view(100));
    await tester.pumpAndSettle();
    expect(find.text('Página 2 de 2'), findsOneWidget);

    await tester.pumpWidget(view(101));
    await tester.pumpAndSettle();
    expect(find.text('Página 2 de 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project switch clears filters from the previous project',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget view(String projectId) => MaterialApp(
          home: Scaffold(
            body: ProjectBacklogView(
              board: _boardWithManyCards(2, projectId: projectId),
              projectName: projectId,
              projectMembers: const <ProjectMemberSummary>[],
              canManageStructure: false,
              canManageCards: false,
              canManageAssignees: false,
              canMoveCards: false,
              isBusy: false,
              onManageColumns: () {},
              onCreateColumn: () {},
              onCreateCard: (_) {},
              onMoveCard: (_, __, ___) {},
              onEditCard: (_) {},
              onDeleteCard: (_) {},
              onManageAssignees: (_) {},
              onOpenDetails: (_) {},
            ),
          ),
        );
    await tester.pumpWidget(view('project-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('backlog-header-description')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtrar coluna'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'nenhuma descrição');
    await tester.tap(find.text('Aplicar filtro'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum card corresponde aos filtros.'), findsOneWidget);

    await tester.pumpWidget(view('project-b'));
    await tester.pumpAndSettle();
    expect(find.text('Card 1'), findsOneWidget);
    expect(find.text('2 de 2 cards'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('backlog-search')), 'Card 2');
    await tester.pumpAndSettle();
    expect(find.text('Card 1'), findsNothing);
    await tester.pumpWidget(view('project-c'));
    await tester.pumpAndSettle();
    final searchField = find.descendant(
        of: find.byKey(const ValueKey('backlog-search')),
        matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(searchField).controller.text, isEmpty);
    expect(find.text('Card 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deep hierarchy remains bounded and keeps parent relation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProjectBacklogView(
      board: _boardWithManyCards(130, nested: true),
      projectName: 'Projeto Alpha',
      projectMembers: const <ProjectMemberSummary>[],
      canManageStructure: false,
      canManageCards: false,
      canManageAssignees: false,
      canMoveCards: false,
      isBusy: false,
      onManageColumns: () {},
      onCreateColumn: () {},
      onCreateCard: (_) {},
      onMoveCard: (_, __, ___) {},
      onEditCard: (_) {},
      onDeleteCard: (_) {},
      onManageAssignees: (_) {},
      onOpenDetails: (_) {},
    ))));
    await tester.pumpAndSettle();
    expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 50);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('backlog-page-next')));
    await tester.pumpAndSettle();
    expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 50);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('backlog-page-next')));
    await tester.pumpAndSettle();
    expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty backlog is distinguished from empty search results',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectBacklogView(
          board: _boardWithManyCards(0),
          projectName: 'Projeto Alpha',
          projectMembers: const <ProjectMemberSummary>[],
          canManageStructure: false,
          canManageCards: false,
          canManageAssignees: false,
          canMoveCards: false,
          isBusy: false,
          onManageColumns: () {},
          onCreateColumn: () {},
          onCreateCard: (_) {},
          onMoveCard: (_, __, ___) {},
          onEditCard: (_) {},
          onDeleteCard: (_) {},
          onManageAssignees: (_) {},
          onOpenDetails: (_) {},
        ),
      ),
    ));
    expect(find.text('Nenhum card neste projeto.'), findsOneWidget);
    expect(find.text('Nenhum card corresponde aos filtros.'), findsNothing);
    expect(find.text('0 de 0 cards'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hash-only search does not match every card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectBacklogView(
          board: _boardWithManyCards(3),
          projectName: 'Projeto Alpha',
          projectMembers: const <ProjectMemberSummary>[],
          canManageStructure: false,
          canManageCards: false,
          canManageAssignees: false,
          canMoveCards: false,
          isBusy: false,
          onManageColumns: () {},
          onCreateColumn: () {},
          onCreateCard: (_) {},
          onMoveCard: (_, __, ___) {},
          onEditCard: (_) {},
          onDeleteCard: (_) {},
          onManageAssignees: (_) {},
          onOpenDetails: (_) {},
        ),
      ),
    ));
    await tester.enterText(find.byKey(const ValueKey('backlog-search')), '#');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum card corresponde aos filtros.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('backlog-search')), '#2');
    await tester.pumpAndSettle();
    expect(find.text('Card 2'), findsOneWidget);
    expect(find.text('Card 1'), findsNothing);
  });
}

KanbanBoard _boardWithManyCards(int count,
    {String projectId = 'project-1', bool nested = false}) {
  final date = DateTime.utc(2026, 10, 12);
  return KanbanBoard(projectId: projectId, kanbanVersion: 1, columns: [
    KanbanColumn(
      id: 'column-1',
      projectId: projectId,
      name: 'A fazer',
      position: 0,
      cards: <KanbanCard>[
        for (var index = 1; index <= count; index++)
          KanbanCard(
            id: 'task-$index',
            projectId: projectId,
            parentTaskId: nested && index > 1 ? 'task-${index - 1}' : null,
            cardNumber: index,
            kanbanColumnId: 'column-1',
            kanbanPosition: index - 1,
            name: 'Card $index',
            description: 'Descrição $index',
            type: TaskType.feature,
            assignees: const [],
            createdAt: date,
            updatedAt: date,
          ),
      ],
      createdAt: date,
      updatedAt: date,
    ),
  ]);
}

KanbanBoard _board({bool hierarchical = false}) {
  final first = KanbanCard(
    id: 'task-1',
    projectId: 'project-1',
    parentTaskId: null,
    cardNumber: 1,
    kanbanColumnId: 'column-1',
    kanbanPosition: 0,
    name: 'Preparar proposta',
    description: 'Descrição detalhada',
    type: TaskType.feature,
    assignees: <TaskMemberSummary>[
      TaskMemberSummary(
        employeeId: 'emp-1',
        taskId: 'task-1',
        employeeName: 'Ana Souza',
        createdAt: DateTime(2026, 1, 2),
      ),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 3),
  );
  final second = KanbanCard(
    id: 'task-2',
    projectId: 'project-1',
    parentTaskId: hierarchical ? 'task-1' : null,
    cardNumber: 2,
    kanbanColumnId: 'column-2',
    kanbanPosition: 0,
    name: 'Corrigir defeito',
    description: 'Falha no formulário',
    type: TaskType.bug,
    assignees: const <TaskMemberSummary>[],
    createdAt: DateTime(2026, 1, 4),
    updatedAt: DateTime(2026, 1, 5),
  );
  final third = KanbanCard(
    id: 'task-3',
    projectId: 'project-1',
    parentTaskId: 'task-2',
    cardNumber: 3,
    kanbanColumnId: 'column-2',
    kanbanPosition: 1,
    name: 'Revisar subtarefa',
    description: 'Detalhe da subtarefa',
    type: TaskType.improvement,
    assignees: const <TaskMemberSummary>[],
    createdAt: DateTime(2026, 1, 6),
    updatedAt: DateTime(2026, 1, 6),
  );
  return KanbanBoard(
    projectId: 'project-1',
    kanbanVersion: 0,
    columns: <KanbanColumn>[
      KanbanColumn(
        id: 'column-1',
        projectId: 'project-1',
        name: 'A fazer',
        position: 0,
        cards: <KanbanCard>[first],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      KanbanColumn(
        id: 'column-2',
        projectId: 'project-1',
        name: 'Em andamento',
        position: 1,
        cards:
            hierarchical ? <KanbanCard>[second, third] : <KanbanCard>[second],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ],
  );
}
