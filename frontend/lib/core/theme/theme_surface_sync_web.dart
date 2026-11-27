import 'dart:js_interop';

import 'package:flutter/material.dart';

@JS('touchinSetThemeMode')
external JSFunction? get _setBrowserThemeMode;

@JS('touchinPersistThemeMode')
external JSFunction? get _persistBrowserThemeMode;

void syncBrowserThemeMode(ThemeMode mode) {
  _setBrowserThemeMode?.callAsFunction(null, mode.name.toJS);
}

void previewBrowserThemeMode(ThemeMode mode) {
  _setBrowserThemeMode?.callAsFunction(null, mode.name.toJS, false.toJS);
}

void persistBrowserThemeMode(ThemeMode mode) {
  _persistBrowserThemeMode?.callAsFunction(null, mode.name.toJS);
}
