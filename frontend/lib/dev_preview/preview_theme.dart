import 'package:flutter/material.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

/// Offline fallback typography avoids the production Google Fonts downloader.
/// Workspace widgets, semantic colors, layouts and navigation stay unchanged.
ThemeData previewTheme(Brightness brightness) {
  return AppTheme.offlineTheme(brightness);
}
