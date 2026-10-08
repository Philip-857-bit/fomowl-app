@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/services/walletconnect/wallet_connect_policy.dart';
import 'package:fomowl_wallet/services/walletconnect/wallet_connect_solana_codec.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });
  group('WalletConnectSolanaCodec', () {
    test('returns the Reown signature and signed transaction fields', () {
      final signed = Uint8List.fromList([1, 2, 3]);
      expect(
        WalletConnectSolanaCodec.signedTransactionResult(
          signatureBase58: 'signature',
          signedTransaction: signed,
        ),
        {'signature': 'signature', 'transaction': base64Encode(signed)},
      );
    });

    test('signs the slot belonging to the connected signer', () async {
      final signer = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      final other = Uint8List.fromList(List<int>.filled(32, 9));
      final message = Uint8List.fromList([
        2,
        0,
        0,
        2,
        ...signer,
        ...other,
        ...List<int>.filled(32, 7),
        0,
      ]);
      final transaction = Uint8List.fromList([
        2,
        ...List<int>.filled(128, 0),
        ...message,
      ]);
      final signature = Uint8List.fromList(List<int>.filled(64, 3));

      final signed = await WalletConnectSolanaCodec.attachSignature(
        transactionBytes: transaction,
        signerAddress: WalletService.encodeBase58Bytes(signer),
        signature: signature,
      );

      expect(signed.sublist(1, 65), signature);
      expect(signed.sublist(65, 129), List<int>.filled(64, 0));
      expect(await WalletConnectSolanaCodec.messageBytes(signed), message);
    });

    test(
      'rejects a transaction that does not include the connected signer',
      () async {
        final signer = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
        final other = Uint8List.fromList(List<int>.filled(32, 9));
        final transaction = Uint8List.fromList([
          1,
          ...List<int>.filled(64, 0),
          1,
          0,
          0,
          1,
          ...other,
          ...List<int>.filled(32, 7),
          0,
        ]);

        await expectLater(
          WalletConnectSolanaCodec.attachSignature(
            transactionBytes: transaction,
            signerAddress: WalletService.encodeBase58Bytes(signer),
            signature: Uint8List.fromList(List<int>.filled(64, 3)),
          ),
          throwsA(
            isA<WalletConnectPolicyException>().having(
              (error) => error.code,
              'code',
              4100,
            ),
          ),
        );
      },
    );
  });
}
