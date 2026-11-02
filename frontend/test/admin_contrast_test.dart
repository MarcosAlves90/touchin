import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/accessibility_tools.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final highContrast in [false, true]) {
      for (final width in [430.0, 1440.0]) {
        testWidgets('team_selection_indicator $brightness $highContrast $width', (tester) async {
          tester.view.physicalSize = Size(width, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          final base = brightness == Brightness.light ? AppTheme.lightTheme : AppTheme.darkTheme;
          final theme = highContrast ? AppTheme.highContrastTheme(base) : base;
          await tester.pumpWidget(MaterialApp(theme: theme, home: AdminEmployeesPage(api: _ContrastApi(employees: _employees))));
          await tester.pumpAndSettle();
          final active = find.text('Active Employee').first;
          final inactive = find.text('Inactive Employee').first;
          await tester.ensureVisible(active);
          await tester.tap(active);
          await tester.pumpAndSettle();
          final tile = find.ancestor(of: active, matching: find.byType(InkWell)).first;
          final box = find.descendant(of: tile, matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration)).first;
          final decoration = tester.widget<Container>(box).decoration! as BoxDecoration;
          final border = (decoration.border! as Border).top;
          final localTheme = Theme.of(tester.element(active));
          final section = find.ancestor(of: tile, matching: find.byType(WorkspaceSectionCard)).first;
          final panel = tester.widget<Material>(find.descendant(of: section, matching: find.byType(Material)).first);
          final adjacent = Color.alphaBlend(panel.color!, localTheme.scaffoldBackgroundColor);
          if (!highContrast) {
            expect(border.color, localTheme.colorScheme.outline, reason: 'Normal selection must use the shared outline token');
          }
          expect(_contrast(border.color, decoration.color!), greaterThanOrEqualTo(3), reason: 'selected surface');
          expect(_contrast(border.color, adjacent), greaterThanOrEqualTo(3), reason: 'composited adjacent panel');
          final selected = find.ancestor(of: active, matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.selected == true));
          expect(selected, findsWidgets);
          await tester.ensureVisible(inactive);
          final focus = Focus.of(tester.element(inactive));
          focus.requestFocus();
          await tester.pump();
          expect(focus.hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.ancestor(of: inactive, matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.selected == true)), findsWidgets);
          expect(find.ancestor(of: active, matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.selected == false)), findsWidgets);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        });
      }
    }

    testWidgets(
        '${brightness.name} input borders distinguish enabled and focused controls',
        (tester) async {
      final theme = AppTheme.adminContrastTheme(
        brightness == Brightness.light
            ? AppTheme.lightTheme
            : AppTheme.darkTheme,
      );
      final inputTheme = theme.inputDecorationTheme;
      final fill = inputTheme.fillColor!;
      expect(
        _contrast(inputTheme.enabledBorder!.borderSide.color, fill),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrast(inputTheme.focusedBorder!.borderSide.color, fill),
        greaterThanOrEqualTo(3),
      );
      expect(
        inputTheme.disabledBorder!.borderSide.color,
        isNot(inputTheme.enabledBorder!.borderSide.color),
      );
      final adminColors = theme.extension<AdminSemanticColors>()!;
      expect(
        _contrast(
            adminColors.selectedForeground, adminColors.selectedContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(adminColors.selectedIndicator, theme.colorScheme.surface),
        greaterThanOrEqualTo(3),
      );
      for (final tone in <AdminToneColors>[
        adminColors.success,
        adminColors.warning,
        adminColors.info,
        adminColors.danger,
        adminColors.neutral,
      ]) {
        expect(_contrast(tone.foreground, tone.container),
            greaterThanOrEqualTo(4.5));
        expect(
          _contrast(tone.foreground, theme.colorScheme.surfaceContainerHighest),
          greaterThanOrEqualTo(3),
        );
      }
      expect(
        _contrast(theme.colorScheme.onSurface, adminColors.selectedContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(
            theme.colorScheme.onSurfaceVariant, theme.colorScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.surfaceContainerHighest,
        ),
        greaterThanOrEqualTo(4.5),
      );
      final compositedCard = Color.alphaBlend(
        theme.colorScheme.surface.withValues(alpha: 0.8),
        theme.scaffoldBackgroundColor,
      );
      expect(
        _contrast(theme.colorScheme.onSurface, compositedCard),
        greaterThanOrEqualTo(4.5),
      );
      await tester
          .pumpWidget(MaterialApp(theme: theme, home: const SizedBox()));
    });

    testWidgets('${brightness.name} team global contrast and keyboard activation', (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = brightness == Brightness.light ? AppTheme.lightTheme : AppTheme.darkTheme;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        builder: (context, child) => AccessibilityTools(child: child!),
        home: AdminEmployeesPage(api: _ContrastApi(employees: _employees)),
      ));
      await tester.pumpAndSettle();
      final name = find.text('Active Employee').first;
      await tester.tap(name);
      await tester.pumpAndSettle();
      expect(_decorationColorAncestor(tester, name, theme.colorScheme.surfaceContainerHighest), isNotNull);
      await tester.tap(find.bySemanticsLabel('Acessibilidade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alto contraste'));
      await tester.pumpAndSettle();
      final high = Theme.of(tester.element(name));
      expect(high.extension<HighContrastMarker>(), isNotNull);
      final selected = AppTheme.adminColors(high).selectedContainer;
      expect(_decorationColorAncestor(tester, name, selected), selected);
      expect(_contrast(_renderedTextColor(tester, name), selected), greaterThanOrEqualTo(4.5));
      await tester.tap(find.bySemanticsLabel('Acessibilidade'));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(OutlinedButton, 'Ponto').last;
      await tester.ensureVisible(button);
      final focus = Focus.of(tester.element(find.text('Ponto').last));
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(button).style!.backgroundColor!.resolve({}), selected);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${brightness.name} employee states render accessible colors',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme;
      final api = _ContrastApi(employees: _employees);
      await tester.pumpWidget(
        MaterialApp(theme: theme, home: AdminEmployeesPage(api: api)),
      );
      await tester.pumpAndSettle();

      final activeName = find.text('Active Employee').first;
      final inactiveName = find.text('Inactive Employee').first;
      await tester.tap(activeName);
      await tester.pumpAndSettle();
      final localTheme = Theme.of(tester.element(activeName));
      final selectedBackground = localTheme.colorScheme.surfaceContainerHighest;
      expect(selectedBackground, isNot(localTheme.colorScheme.surface));
      expect(
        _decorationColorAncestor(tester, activeName, selectedBackground),
        selectedBackground,
      );
      expect(
        _contrast(_renderedTextColor(tester, activeName), selectedBackground),
        greaterThanOrEqualTo(4.5),
      );
      final pillBackground = localTheme.colorScheme.surfaceContainerHighest;
      final activeLabel = find.text('Ativo').last;
      expect(
        _decorationColorAncestor(tester, activeLabel, pillBackground),
        pillBackground,
      );
      expect(
        _contrast(_renderedTextColor(tester, activeLabel), pillBackground),
        greaterThanOrEqualTo(4.5),
      );
      final activeIcon = tester.widget<Icon>(
        find.byIcon(Icons.check_circle_rounded).last,
      );
      expect(
        _contrast(activeIcon.color!, pillBackground),
        greaterThanOrEqualTo(3),
      );

      await tester.tap(inactiveName);
      await tester.pumpAndSettle();
      final selectedInactive = find.text('Inactive Employee').first;
      expect(
        _decorationColorAncestor(tester, selectedInactive, selectedBackground),
        selectedBackground,
      );
      final inactiveLabel = find.text('Inativo').last;
      expect(
        _decorationColorAncestor(tester, inactiveLabel, pillBackground),
        pillBackground,
      );
      expect(
        _contrast(_renderedTextColor(tester, inactiveLabel), pillBackground),
        greaterThanOrEqualTo(4.5),
      );
      final inactiveIcon = tester.widget<Icon>(
        find.byIcon(Icons.do_not_disturb_on_rounded).last,
      );
      expect(
        _contrast(inactiveIcon.color!, pillBackground),
        greaterThanOrEqualTo(3),
      );
      final profileLabel = find.text('Perfil selecionado');
      final sectionMaterial = tester.widget<Material>(
        find.ancestor(of: profileLabel, matching: find.byType(Material)).first,
      );
      final composedSectionBackground = _composite(
        sectionMaterial.color!,
        localTheme.scaffoldBackgroundColor,
      );
      expect(
        sectionMaterial.color!.alpha,
        lessThan(255),
        reason: 'The employee detail card uses a translucent surface.',
      );
      expect(
        _contrast(
          _renderedTextColor(tester, profileLabel),
          composedSectionBackground,
        ),
        greaterThanOrEqualTo(4.5),
      );

      final inactiveFilter = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Inativos'),
      );
      expect(inactiveFilter.selected, isFalse);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Inativos'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Inativos'),
            )
            .selected,
        isTrue,
      );
      expect(find.text('Active Employee'), findsNothing);

      final search = find.widgetWithText(TextField, 'Buscar funcionário');
      await tester.tap(search);
      await tester.pump();
      final decorator = tester
          .widgetList<InputDecorator>(find.byType(InputDecorator))
          .firstWhere(
              (item) => item.decoration.labelText == 'Buscar funcionário');
      expect(decorator.isFocused, isTrue);
      final focusedBorder =
          decorator.decoration.focusedBorder as OutlineInputBorder;
      expect(
        _contrast(
          focusedBorder.borderSide.color,
          decorator.decoration.fillColor ??
              localTheme.inputDecorationTheme.fillColor!,
        ),
        greaterThanOrEqualTo(3),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('page header audit filter rendered contrast in ${brightness.name}',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme;
      await tester.pumpWidget(MaterialApp(
          theme: theme, home: AdminAuditPage(api: _ContrastApi())));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey<String>('audit-filters-button'));
      final label = find.descendant(of: button, matching: find.text('Filtros'));
      final background = Theme.of(tester.element(button)).scaffoldBackgroundColor;
      expect(_contrast(_renderedTextColor(tester, label), background),
          greaterThanOrEqualTo(4.5));
    });

    testWidgets(
        '${brightness.name} audit filters and event indicators use rendered colors',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme;
      final api = _ContrastApi(auditEvents: _auditEvents);
      await tester.pumpWidget(
        MaterialApp(theme: theme, home: AdminAuditPage(api: api)),
      );
      await tester.pumpAndSettle();

      final eventText = find.text('Funcionário atualizado').first;
      final auditTheme = Theme.of(tester.element(eventText));
      expect(
        _contrast(
          _renderedTextColor(tester, eventText),
          auditTheme.scaffoldBackgroundColor,
        ),
        greaterThanOrEqualTo(4.5),
      );

      final filtersButton =
          find.byKey(const ValueKey<String>('audit-filters-button'));
      await tester.ensureVisible(filtersButton);
      await tester.tap(filtersButton);
      await tester.pumpAndSettle();
      final filterText = find.text('Filtros da auditoria');
      final filterPanel = tester.widget<Container>(
        find.byKey(const ValueKey<String>('audit-filter-panel')),
      );
      final filterBackground =
          (filterPanel.decoration! as BoxDecoration).color ??
              auditTheme.colorScheme.surface;
      expect(
        _contrast(
          _renderedTextColor(tester, filterText),
          filterBackground,
        ),
        greaterThanOrEqualTo(4.5),
      );
      final applyButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aplicar filtros'),
      );
      final applyText = find.text('Aplicar filtros');
      expect(
        _contrast(
          _renderedTextColor(tester, applyText),
          applyButton.style?.backgroundColor?.resolve(<WidgetState>{}) ??
              auditTheme.colorScheme.primary,
        ),
        greaterThanOrEqualTo(4.5),
      );

      await tester.ensureVisible(filtersButton);
      await tester.tap(filtersButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carregar mais eventos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final endText = find.text('Todos os eventos carregados.');
      expect(endText, findsOneWidget);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.content, isA<Text>());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(endText, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

class _ContrastApi extends TouchInApi {
  _ContrastApi(
      {this.employees = const <EmployeeProfile>[],
      this.auditEvents = const <AuditEventResponse>[]});

  final List<EmployeeProfile> employees;
  final List<AuditEventResponse> auditEvents;

  @override
  Future<AuthContext> getAuthContext() async => AuthContext(
        company: const AuthCompanySummary(
          id: 'company',
          legalName: 'Empresa',
          tradeName: 'Empresa',
          cnpjMasked: '',
          emailMasked: '',
          phoneMasked: '',
        ),
        user: const AuthUserSummary(
          id: 'user',
          email: 'admin@example.test',
          role: 'admin',
          employeeId: null,
        ),
      );

  @override
  Future<List<EmployeeProfile>> listEmployees() async => employees;

  @override
  Future<ManagedPunchPage> listManagedPunches(String employeeId,
          {int page = 1, int limit = 4}) async =>
      const ManagedPunchPage(
          records: <ManagedPunchRecord>[],
          recordsPage: 1,
          recordsPageSize: 4,
          recordsTotal: 0,
          recordsTotalPages: 1,
          recordsHasPrevious: false,
          recordsHasNext: false);

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
    final start = (page - 1) * limit;
    if (start >= auditEvents.length) return <AuditEventResponse>[];
    return auditEvents.skip(start).take(limit).toList();
  }
}

