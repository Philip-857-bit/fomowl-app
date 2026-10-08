import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/native_crypto.dart';

void main() {
  group('NativeCrypto FFI Wrapper', () {
    test(
      'generateMnemonic fails closed when Rust FFI is unavailable',
      () async {
        await expectLater(
          NativeCrypto.generateMnemonic().then((_) => true),
          throwsA(anything),
        );
      },
    );

    test('mnemonicToSeed fails closed when Rust FFI is unavailable', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

      await expectLater(
        NativeCrypto.mnemonicToSeed(mnemonic).then((_) => true),
        throwsA(anything),
      );
    });

    test('validateMnemonic fails closed when Rust FFI is unavailable', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      await expectLater(
        NativeCrypto.validateMnemonic(mnemonic).then((_) => true),
        throwsA(anything),
      );
    });

    test('signTypedData surfaces FFI absence in Dart-only tests', () async {
      // This test deliberately does not initialize RustLib. A missing engine
      // must never silently select a different cryptographic implementation.
      expect(
        () async => await NativeCrypto.signTypedData(
          privateKeyHex: '0x123',
          jsonData: '{}',
        ),
        throwsA(anyOf(isA<Exception>(), isA<Error>())),
      );
    });
  });
}
