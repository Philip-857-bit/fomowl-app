/// Process-local host admission supplied by the runtime/provider coordinator.
/// It starts disabled and contains no network or cryptographic implementation.
class BitcoinHostAvailability {
  static bool _mainnet = false;
  static bool get mainnet => _mainnet;
  static void configure({required bool mainnet}) {
    _mainnet = mainnet;
  }
}
