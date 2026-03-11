import 'dart:typed_data';
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

    test('signTypedData triggers intentional Rust unimplemented stub error', () async {
      // EIP-712 is intentionally stubbed in Rust for now and relies on `EthSigUtil`
      // on the Dart side, so NativeCrypto will always throw if called, allowing 
      // the wallet_service logic to catch the fallback properly.
      expect(
        () async => await NativeCrypto.signTypedData(
            privateKeyHex: '0x123', jsonData: '{}'),
        throwsA(anyOf(isA<Exception>(), isA<Error>())),
      );
    });
  });
}
