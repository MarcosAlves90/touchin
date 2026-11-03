import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/theme/app_theme.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final highContrast in [false, true]) {
      for (final width in [430.0, 1440.0]) {
        testWidgets('profile keyboard focus $dark $highContrast $width', (tester) async {
          tester.view.physicalSize = Size(width, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final base = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
          final theme = highContrast ? AppTheme.highContrastTheme(base) : base;
          final semantics = tester.ensureSemantics();
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: MaterialApp(theme: theme, home: AdminEmployeesPage(api: _FakeAdminApi(employee: _employeeResponse(pendingAdjustments: 1))))));
          await tester.pumpAndSettle();
          final selected = find.ancestor(of: find.text('Cadastro').last, matching: find.byType(OutlinedButton)).first;
          final next = find.ancestor(of: find.text('Políticas').last, matching: find.byType(OutlinedButton)).first;
          void checkFocus(String label, Finder button) {
            final indicator = find.byKey(ValueKey('profile-tab-focus-$label'));
            expect(indicator, findsOneWidget, reason: 'profile_tab_focus_invisible');
            final box = tester.widget<DecoratedBox>(indicator);
            final border = (box.decoration as BoxDecoration).border! as Border;
            expect(border.top.width, greaterThanOrEqualTo(2));
            final style = tester.widget<OutlinedButton>(button).style!;
            final section = find.ancestor(of: button, matching: find.byType(WorkspaceSectionCard)).first;
            final panel = tester.widget<Material>(find.descendant(of: section, matching: find.byType(Material)).first);
            final adjacent = Color.alphaBlend(panel.color!, theme.scaffoldBackgroundColor);
            final background = Color.alphaBlend(style.backgroundColor!.resolve({})!, adjacent);
            final a = border.top.color.computeLuminance();
            final b = background.computeLuminance();
            expect((a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05), greaterThanOrEqualTo(3));
            expect(tester.getRect(button).contains(tester.getRect(indicator).topLeft), isTrue);
            expect(tester.getRect(button).contains(tester.getRect(indicator).bottomRight - const Offset(0.1, 0.1)), isTrue);
          }
          await tester.ensureVisible(selected);
          await tester.pumpAndSettle();
          final labels = ['Cadastro', 'Políticas', 'Ponto', 'Notas'];
          Finder tab(String label) => find.ancestor(of: find.text(label).last, matching: find.byType(OutlinedButton)).first;
          List<Rect> rects() => labels.map((label) => tester.getRect(tab(label))).toList();
          final initialRects = rects();
          Future<Color> pixel(Offset point) async {
            final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            return (await tester.runAsync(() async {
              final image = await boundary.toImage();
              try {
                final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
                final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
                return Color.fromARGB(bytes.getUint8(offset + 3), bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
              } finally {
                image.dispose();
              }
            }))!;
          }
          Offset ringPoint(Finder button) => tester.getRect(button).topCenter + const Offset(0, 5);
          final selectedBefore = await pixel(ringPoint(selected));
          final nextBefore = await pixel(ringPoint(next));
          final selectedFocus = Focus.of(tester.element(find.text('Cadastro').last));
          final nextFocus = Focus.of(tester.element(find.text('Políticas').last));
          for (var i = 0; i < 80 && !selectedFocus.hasFocus; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
          }
          expect(selectedFocus.hasFocus, isTrue);
          checkFocus('Cadastro', selected);
          expect(await pixel(ringPoint(selected)), (tester.widget<DecoratedBox>(find.byKey(const ValueKey('profile-tab-focus-Cadastro'))).decoration as BoxDecoration).border!.top.color);
          expect(await pixel(ringPoint(selected)), isNot(selectedBefore));
          expect(rects(), initialRects);
          final selectedSide = tester.widget<OutlinedButton>(selected).style!.side!.resolve({MaterialState.focused})!;
          expect(selectedSide.color, AppTheme.adminColors(theme).selectedIndicator);
          expect(selectedSide.width, 2);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(nextFocus.hasFocus, isTrue);
          expect(find.byKey(const ValueKey('profile-tab-focus-Cadastro')), findsNothing);
          checkFocus('Políticas', next);
          expect(await pixel(ringPoint(next)), (tester.widget<DecoratedBox>(find.byKey(const ValueKey('profile-tab-focus-Políticas'))).decoration as BoxDecoration).border!.top.color);
          expect(await pixel(ringPoint(next)), isNot(nextBefore));
          expect(rects(), initialRects);
          expect(find.bySemanticsLabel('Cadastro'), findsWidgets);
          expect(find.bySemanticsLabel('Políticas'), findsWidgets);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(rects(), initialRects);
          expect(find.text('Validação de localização'), findsOneWidget);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        });
      }
    }
  }
  for (final dark in [false, true]) {
    for (final highContrast in [false, true]) {
      for (final width in [430.0, 1440.0]) {
        testWidgets('profile selected tabs $dark $highContrast $width', (tester) async {
          tester.view.physicalSize = Size(width, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final base = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
          final theme = highContrast ? AppTheme.highContrastTheme(base) : base;
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(MaterialApp(theme: theme, home: AdminEmployeesPage(api: _FakeAdminApi(employee: _employeeResponse(pendingAdjustments: 1)))));
          await tester.pumpAndSettle();
          final selectedCard = find.ancestor(of: find.text('Renata Souza').first, matching: find.byType(InkWell)).first;
          final cardBox = find.descendant(of: selectedCard, matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration)).first;
          final card = tester.widget<Container>(cardBox).decoration! as BoxDecoration;
          final cardBorder = (card.border! as Border).top;
          final labels = ['Cadastro', 'Políticas', 'Ponto', 'Notas'];
          final failures = <String>[];
          Finder button(String label) => find.ancestor(of: find.text(label).last, matching: find.byType(OutlinedButton)).first;
          double contrast(Color a, Color b) {
            final x = a.computeLuminance();
            final y = b.computeLuminance();
            return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
          }
          for (final label in labels) {
            final target = button(label);
            await tester.ensureVisible(target);
            await tester.tap(target);
            await tester.pumpAndSettle();
            final style = tester.widget<OutlinedButton>(target).style!;
            final side = style.side!.resolve({})!;
            if (side != cardBorder) {
              failures.add('$label $side != $cardBorder');
              continue;
            }
            final bg = style.backgroundColor!.resolve({})!;
            final section = find.ancestor(of: target, matching: find.byType(WorkspaceSectionCard)).first;
            final panel = tester.widget<Material>(find.descendant(of: section, matching: find.byType(Material)).first);
            final adjacent = Color.alphaBlend(panel.color!, theme.scaffoldBackgroundColor);
            expect(contrast(side.color, Color.alphaBlend(bg, adjacent)), greaterThanOrEqualTo(3), reason: 'selected surface $label');
            expect(contrast(side.color, adjacent), greaterThanOrEqualTo(3), reason: 'adjacent surface $label');
            expect(contrast(style.foregroundColor!.resolve({})!, Color.alphaBlend(bg, adjacent)), greaterThanOrEqualTo(4.5), reason: 'selected text $label');
            expect(find.bySemanticsLabel(label), findsWidgets);
            for (final other in labels.where((item) => item != label)) {
              final inactive = tester.widget<OutlinedButton>(button(other)).style!.side!.resolve({})!;
              expect(inactive.width, 1);
              expect(inactive.color, theme.colorScheme.outlineVariant);
            }
          }
          final first = button('Cadastro');
          await tester.ensureVisible(first);
          final focus = Focus.of(tester.element(find.text('Cadastro').last));
          focus.requestFocus();
          await tester.pump();
          expect(focus.hasFocus, isTrue);
          final focused = tester.widget<OutlinedButton>(first).style!.side!.resolve({MaterialState.focused})!;
          expect(focused.color, AppTheme.navigationColors(theme).focusRing);
          expect(focused.width, 2);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.text('E-mail'), findsWidgets);
          expect(tester.takeException(), isNull);
          semantics.dispose();
          expect(failures, isEmpty, reason: 'profile_tab_indicator_mismatch');
        });
      }
    }
  }
  for (final dark in [false, true]) {
    for (final highContrast in [false, true]) {
      for (final width in [430.0, 1440.0]) {
        testWidgets('team selected v2 $dark $highContrast $width', (tester) async {
          tester.view.physicalSize = Size(width, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final base = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
          final theme = highContrast ? AppTheme.highContrastTheme(base) : base;
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(MaterialApp(theme: theme, home: AdminEmployeesPage(api: _FakeAdminApi(employee: _employeeResponse(pendingAdjustments: 1)))));
          await tester.pumpAndSettle();
          BoxDecoration decoration(Finder child) => tester.widget<Container>(find.ancestor(of: child, matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration)).first).decoration! as BoxDecoration;
          final button = find.ancestor(of: find.text('Cadastro').last, matching: find.byType(OutlinedButton)).first;
          final style = tester.widget<OutlinedButton>(button).style!;
          expect(style.backgroundColor!.resolve({}), highContrast ? AppTheme.adminColors(theme).selectedContainer : theme.colorScheme.surfaceContainerHighest, reason: 'team_selected_v2 tab');
          expect(style.side!.resolve({})!.color, AppTheme.adminColors(theme).selectedIndicator, reason: 'profile_tab_indicator_mismatch');
          expect(style.side!.resolve({MaterialState.focused})!.width, 2);
          expect((decoration(find.text('Acompanhamento')).border! as Border).top.color, theme.colorScheme.outlineVariant);
          await tester.ensureVisible(find.text('Ponto').last);
          await tester.tap(find.text('Ponto').last);
          await tester.pumpAndSettle();
          for (final label in ['Gestão de ponto', 'Nenhum ponto manual registrado.']) {
            expect((decoration(find.text(label)).border! as Border).top.color, theme.colorScheme.outlineVariant, reason: 'team_selected_v2 $label');
          }
          expect(find.bySemanticsLabel('Ponto'), findsWidgets);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        });
      }
    }
  }
  for (final dark in [false, true]) {
    for (final highContrast in [false, true]) {
      for (final width in [430.0, 1440.0]) {
        testWidgets('team normal surfaces $dark $highContrast $width', (tester) async {
          tester.view.physicalSize = Size(width, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final base = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
          final theme = highContrast ? AppTheme.highContrastTheme(base) : base;
          await tester.pumpWidget(MaterialApp(
            theme: theme,
            home: AdminEmployeesPage(api: _FakeAdminApi(employee: _employeeResponse(pendingAdjustments: 1))),
          ));
          await tester.pumpAndSettle();
          BoxDecoration decoration(Finder child) {
            final container = find.ancestor(
              of: child,
              matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration),
            ).first;
            return tester.widget<Container>(container).decoration! as BoxDecoration;
          }
          for (final label in ['Perfil selecionado', 'Jornada', 'E-mail', 'Atenção operacional']) {
            final border = decoration(find.text(label).last).border! as Border;
            expect(border.top.color, theme.colorScheme.outlineVariant, reason: 'team_surface_color $label');
          }
          final button = find.ancestor(of: find.text('Cadastro').last, matching: find.byType(OutlinedButton)).first;
          final selected = tester.widget<OutlinedButton>(button).style!;
          expect(selected.backgroundColor!.resolve({}), highContrast ? AppTheme.adminColors(theme).selectedContainer : theme.colorScheme.surfaceContainerHighest);
          await tester.ensureVisible(find.text('Políticas').last);
          await tester.tap(find.text('Políticas').last);
          await tester.pumpAndSettle();
          expect(find.text('Validação de localização'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final dark in [false, true]) {
    for (final width in [430.0, 1440.0]) {
      for (final populated in [false, true]) {
        testWidgets('profile tabs rounded $dark $width $populated',
            (tester) async {
          tester.view.physicalSize = Size(width, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          final api = _FakeAdminApi(managedPunchesByEmployeeId: {
            'emp-99': populated
                ? [
                    ManagedPunchRecord(
                      id: 'test-punch',
                      employeeId: 'emp-99',
                      type: PunchType.checkIn,
                      timestamp: DateTime(2026, 5, 1, 8),
                      detail: 'Registro fictício',
                      projectId: null,
                      location: null,
                    )
                  ]
                : [],
          });
          await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: AdminEmployeesPage(api: api),
          ));
          await tester.pumpAndSettle();
          final failures = <String>[];
          void radius(Finder child, double expected, {int ancestor = 0}) {
            final containers = find.ancestor(
                of: child,
                matching: find.byWidgetPredicate(
                    (w) => w is Container && w.decoration is BoxDecoration));
            final decoration = tester
                .widget<Container>(containers.at(ancestor))
                .decoration! as BoxDecoration;
            if (decoration.borderRadius != BorderRadius.circular(expected)) {
              failures.add(
                  '$child expected $expected got ${decoration.borderRadius}');
            }
          }

          Future<void> tab(String label) async {
            final button = find
                .ancestor(
                    of: find.text(label).last,
                    matching: find.byType(OutlinedButton))
                .first;
            await tester.ensureVisible(button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(find.bySemanticsLabel(label), findsWidgets);
          }

          await tab('Políticas');
          for (final label in [
            'Validação de localização',
            'Dispositivo confiável',
            'Ajustes pendentes'
          ]) {
            radius(find.text(label), 12);
          }
          for (final icon in [
            Icons.location_searching_rounded,
            Icons.verified_user_outlined,
            Icons.task_alt_rounded
          ]) {
            radius(find.byIcon(icon), 8);
          }
          await tab('Notas');
          radius(find.text('Notas da gestão'), 12);
          expect(find.text('Nova contratação.'), findsOneWidget);
          await tab('Ponto');
          radius(find.text('Gestão de ponto'), 12);
          if (populated) {
            radius(find.text('Registro fictício'), 12);
            radius(find.byIcon(Icons.login_rounded).first, 8);
            radius(find.text('Entrada'), 8);
            final menu = find.byIcon(Icons.more_horiz_rounded).last;
            await tester.ensureVisible(menu);
            await tester.tap(menu);
            await tester.pumpAndSettle();
            expect(find.text('Remover'), findsWidgets);
            await tester.tap(find.text('Remover').last);
            await tester.pumpAndSettle();
            expect(find.text('Remover ponto'), findsOneWidget);
            await tester.tap(find.text('Cancelar'));
            await tester.pumpAndSettle();
            expect(api.deletedPunches, isEmpty);
          } else {
            radius(find.text('Nenhum ponto manual registrado.'), 12);
          }
          expect(tester.takeException(), isNull);
          semantics.dispose();
          expect(failures, isEmpty, reason: 'profile_tabs_radius');
        });
      }
    }
  }
  for (final dark in [false, true]) {
    for (final width in [430.0, 1440.0]) {
      testWidgets('profile surface radii $dark $width', (tester) async {
        tester.view.physicalSize = Size(width, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: AdminEmployeesPage(
            api: _FakeAdminApi(
                employee: _employeeResponse(pendingAdjustments: 1)),
          ),
        ));
        await tester.pumpAndSettle();
        final profile = find
            .ancestor(
              of: find.text('Perfil selecionado'),
              matching: find.byType(WorkspaceSectionCard),
            )
            .first;
        Finder inside(Finder finder) =>
            find.descendant(of: profile, matching: finder);
        void radius(Finder child, double value, {int ancestor = 0}) {
          final containers = find.ancestor(
              of: child,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container && widget.decoration is BoxDecoration,
              ));
          final decoration = tester
              .widget<Container>(containers.at(ancestor))
              .decoration! as BoxDecoration;
          expect(decoration.borderRadius, BorderRadius.circular(value),
              reason: 'profile_surface_radius');
        }

        if (width >= 560) {
          radius(inside(find.byIcon(Icons.manage_accounts_rounded)), 8);
        }
        for (final label in ['Ativo', 'Híbrido', 'Atenção operacional']) {
          radius(inside(find.text(label)), 8);
        }
        for (final label in ['Jornada', 'Horas de hoje', 'Última batida']) {
          radius(inside(find.text(label)), 12);
        }
        for (final icon in [
          Icons.schedule_rounded,
          Icons.av_timer_rounded,
          Icons.history_toggle_off_rounded
        ]) {
          final cardIcon = inside(find.byIcon(icon)).first;
          radius(cardIcon, 8);
        }
        radius(inside(find.text('E-mail')), 12);
        expect(inside(find.byType(Divider)), findsOneWidget);
        for (final label in ['Cadastro', 'Políticas', 'Ponto', 'Notas']) {
          final button = find.ancestor(
              of: inside(find.text(label)),
              matching: find.byType(OutlinedButton));
          final style = tester.widget<OutlinedButton>(button).style!;
          final shape = style.shape!.resolve(<MaterialState>{})!
              as RoundedRectangleBorder;
          expect(shape.borderRadius, BorderRadius.circular(8),
              reason: 'profile_surface_radius');
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          final selected = tester
              .widget<OutlinedButton>(button)
              .style!
              .backgroundColor!
              .resolve(<MaterialState>{});
          expect(
              selected,
              Theme.of(tester.element(button)).colorScheme.surfaceContainerHighest);
        }
        await tester.ensureVisible(inside(find.text('Editar')));
        await tester.tap(inside(find.text('Editar')));
        await tester.pumpAndSettle();
        expect(find.text('Editar funcionário'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final isPunch in [false, true]) {
    for (final dark in [false, true]) {
      for (final width in [430.0, 1440.0]) {
        testWidgets(
            'removal confirmation safety and radius $isPunch $dark $width',
            (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          final api = _FakeAdminApi(managedPunchesByEmployeeId: {
            'emp-99': [
              ManagedPunchRecord(
                id: 'punch-1',
                employeeId: 'emp-99',
                type: PunchType.checkIn,
                timestamp: DateTime(2026, 5, 1, 8),
                detail: 'Teste',
                projectId: null,
                location: null,
              )
            ],
          });
          await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: AdminEmployeesPage(api: api),
          ));
          await tester.pumpAndSettle();
          if (isPunch) {
            final tab = find.text('Ponto').last;
            await tester.ensureVisible(tab);
            await tester.tap(tab);
            await tester.pumpAndSettle();
          }
          Future<void> openDialog() async {
            if (isPunch) {
              final menu = find.byIcon(Icons.more_horiz_rounded).last;
              await tester.ensureVisible(menu);
              await tester.tap(menu);
              await tester.pumpAndSettle();
              await tester.tap(find.text('Remover').last);
            } else {
              final remove = find.byTooltip('Remover funcionário');
              await tester.ensureVisible(remove);
              await tester.tap(remove);
            }
            await tester.pumpAndSettle();
          }

          await openDialog();
          expect(find.text(isPunch ? 'Remover ponto' : 'Remover funcionário'),
              findsOneWidget);
          expect(find.textContaining('Esta ação não pode ser desfeita.'),
              findsOneWidget);
          expect(find.bySemanticsLabel('Cancelar'), findsWidgets);
          expect(find.bySemanticsLabel('Remover'), findsWidgets);
          expect(api.deletedEmployees, isEmpty);
          expect(api.deletedPunches, isEmpty);
          final shape = tester
              .widget<AlertDialog>(find.byType(AlertDialog))
              .shape as RoundedRectangleBorder;
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
          expect(api.deletedEmployees, isEmpty);
          expect(api.deletedPunches, isEmpty);
          await openDialog();
          expect(api.deletedEmployees, isEmpty);
          expect(api.deletedPunches, isEmpty);
          await tester.tap(find.text('Remover').last);
          await tester.pumpAndSettle();
          expect(api.deletedEmployees, isPunch ? isEmpty : ['emp-99']);
          expect(api.deletedPunches, isPunch ? ['emp-99/punch-1'] : isEmpty);
          semantics.dispose();
          expect(shape.borderRadius, BorderRadius.circular(12),
              reason: 'removal_dialog_radius_12');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('pending indicator at 200 percent on narrow viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: AdminEmployeesPage(
          api: _FakeAdminApi(
              employee: _employeeResponse(pendingAdjustments: 1))),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Acompanhamento'));
    await tester.pumpAndSettle();
    FlutterError.onError = previous;
    expect(errors, isEmpty, reason: errors.join('\n'));
    final indicator = find.text('Acompanhamento');
    expect(indicator, findsOneWidget);
    final pill =
        find.ancestor(of: indicator, matching: find.byType(Container)).first;
    final icon = find.descendant(
        of: pill, matching: find.byIcon(Icons.priority_high_rounded));
    expect(icon, findsOneWidget);
    final bounds = tester.getRect(pill);
    for (final child in [indicator, icon]) {
      final rect = tester.getRect(child);
      expect(bounds.contains(rect.topLeft), isTrue);
      expect(rect.right, lessThanOrEqualTo(bounds.right));
      expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
    }
    expect(tester.getSemantics(indicator).label, contains('Acompanhamento'));
    expect(find.bySemanticsLabel(RegExp('Acompanhamento')), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('profile identity hierarchy', (tester) async {
    for (final width in [1440.0, 430.0]) {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(home: AdminEmployeesPage(api: _FakeAdminApi())),
      );
      await tester.pumpAndSettle();
      final profile = find
          .ancestor(
            of: find.text('Perfil selecionado'),
            matching: find.byType(WorkspaceSectionCard),
          )
          .first;
      final name =
          find.descendant(of: profile, matching: find.text('Renata Souza'));
      final status = find.descendant(of: profile, matching: find.text('Ativo'));
      expect(
          tester.getBottomLeft(name).dy, lessThan(tester.getTopLeft(status).dy),
          reason: 'profile_identity_hierarchy');
      expect(find.descendant(of: profile, matching: find.text('Editar')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    addTearDown(tester.view.reset);
  });
  testWidgets('team toolbar composition', (tester) async {
    tester.view.physicalSize = const Size(1800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: AdminEmployeesPage(api: _FakeAdminApi())),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Buscar funcionário')).dy,
      lessThan(tester.getBottomLeft(find.text('Equipe')).dy + 20),
      reason: 'team_toolbar_composition',
    );
    expect(tester.getTopLeft(find.text('Jornada')).dy,
        closeTo(tester.getTopLeft(find.text('Última batida')).dy, 2));
    expect(tester.getTopLeft(find.text('Cadastro')).dy,
        closeTo(tester.getTopLeft(find.text('Notas')).dy, 2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('team directory stacks above selected profile', (tester) async {
    tester.view.physicalSize = const Size(1800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: AdminEmployeesPage(api: _FakeAdminApi())),
    );
    await tester.pumpAndSettle();

    final directory = find
        .ancestor(
          of: find.text('Buscar funcionário'),
          matching: find.byType(WorkspaceSectionCard),
        )
        .first;
    final profile = find
        .ancestor(
          of: find.text('Perfil selecionado'),
          matching: find.byType(WorkspaceSectionCard),
        )
        .first;
    expect(
      tester.getTopLeft(profile).dy,
      greaterThan(tester.getBottomLeft(directory).dy),
      reason: 'team_directory_layout',
    );
    expect(
      tester.getSize(directory).width,
      closeTo(tester.getSize(profile).width, 1),
      reason: 'team_directory_full_width',
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar funcionário'),
      'Renata',
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Limpar busca'), findsOneWidget);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    expect(find.text('Renata Souza'), findsWidgets);
    await tester.tap(find.byTooltip('Editar funcionário'));
    await tester.pumpAndSettle();
    expect(find.text('Editar funcionário'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nome'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'employee editor accepts two characters for role, department and unit',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: AdminEmployeesPage(api: _FakeAdminApi())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Novo funcionário'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'),
        'Ana Silva',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Cargo'), 'QA');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Departamento'),
        'IT',
      );
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Unidade'), 'HQ');
      final submit = find.text('Criar funcionário');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('Informe o cargo principal.'), findsNothing);
      expect(find.text('Informe o departamento.'), findsNothing);
      expect(find.text('Informe a unidade de referência.'), findsNothing);
      expect(find.text('Informe o nome.'), findsNothing);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Al');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Informe o nome.'), findsOneWidget);
    },
  );

  testWidgets('renders desktop admin header with create action on the right', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: AdminEmployeesPage(api: _FakeAdminApi())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administrar equipe'), findsOneWidget);
    expect(find.byType(WorkspaceHeader), findsOneWidget);
    expect(find.byType(WorkspaceMetricCard), findsNWidgets(4));
    expect(find.text('Novo funcionário'), findsOneWidget);
    expect(find.text('Editar selecionado'), findsNothing);
    expect(find.byTooltip('Editar funcionário'), findsOneWidget);
    expect(find.byTooltip('Remover funcionário'), findsOneWidget);
    expect(find.text('renata.souza@touchin.com'), findsOneWidget);
    expect(find.text('Sem batida recente'), findsNothing);
    expect(find.textContaining('Hoje:'), findsNothing);
    expect(find.text('Ativo'), findsOneWidget);
    expect(find.text('Resumo rápido'), findsOneWidget);
    expect(find.text('Cadastro'), findsOneWidget);
    expect(find.text('Políticas'), findsOneWidget);
    expect(find.text('Notas'), findsOneWidget);

    final punchTab = find.text('Ponto').last;
    await tester.ensureVisible(punchTab);
    await tester.tap(punchTab);
    await tester.pumpAndSettle();

    expect(find.text('Gestão de ponto'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    expect(find.text('Novo funcionário'), findsOneWidget);
  });

  testWidgets('does not render selected edit action in mobile header', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: AdminEmployeesPage(api: _FakeAdminApi())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Novo funcionário'), findsOneWidget);
    expect(find.text('Editar selecionado'), findsNothing);
    expect(find.byIcon(Icons.badge_rounded), findsNothing);
  });

  testWidgets('renders company data from auth context in the sidebar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: AdminEmployeesPage(api: _FakeAdminApi())),
    );
    await tester.pumpAndSettle();

    expect(find.text('TouchIn'), findsOneWidget);
    expect(find.text('TouchIn Tecnologia LTDA'), findsOneWidget);
    expect(find.textContaining('CNPJ'), findsNothing);
    expect(find.text('Contato'), findsNothing);
    expect(find.text('co*****@touchin.com'), findsNothing);
    expect(find.text('Tel. 11*****0000'), findsNothing);
    expect(
      find.text('Perfil administrador'),
      findsNothing,
      reason: 'workspace_sidebar_chips_removed',
    );
    expect(
      find.text('Dados mascarados'),
      findsNothing,
      reason: 'workspace_sidebar_chips_removed',
    );
  });

  testWidgets('opens punch tab without runtime error and shows empty state', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: AdminEmployeesPage(api: _FakeAdminApi())),
    );
    await tester.pumpAndSettle();

    final punchTab = find.text('Ponto').last;
    await tester.ensureVisible(punchTab);
    await tester.tap(punchTab);
    await tester.pumpAndSettle();

    expect(find.text('Novo ponto'), findsWidgets);
    expect(find.byIcon(Icons.refresh_rounded), findsWidgets);
    expect(find.text('Nenhum ponto manual registrado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps admin punch header readable at desktop width',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AdminEmployeesPage(api: _FakeAdminApi()),
        ),
      );
      await tester.pumpAndSettle();

      final punchTab = find.text('Ponto').last;
      await tester.ensureVisible(punchTab);
      await tester.tap(punchTab);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'admin_punch_header_title_width_collapsed',
      );

      final heading = find.text('Gestão de ponto');
      expect(heading, findsOneWidget);
      expect(
        tester.getSize(heading).width,
        greaterThan(80),
        reason: 'admin_punch_header_title_width_collapsed',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('paginates managed punches on the admin screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminEmployeesPage(
          api: _FakeAdminApi(
            managedPunchesByEmployeeId: <String, List<ManagedPunchRecord>>{
              'emp-99': List<ManagedPunchRecord>.generate(5, (index) {
                final day = index + 1;
                return ManagedPunchRecord(
                  id: 'punch-$day',
                  employeeId: 'emp-99',
                  type: PunchType.checkIn,
                  timestamp: DateTime(2026, 5, day, 8, 0),
                  detail: 'Ponto $day',
                  projectId: null,
                  location: null,
                );
              }),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final punchTab = find.text('Ponto').last;
    await tester.ensureVisible(punchTab);
    await tester.tap(punchTab);
    await tester.pumpAndSettle();

    expect(find.text('Página 1 de 2'), findsOneWidget);
    expect(find.text('Ponto 5'), findsOneWidget);
    expect(find.text('Ponto 2'), findsOneWidget);
    expect(find.text('Ponto 1'), findsNothing);

    final nextPage = find.text('Próxima');
    await tester.ensureVisible(nextPage);
    await tester.tap(nextPage);
    await tester.pumpAndSettle();

    expect(find.text('Página 2 de 2'), findsOneWidget);
    expect(find.text('Ponto 1'), findsOneWidget);
    expect(find.text('Ponto 5'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('employee search and selection expose accessible controls', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: AdminEmployeesPage(api: _FakeAdminApi())),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar funcionário'),
      'Renata',
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Limpar busca'), findsOneWidget);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Limpar busca'), findsNothing);

    final employeeName = find.text('Renata Souza').first;
    await tester.ensureVisible(employeeName);
    await tester.tap(employeeName);
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: employeeName,
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('shows the linked manager role separately from job title', (
    WidgetTester tester,
  ) async {
    await _openEditor(tester, _employeeResponse(accessRole: 'manager'));

    expect(
      find.text('Gestor'),
      findsOneWidget,
      reason: 'employee_access_role_manager_not_shown',
    );
    expect(find.text('Analista Financeira'), findsOneWidget);
  });

  testWidgets(
    'does not offer an access role for employees without an account',
    (WidgetTester tester) async {
      await _openEditor(
        tester,
        _employeeResponse(hasAccount: false, accessRole: null),
      );

      expect(
        find.text('Sem acesso ao sistema'),
        findsOneWidget,
        reason: 'employee_access_role_missing_account_not_distinguished',
      );
      expect(
        find.byKey(const ValueKey('employee-access-role-dropdown')),
        findsNothing,
      );
    },
  );

  testWidgets('shows the linked admin role as read-only', (
    WidgetTester tester,
  ) async {
    await _openEditor(tester, _employeeResponse(accessRole: 'admin'));

    expect(
      find.text('Administrador (não editável)'),
      findsOneWidget,
      reason: 'employee_access_role_admin_not_read_only',
    );
    expect(
      find.byKey(const ValueKey('employee-access-role-dropdown')),
      findsNothing,
    );
  });
}

Future<void> _openEditor(WidgetTester tester, EmployeeProfile employee) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: AdminEmployeesPage(api: _FakeAdminApi(employee: employee)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Editar funcionário'));
  await tester.pumpAndSettle();
}

EmployeeProfile _employeeResponse({
  bool? hasAccount = true,
  String? accessRole = 'manager',
  bool includeAccountMetadata = true,
  int pendingAdjustments = 0,
}) =>
    EmployeeProfile.fromJson(<String, dynamic>{
      'id': 'emp-99',
      'name': 'Renata Souza',
      'role': 'Analista Financeira',
      'department': 'Financeiro',
      'email': 'renata.souza@touchin.com',
      'phone': '(11) 94444-6060',
      'unit': 'Backoffice Centro',
      'expectedShiftStart': '08:00:00',
      'expectedShiftEnd': '17:00:00',
      'status': 'active',
      'workMode': 'hybrid',
      'roleLevel': 'specialist',
      'requiresLocationOnPunch': false,
      'trustedDeviceRequired': true,
      'todayWorkedMinutes': 0,
      'pendingAdjustments': pendingAdjustments,
      'lastPunchAt': null,
      'notes': 'Nova contratação.',
      if (includeAccountMetadata) 'hasAccount': hasAccount,
      if (includeAccountMetadata) 'accessRole': accessRole,
    });

class _FakeAdminApi extends TouchInApi {
  _FakeAdminApi({
    EmployeeProfile? employee,
    Map<String, List<ManagedPunchRecord>>? managedPunchesByEmployeeId,
  })  : employee = employee ?? _employeeResponse(),
        managedPunchesByEmployeeId =
            managedPunchesByEmployeeId ?? <String, List<ManagedPunchRecord>>{};

  final EmployeeProfile employee;
  final deletedEmployees = <String>[];
  final deletedPunches = <String>[];

  @override
  Future<void> deleteEmployee(String employeeId) async {
    deletedEmployees.add(employeeId);
  }

  final Map<String, List<ManagedPunchRecord>> managedPunchesByEmployeeId;

  @override
  Future<AuthContext> getAuthContext() async {
    return AuthContext(
      company: const AuthCompanySummary(
        id: 'cmp-01',
        legalName: 'TouchIn Tecnologia LTDA',
        tradeName: 'TouchIn',
        cnpjMasked: '12.***.***/****-90',
        emailMasked: 'co*****@touchin.com',
        phoneMasked: '11*****0000',
      ),
      user: const AuthUserSummary(
        id: 'usr-01',
        email: 'admin@touchin.com',
        role: 'admin',
        employeeId: null,
      ),
    );
  }

  @override
  Future<List<EmployeeProfile>> listEmployees() async {
    return <EmployeeProfile>[employee];
  }

  @override
  Future<ManagedPunchPage> listManagedPunches(
    String employeeId, {
    int page = 1,
    int limit = 4,
  }) async {
    final records = <ManagedPunchRecord>[
      ...managedPunchesByEmployeeId[employeeId] ?? <ManagedPunchRecord>[],
    ]..sort((left, right) {
        final timestampComparison = right.timestamp.compareTo(left.timestamp);
        if (timestampComparison != 0) {
          return timestampComparison;
        }
        return right.id.compareTo(left.id);
      });
    final totalPages = records.isEmpty ? 1 : (records.length / limit).ceil();
    final normalizedPage = page.clamp(1, totalPages);
    final startIndex = (normalizedPage - 1) * limit;
    final endIndex = (startIndex + limit).clamp(0, records.length);
    return ManagedPunchPage(
      records: records.sublist(startIndex, endIndex),
      recordsPage: normalizedPage,
      recordsPageSize: limit,
      recordsTotal: records.length,
      recordsTotalPages: totalPages,
      recordsHasPrevious: normalizedPage > 1,
      recordsHasNext: normalizedPage < totalPages,
    );
  }

  @override
  Future<ManagedPunchRecord> createManagedPunch({
    required String employeeId,
    required ManagedPunchDraft draft,
  }) async {
    return ManagedPunchRecord(
      id: 'punch-01',
      employeeId: employeeId,
      type: draft.type,
      timestamp: draft.timestamp,
      detail: draft.detail,
      projectId: draft.projectId,
      location: draft.location,
    );
  }

  @override
  Future<ManagedPunchRecord> updateManagedPunch({
    required String employeeId,
    required String punchId,
    required ManagedPunchDraft draft,
  }) async {
    return ManagedPunchRecord(
      id: punchId,
      employeeId: employeeId,
      type: draft.type,
      timestamp: draft.timestamp,
      detail: draft.detail,
      projectId: draft.projectId,
      location: draft.location,
    );
  }

  @override
  Future<void> deleteManagedPunch({
    required String employeeId,
    required String punchId,
  }) async {
    deletedPunches.add('$employeeId/$punchId');
  }
}
