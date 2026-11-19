import 'package:flutter/widgets.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/time_tracking/application/punch_location_service.dart';

/// Dependencies belong to one application tree, including its logout action.
/// No global API replacement is used by the developer preview.
class AppDependencies extends InheritedWidget {
  const AppDependencies({
    super.key,
    required this.api,
    this.onLogout,
    this.punchLocationService,
    required super.child,
  });

  final TouchInApi? api;
  final PunchLocationService? punchLocationService;
  final VoidCallback? onLogout;

  static AppDependencies? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppDependencies>();

  @override
  bool updateShouldNotify(AppDependencies oldWidget) =>
      api != oldWidget.api || onLogout != oldWidget.onLogout;
}
