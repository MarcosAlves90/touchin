import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'theme_surface_sync_stub.dart'
    if (dart.library.js_interop) 'theme_surface_sync_web.dart' as theme_surface;

abstract class ThemePreferenceStore {
  Future<String?> readThemeMode();

  Future<void> writeThemeMode(ThemeMode mode);
}

class SecureThemePreferenceStore implements ThemePreferenceStore {
  SecureThemePreferenceStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _themeModeKey = 'theme_mode';
  final FlutterSecureStorage _secureStorage;

  @override
  Future<String?> readThemeMode() {
    return _secureStorage.read(key: _themeModeKey);
  }

  @override
  Future<void> writeThemeMode(ThemeMode mode) {
    return _secureStorage.write(key: _themeModeKey, value: _encode(mode));
  }

  static String _encode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}

class ThemeModeController extends ChangeNotifier {
  ThemeModeController({ThemePreferenceStore? store})
      : _store = store ?? SecureThemePreferenceStore();

  static final ThemeModeController instance = ThemeModeController();

  final ThemePreferenceStore _store;
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode _persistedMode = ThemeMode.dark;
  Future<void> _pendingWrites = Future<void>.value();
  int _selectionVersion = 0;
  bool _hasPersistenceError = false;
  bool _isLoaded = false;

  ThemeMode get mode => _mode;
  bool get hasPersistenceError => _hasPersistenceError;

  bool get prefersLightTheme => _mode == ThemeMode.light;

  Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    try {
      _mode = _decode(await _store.readThemeMode());
      _persistedMode = _mode;
      theme_surface.syncBrowserThemeMode(_mode);
    } catch (_) {
      _hasPersistenceError = true;
      _mode = ThemeMode.dark;
      theme_surface.previewBrowserThemeMode(_mode);
      debugPrint('TouchIn: theme preference could not be read; using default.');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_mode == mode) {
      return;
    }

    _mode = mode;
    final selectionVersion = ++_selectionVersion;
    _hasPersistenceError = false;
    theme_surface.previewBrowserThemeMode(mode);
    notifyListeners();
    _isLoaded = true;
    // Keep the UI responsive, but persist the first-paint hint only after
    // secure storage confirms the write. Serialized writes preserve order
    // when users quickly switch between themes.
    final write = _pendingWrites.then((_) async {
      try {
        await _store.writeThemeMode(mode);
        _persistedMode = mode;
        theme_surface.persistBrowserThemeMode(mode);
        _hasPersistenceError = false;
      } catch (_) {
        _hasPersistenceError = true;
        debugPrint('TouchIn: theme preference could not be saved.');
        if (_selectionVersion == selectionVersion) {
          _mode = _persistedMode;
          theme_surface.previewBrowserThemeMode(_mode);
        }
        notifyListeners();
      }
    });
    _pendingWrites = write;
    await write;
  }

  Future<void> setUseLightTheme(bool enabled) {
    return setThemeMode(enabled ? ThemeMode.light : ThemeMode.system);
  }

  static ThemeMode _decode(String? rawMode) {
    return switch (rawMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }
}
