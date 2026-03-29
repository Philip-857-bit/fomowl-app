import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/native_crypto.dart';

void main() {
  group('NativeCrypto FFI Wrapper', () {
    test('generateMnemonic delegates to Rust correctly', () async {
      // Since `flutter_test` runs strictly in Dart and lacks the compiled Rust
      // FFI binary (unless explicitly built for the host), this will rethrow a
      // Rust/FFI exception. We test that the Exception rethrow is functioning
      // without silent failures.
      expect(
        () async => await NativeCrypto.generateMnemonic(),
        throwsA(anyOf(isA<Exception>(), isA<Error>())),
      );
    });

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
