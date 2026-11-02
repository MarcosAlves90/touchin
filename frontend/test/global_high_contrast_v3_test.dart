import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:touchin_flutter/features/auth/presentation/widgets/auth_shell.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_page.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final brightness in Brightness.values) {
    testWidgets(
        'contrast_v3_regression disabled authentication button $brightness',
        (tester) async {
      final normal = brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme;
      final high = AppTheme.highContrastTheme(normal);
      await tester.pumpWidget(MaterialApp(
          theme: high,
          home: const Scaffold(
              body: AuthFormFrame(
                  child: ElevatedButton(
                      onPressed: null, child: Text('Entrar'))))));
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final style = high.elevatedButtonTheme.style!;
      final disabled = <WidgetState>{WidgetState.disabled};
      final bg = style.backgroundColor!.resolve(disabled)!;
      final fg = style.foregroundColor!.resolve(disabled)!;
      final side = style.side?.resolve(disabled);
      final frame = tester.widget<Card>(find
          .descendant(
              of: find.byType(AuthFormFrame), matching: find.byType(Card))
          .first);
      final card = frame.color ?? high.cardColor;
      expect(button.onPressed, isNull);
      expect(contrast(fg, bg), greaterThanOrEqualTo(4.5),
          reason: 'contrast_v3_regression text');
      expect(
          math.max(contrast(bg, card),
              side == null ? 0 : contrast(side.color, card)),
          greaterThanOrEqualTo(3),
          reason: 'contrast_v3_regression button outline');
      expect(bg, isNot(style.backgroundColor!.resolve(<WidgetState>{})),
          reason: 'contrast_v3_regression state');
    });
    for (final isHigh in [false, true]) {
      testWidgets(
          'contrast_v3_regression team field keyboard focus $brightness high=$isHigh',
          (tester) async {
        tester.view.physicalSize = const Size(1440, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final normal = brightness == Brightness.light
            ? AppTheme.lightTheme
            : AppTheme.darkTheme;
        final theme = isHigh ? AppTheme.highContrastTheme(normal) : normal;
        await tester.pumpWidget(MaterialApp(
            theme: theme, home: AdminEmployeesPage(api: FakeApi())));
        await tester.pumpAndSettle();
        final finder = find.widgetWithText(TextField, 'Buscar funcionário');
        expect(finder, findsOneWidget);
        for (var i = 0; i < 40; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final editable = tester.widget<EditableText>(
              find.descendant(of: finder, matching: find.byType(EditableText)));
          if (editable.focusNode.hasFocus) break;
        }
        final editable = tester.widget<EditableText>(
            find.descendant(of: finder, matching: find.byType(EditableText)));
        expect(editable.focusNode.hasFocus, isTrue,
            reason: 'contrast_v3_regression team keyboard');
        final local = Theme.of(tester.element(finder));
        final border = local.inputDecorationTheme.focusedBorder!.borderSide;
        expect(contrast(border.color, local.inputDecorationTheme.fillColor!),
            greaterThanOrEqualTo(3),
            reason: 'contrast_v4_regression team focus');
      });
      testWidgets(
          'contrast_v3_regression login field keyboard focus $brightness high=$isHigh',
          (tester) async {
        final normal = brightness == Brightness.light
            ? AppTheme.lightTheme
            : AppTheme.darkTheme;
        final theme = isHigh ? AppTheme.highContrastTheme(normal) : normal;
        await tester
            .pumpWidget(MaterialApp(theme: theme, home: const LoginPage()));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final field =
            tester.widget<EditableText>(find.byType(EditableText).first);
        expect(field.focusNode.hasFocus, isTrue,
            reason: 'contrast_v3_regression keyboard');
        final border = theme.inputDecorationTheme.focusedBorder!.borderSide;
        expect(contrast(border.color, theme.inputDecorationTheme.fillColor!),
            greaterThanOrEqualTo(3),
            reason: 'contrast_v4_regression login focus');
      });
    }
    testWidgets('contrast_v3_regression project active text $brightness',
        (tester) async {
      final normal = brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme;
      final high = AppTheme.highContrastTheme(normal);
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          MaterialApp(theme: high, home: ProjectTasksPage(api: FakeApi())));
      await tester.pumpAndSettle();
      final text = find.text('Ativo').last;
      final widget = tester.widget<Text>(text);
      final containers = find.ancestor(
          of: text,
          matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration));
      final background = (tester.widget<Container>(containers.first).decoration!
              as BoxDecoration)
          .color!;
      final actualBg = Color.alphaBlend(background, high.colorScheme.surface);
      expect(
          contrast(widget.style!.color!, actualBg), greaterThanOrEqualTo(4.5),
          reason: 'contrast_v3_regression project status');
    });
  }
}

class FakeApi extends TouchInApi {
  @override
  Future<AuthContext> getAuthContext() async => const AuthContext(
      company: AuthCompanySummary(
          id: 'c',
          legalName: 'Company',
          tradeName: 'Company',
          cnpjMasked: '1',
          emailMasked: 'a',
          phoneMasked: '1'),
      user: AuthUserSummary(
          id: 'u', email: 'a@b.com', role: 'manager', employeeId: 'e'));
  @override
  Future<List<ProjectSummary>> listProjects({ProjectStatus? status}) async => [
        ProjectSummary(
            id: 'p',
            name: 'Projeto',
            description: '',
            taskEmployeeLimit: 2,
            status: ProjectStatus.active,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026))
      ];
  @override
  Future<List<ProjectMemberSummary>> listProjectMembers(
          String projectId) async =>
      [];
  @override
  Future<List<TaskRecord>> listTasks(String projectId) async => [];
  @override
  Future<List<EmployeeProfile>> listEmployees() async => [];
}
