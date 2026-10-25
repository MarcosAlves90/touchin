import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      final localColors = AppTheme.adminColors(localTheme);
      expect(
        _decorationColorAncestor(
            tester, activeName, localColors.selectedContainer),
        localColors.selectedContainer,
      );
      expect(
        _contrast(_renderedTextColor(tester, activeName),
            localColors.selectedContainer),
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
        _decorationColorAncestor(
            tester, selectedInactive, localColors.selectedContainer),
        localColors.selectedContainer,
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

      final eventText = find.text('Funcionário atualizado - Sucesso').first;
      final auditTheme = Theme.of(tester.element(eventText));
      expect(
        _contrast(
          _renderedTextColor(tester, eventText),
          auditTheme.scaffoldBackgroundColor,
        ),
        greaterThanOrEqualTo(4.5),
      );
      final filterText = find.text('Filtros da auditoria');
      final filterCard = tester.widget<Card>(
        find.ancestor(of: filterText, matching: find.byType(Card)).first,
      );
      final filterBackground = filterCard.color ??
          auditTheme.cardTheme.color ??
          auditTheme.colorScheme.surface;
      expect(
        _contrast(
          _renderedTextColor(tester, filterText),
          filterBackground,
        ),
        greaterThanOrEqualTo(4.5),
      );
      final applyButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Aplicar filtros'),
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

      await tester.tap(find.text('Carregar mais eventos'));
      await tester.pumpAndSettle();
      final endText =
          find.text('Todos os eventos de auditoria foram carregados.');
      expect(endText, findsOneWidget);
      final endFocus = tester.widget<Focus>(
        find.ancestor(of: endText, matching: find.byType(Focus)).first,
      );
      endFocus.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(endFocus.focusNode!.hasFocus, isTrue);
      final endContainer = tester.widget<Container>(
        find.ancestor(
          of: endText,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                ((widget.decoration! as BoxDecoration).border?.top.width == 2),
          ),
        ),
      );
      final focusColor =
          (endContainer.decoration! as BoxDecoration).border!.top.color;
      expect(focusColor, AppTheme.adminColors(auditTheme).selectedIndicator);
      expect(
        _contrast(focusColor, auditTheme.scaffoldBackgroundColor),
        greaterThanOrEqualTo(3),
      );
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
