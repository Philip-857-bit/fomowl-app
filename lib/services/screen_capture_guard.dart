import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenCaptureGuard {
  ScreenCaptureGuard({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('owllet/screen_security');

  final MethodChannel _channel;

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
      await _channel.invokeMethod('enable');
    } on MissingPluginException {
      // Best effort only on unsupported shells.
    } on PlatformException {
      // Best effort only on unsupported shells.
    }
  }

  Future<void> disableProtection() async {
    if (!_supportsProtection) return;
    try {
      await _channel.invokeMethod('disable');
    } on MissingPluginException {
      // Best effort only on unsupported shells.
    } on PlatformException {
      // Best effort only on unsupported shells.
    }
  }

  bool get _supportsProtection {
    // Meaningful protection only on mobile platforms.
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
