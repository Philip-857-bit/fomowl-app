import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/services/walletconnect/wallet_connect_policy.dart';
import 'package:fomowl_wallet/services/walletconnect/wallet_connect_solana_codec.dart';
import 'package:reown_walletkit/reown_walletkit.dart';

void main() {
  group('WalletConnectPolicy', () {
    const address = '0x1111111111111111111111111111111111111111';
    final namespaces = <String, Namespace>{
      'eip155': const Namespace(
        chains: ['eip155:1'],
        accounts: ['eip155:1:$address'],
        methods: ['personal_sign', 'eth_sendTransaction'],
        events: ['accountsChanged'],
      ),
    };

    test('accepts an approved chain and method', () {
      expect(
        () => WalletConnectPolicy.validateSessionRequest(
          namespaces: namespaces,
          chainId: 'eip155:1',
          method: 'personal_sign',
        ),
        returnsNormally,
      );
    });

    test('rejects a method that the session did not approve', () {
      expect(
        () => WalletConnectPolicy.validateSessionRequest(
          namespaces: namespaces,
          chainId: 'eip155:1',
          method: 'eth_signTypedData_v4',
        ),
        throwsA(
          isA<WalletConnectPolicyException>().having(
            (error) => error.code,
            'code',
            4200,
          ),
        ),
      );
    });

    test('rejects a chain that the session did not approve', () {
      expect(
        () => WalletConnectPolicy.validateSessionRequest(
          namespaces: namespaces,
          chainId: 'eip155:56',
          method: 'personal_sign',
        ),
        throwsA(isA<WalletConnectPolicyException>()),
      );
    });

    test('personal_sign requires the connected account in either position', () {
      expect(
        WalletConnectPolicy.extractEvmSigningPayload(
          method: 'personal_sign',
          params: ['0x68656c6c6f', address],
          approvedAddress: address,
        ),
        '0x68656c6c6f',
      );
      expect(
        () => WalletConnectPolicy.extractEvmSigningPayload(
          method: 'personal_sign',
          params: [
            '0x68656c6c6f',
            '0x2222222222222222222222222222222222222222',
          ],
          approvedAddress: address,
        ),
        throwsA(isA<WalletConnectPolicyException>()),
      );
    });

    test('extracts unique chains from CAIP-10 accounts', () {
      expect(
        WalletConnectPolicy.chainsFromAccounts([
          'eip155:1:$address',
          'eip155:56:$address',
          '${WalletConnectPolicy.tronMainnetChain}:TExample',
        ]),
        {'eip155:1', 'eip155:56', WalletConnectPolicy.tronMainnetChain},
      );
    });

    test('pairing logs never contain the topic or symmetric key', () {
      final uri = Uri.parse('wc:topic@2?symKey=secret&relay-protocol=irn');
      final logValue = WalletConnectPolicy.redactedPairingLog(uri);
      expect(logValue, 'wc:<redacted>');
      expect(logValue, isNot(contains('topic')));
      expect(logValue, isNot(contains('secret')));
    });

    test('TRON personal messages use the canonical prefixed Keccak digest', () {
      expect(
        WalletService.tronPersonalMessageDigest(
          'hello',
        ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        'a07d8e5b946cc0416662f5420751673680809e5f10313e20c7c5badb0ef4226d',
      );
    });

    test('negotiates TRON v1 session payloads without dropping properties', () {
      expect(
        WalletConnectPolicy.approvedSessionProperties(
          requested: const {'client': 'test'},
          namespaceKeys: const ['tron'],
        ),
        const {'client': 'test', 'tron_method_version': 'v1'},
      );
      expect(WalletConnectPolicy.tronMethods, isNot(contains('tron_sign')));
    });

    test('unwraps both current and legacy TRON transaction payloads', () {
      const transaction = {'raw_data_hex': 'aabb'};
      expect(
        WalletConnectPolicy.tronTransaction({
          'address': 'TAddress',
          'transaction': transaction,
        }),
        transaction,
      );
      expect(
        WalletConnectPolicy.tronTransaction({
          'address': 'TAddress',
          'transaction': {'transaction': transaction},
        }),
        transaction,
      );
    });
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

    test('signs the slot belonging to the connected signer', () {
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

      final signed = WalletConnectSolanaCodec.attachSignature(
        transactionBytes: transaction,
        signerAddress: WalletService.encodeBase58Bytes(signer),
        signature: signature,
      );

      expect(signed.sublist(1, 65), signature);
      expect(signed.sublist(65, 129), List<int>.filled(64, 0));
      expect(WalletConnectSolanaCodec.messageBytes(signed), message);
    });

    test(
      'rejects a transaction that does not include the connected signer',
      () {
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

        expect(
          () => WalletConnectSolanaCodec.attachSignature(
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
