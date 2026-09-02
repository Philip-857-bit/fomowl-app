import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/native_crypto.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';

void main() {
  setUpAll(() async {
    try {
      await RustLib.init();
    } catch (e) {
      // Ignore if already initialized
    }
  });

  group('NativeCrypto FFI Wrapper', () {
    test(
      'generateMnemonic falls back to Dart when Rust FFI is unavailable',
      () async {
        final mnemonic = await NativeCrypto.generateMnemonic();

        expect(await NativeCrypto.validateMnemonic(mnemonic), isTrue);
      },
    );

    test(
      'mnemonicToSeed falls back to Dart when Rust FFI is unavailable',
      () async {
        const mnemonic =
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

        final seed = await NativeCrypto.mnemonicToSeed(mnemonic);

        expect(seed.length, 64);
      },
    );

    test('signTypedData surfaces FFI absence in Dart-only tests', () async {
      // flutter_test runs without the compiled host Rust binary here, so the
      // FFI call still throws even though the Rust implementation exists.
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
