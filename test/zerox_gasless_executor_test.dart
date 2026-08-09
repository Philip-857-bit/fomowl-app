import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/zerox_gasless_executor.dart';

void main() {
  test('splitSignature returns 0x gasless v2 signature fields', () {
    final r = List<String>.filled(32, '11').join();
    final s = List<String>.filled(32, '22').join();
    final signature = '0x$r${s}1b';

    final result = ZeroXGaslessExecutor.splitSignature(signature);

    expect(result, <String, dynamic>{
      'r': '0x$r',
      's': '0x$s',
      'v': 27,
      'signatureType': 2,
    });
  });

  test('splitSignature rejects signatures that are not 65 bytes', () {
    expect(
      () => ZeroXGaslessExecutor.splitSignature('0x1234'),
      throwsFormatException,
    );
  });
}
