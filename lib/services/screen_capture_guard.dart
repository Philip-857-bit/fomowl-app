import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_security/screen_security.dart';

class ScreenCaptureGuard {
  ScreenCaptureGuard({ScreenSecurity? screenSecurity})
    : _screenSecurity = screenSecurity ?? ScreenSecurity();

  final ScreenSecurity _screenSecurity;

  Future<void> enableProtection() async {
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