final List<EmployeeProfile> _employees = <EmployeeProfile>[
  _employee('active-1', 'Active Employee', EmployeeStatus.active),
  _employee('inactive-1', 'Inactive Employee', EmployeeStatus.inactive),
];

EmployeeProfile _employee(String id, String name, EmployeeStatus status) =>
    EmployeeProfile(
      id: id,
      name: name,
      role: 'Analista',
      department: 'Operações',
      email: '$id@example.test',
      phone: '(11) 90000-0000',
      unit: 'Matriz',
      expectedShiftStart: const TimeOfDay(hour: 8, minute: 0),
      expectedShiftEnd: const TimeOfDay(hour: 17, minute: 0),
      status: status,
      workMode: EmployeeWorkMode.hybrid,
      roleLevel: RoleLevel.specialist,
      requiresLocationOnPunch: false,
      trustedDeviceRequired: false,
      todayWorkedMinutes: 420,
      pendingAdjustments: 0,
      lastPunchAt: null,
      notes: 'Equipe de operações',
    );

final List<AuditEventResponse> _auditEvents = List<AuditEventResponse>.generate(
  51,
  (index) => AuditEventResponse(
    id: 'audit-$index',
    timestamp: DateTime.utc(2026, 10, 20, 12, index % 60),
    companyId: 'company',
    actorUserId: 'admin-user',
    projectId: 'project-1',
    action: 'employee.updated',
    entityType: 'employee',
    entityId: 'employee-$index',
    result: 'success',
  ),
);

double _contrast(Color foreground, Color background) {
  final first = _luminance(foreground);
  final second = _luminance(background);
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

Color _renderedTextColor(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  return paragraph.text.style!.color!;
}

Color? _decorationColorAncestor(
  WidgetTester tester,
  Finder finder,
  Color expected,
) {
  final ancestors = find.ancestor(of: finder, matching: find.byType(Container));
  for (final container in tester.widgetList<Container>(ancestors)) {
    if (container.decoration is BoxDecoration) {
      final color = (container.decoration! as BoxDecoration).color;
      if (color == expected) {
        return color;
      }
    }
  }
  return null;
}

Color _composite(Color foreground, Color background) =>
    Color.alphaBlend(foreground, background);

double _luminance(Color color) {
  double channel(int value) {
    final normalized = value / 255;
    return normalized <= 0.04045
        ? normalized / 12.92
        : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((color.r * 255).round()) +
      0.7152 * channel((color.g * 255).round()) +
      0.0722 * channel((color.b * 255).round());
}
