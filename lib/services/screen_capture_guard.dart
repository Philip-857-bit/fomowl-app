import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_security/screen_security.dart';

class ScreenCaptureGuard {
  ScreenCaptureGuard({ScreenSecurity? screenSecurity})
    : _screenSecurity = screenSecurity ?? ScreenSecurity();

  final ScreenSecurity _screenSecurity;

  /// Master switch for screenshot/screen-recording protection (FLAG_SECURE on
  /// Android, secure overlay on iOS).
  ///
  /// Temporarily set to `false` so the team can record tutorial videos of the
  /// app, including the otherwise-protected onboarding and backup screens.
  /// Restore to `true` to re-enable protection before shipping to production.
  static bool protectionEnabled = false;

  Future<void> enableProtection() async {
    if (!protectionEnabled) return;
    if (!_supportsProtection) return;
    try {
      await _screenSecurity.enable();
    } on MissingPluginException {
      // Best effort only on unsupported shells.
    } on PlatformException {
      // Best effort only on unsupported shells.
    }
  }

  Future<void> disableProtection() async {
    if (!_supportsProtection) return;
    try {
      await _screenSecurity.disable();
    } on MissingPluginException {
      // Best effort only on unsupported shells.
    } on PlatformException {
      // Best effort only on unsupported shells.
    }
  }

  bool get _supportsProtection {
    // The plugin only provides meaningful protection on mobile platforms.
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
