import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// Available app wallet theme modes corresponding to Figma #318:2526 and #318:2332.
enum AppThemeMode {
  /// Classic FOMOwl Signature Red/Dark Theme across all networks.
  classic,

  /// Dynamic chain-adaptive theme tailored to the active blockchain.
  adaptive;

  static AppThemeMode fromString(String? value) {
    if (value == 'classic') return AppThemeMode.classic;
    return AppThemeMode.adaptive;
  }
}

/// Controller responsible for managing global wallet theme state (Classic vs. Adaptive).
class ThemeController extends ChangeNotifier {
  ThemeController({StorageService? storage})
    : _storage = storage ?? StorageService();

  final StorageService _storage;
  AppThemeMode _themeMode = AppThemeMode.adaptive;
  bool _initialized = false;

  AppThemeMode get themeMode => _themeMode;
  bool get isAdaptive => _themeMode == AppThemeMode.adaptive;
  bool get isClassic => _themeMode == AppThemeMode.classic;
  bool get initialized => _initialized;

  Future<void> init() async {
    final stored = await _storage.getThemeMode();
    if (stored != null) {
      _themeMode = AppThemeMode.fromString(stored);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.setThemeMode(mode.name);
  }

  Future<void> toggleThemeMode() async {
    final next = isAdaptive ? AppThemeMode.classic : AppThemeMode.adaptive;
    await setThemeMode(next);
  }
}
