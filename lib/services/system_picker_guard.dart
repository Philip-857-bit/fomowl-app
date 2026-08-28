/// Briefly suppresses the app's lock-on-background while a system camera or
/// file picker launched from inside an in-app WebView (e.g. the OwlletPay KYC
/// selfie/document capture) is in flight.
///
/// Without this, the camera/permission flow backgrounds the Flutter activity,
/// which trips the lock-on-background guard in `OwlletApp`. The unlock screen
/// then covers the WebView and, on memory-constrained devices, the capture in
/// progress is wiped — so the photo never lands back in the KYC screen. Arming
/// the guard right before the picker opens tells the lock guard this
/// backgrounding was expected and user-initiated.
class SystemPickerGuard {
  SystemPickerGuard._();

  static DateTime? _armedAt;

  /// Longest an armed guard is trusted. Generous enough for a user to frame and
  /// take a photo, short enough that a stale flag can never disable the lock
  /// indefinitely.
  static const Duration _window = Duration(minutes: 3);

  /// Mark that a system picker/permission flow is about to open.
  static void arm() {
    _armedAt = DateTime.now();
  }

  /// True while a recently-armed picker window is still open.
  static bool get isActive {
    final armedAt = _armedAt;
    if (armedAt == null) {
      return false;
    }
    return DateTime.now().difference(armedAt) <= _window;
  }

  /// Clear the guard (e.g. when the host screen that armed it is disposed).
  static void clear() {
    _armedAt = null;
  }
}
