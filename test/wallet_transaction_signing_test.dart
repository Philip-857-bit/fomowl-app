@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart';

import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/services/evm_transaction_service.dart';
import 'package:fomowl_wallet/services/token_approval_service.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';

const _key = '1ab42cc412b618bdea3a599e3c9bae199ebf030895b039e9db1e30dafb12b727';
const _sender = '0x9858EfFD232B4033E47d90003D41EC34EcaEda94';
const _recipient = '0x3535353535353535353535353535353535353535';
const _contract = '0x1111111111111111111111111111111111111111';
const _hash =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _senderWord =
    '0000000000000000000000009858effd232b4033e47d90003d41ec34ecaeda94';
const _recipientWord =
    '0000000000000000000000003535353535353535353535353535353535353535';
const _idWord =
    '000000000000000000000000000000000000000000000000000000000000002a';

class _Wallet extends WalletService {
  _Wallet(Web3Client client, {this.key = _key, this.address = _sender})
    : super(web3ClientFactory: (_) => client);

  final String? key;
  final String? address;

  @override
  Future<String?> getCurrentWalletAddress() async => address;

  @override
  Future<String?> getPrivateKey([String? address]) async => key;

  @override
  Future<EthPrivateKey> getCredentials() =>
      throw StateError('Migrated transactions must not use Dart credentials');
}

class _Rpc {
  _Rpc(this.expectedData, {this.allowance = 0}) {
    client = Web3Client('https://rpc.invalid', MockClient(_handle));
  }

  final String expectedData;
  final int allowance;
  final List<String> methods = [];
  String? rawTransaction;
  late final Web3Client client;

  Future<http.Response> _handle(http.Request request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final method = body['method'] as String;
    final params = body['params'] as List<dynamic>;
    methods.add(method);
    final Object result;
    switch (method) {
      case 'eth_call':
        final tx = params.first as Map<String, dynamic>;
        expect((tx['to'] as String).toLowerCase(), _contract);
        expect(tx['data'], '0xdd62ed3e$_senderWord$_recipientWord');
        result = '0x${allowance.toRadixString(16).padLeft(64, '0')}';
      case 'eth_gasPrice':
        result = '0x3b9aca00';
      case 'eth_estimateGas':
        final tx = params.first as Map<String, dynamic>;
        expect((tx['from'] as String).toLowerCase(), _sender.toLowerCase());
        expect((tx['to'] as String).toLowerCase(), _contract);
        expect(tx['data'], expectedData);
        result = '0xc350'; // 50,000 gas before the existing 15% NFT buffer.
      case 'eth_getTransactionCount':
        expect((params[0] as String).toLowerCase(), _sender.toLowerCase());
        expect(params[1], 'pending');
        result = '0x7';
      case 'eth_sendRawTransaction':
        rawTransaction = params.single as String;
        result = _hash;
      default:
        throw StateError('Unexpected RPC method: $method');
    }
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

Future<String> _referenceTransaction(
  String data, {
  int gasLimit = 57500,
  BigInt? valueWei,
}) async {
  final client = Web3Client(
    'https://rpc.invalid',
    MockClient((_) => throw StateError('Reference signing must stay offline')),
  );
  try {
    final bytes = await client.signTransaction(
      EthPrivateKey.fromHex(_key),
      Transaction(
        nonce: 7,
        gasPrice: EtherAmount.inWei(BigInt.from(1000000000)),
        maxGas: gasLimit,
        to: EthereumAddress.fromHex(_contract),
        value: EtherAmount.inWei(valueWei ?? BigInt.zero),
        data: Uint8List.fromList(HEX.decode(data.substring(2))),
      ),
      chainId: 1,
      fetchChainIdFromNetworkId: false,
    );
    return '0x${HEX.encode(bytes)}';
  } finally {
    await client.dispose();
  }
}

void main() {
  setUpAll(() async => RustLib.init());

  const token = Token(
    symbol: 'TST',
    name: 'Test token',
    contractAddress: _contract,
    balance: 1,
    valueUsd: 1,
    changePercent24h: 0,
  );

  for (final allowance in [0, 1000]) {
    test(
      'approval preserves exact amount and skips signing when allowance=$allowance',
      () async {
        const data =
            '0x095ea7b3$_recipientWord'
            '00000000000000000000000000000000000000000000000000000000000003e8';
        final rpc = _Rpc(data, allowance: allowance);
        addTearDown(rpc.client.dispose);
        final blockchain = BlockchainService();
        addTearDown(blockchain.dispose);
        var callbacks = 0;
        final result =
            await TokenApprovalService(
              walletService: _Wallet(rpc.client),
              web3ClientFactory: (_) => rpc.client,
            ).ensureApproval(
              token: token,
              amountWei: '1000',
              ownerAddress: _sender,
              blockchain: blockchain,
              allowanceTarget: _recipient,
              onApprovalNeeded: () => callbacks++,
            );
        expect(result.error, isNull);
        expect(result.approvalSatisfied, isTrue);
        expect(result.approvalSubmitted, allowance == 0);
        expect(callbacks, allowance == 0 ? 1 : 0);
        if (allowance == 0) {
          expect(result.transactionHash, _hash);
          expect(
            rpc.rawTransaction,
            await _referenceTransaction(data, gasLimit: 50000),
          );
          expect(rpc.methods, [
            'eth_call',
            'eth_gasPrice',
            'eth_getTransactionCount',
            'eth_estimateGas',
            'eth_sendRawTransaction',
          ]);
        } else {
          expect(result.transactionHash, isNull);
          expect(rpc.rawTransaction, isNull);
          expect(rpc.methods, ['eth_call']);
        }
      },
    );
  }

  test('approval refuses a key that does not belong to its owner', () async {
    final rpc = _Rpc('');
    addTearDown(rpc.client.dispose);
    final blockchain = BlockchainService();
    addTearDown(blockchain.dispose);
    final result =
        await TokenApprovalService(
          walletService: _Wallet(rpc.client, key: '46' * 32),
          web3ClientFactory: (_) => rpc.client,
        ).ensureApproval(
          token: token,
          amountWei: '1000',
          ownerAddress: _sender,
          blockchain: blockchain,
          allowanceTarget: _recipient,
        );
    expect(result.approvalSatisfied, isFalse);
    expect(result.error, contains('does not match the selected wallet'));
    expect(rpc.methods, ['eth_call']);
  });

  for (final isNative in [true, false]) {
    test(
      'production ${isNative ? 'native' : 'token'} transfer preserves supplied fees',
      () async {
        final data = isNative
            ? '0x'
            : '0xa9059cbb$_recipientWord'
                  '00000000000000000000000000000000000000000000000000000000000003e8';
        final rpc = _Rpc(data);
        addTearDown(rpc.client.dispose);
        final wallet = _Wallet(rpc.client);
        final amount = BigInt.from(isNative ? 10 : 1000);
        final hash = isNative
            ? await wallet.sendNativeTransaction(
                toAddress: _contract,
                amountInBaseUnits: amount,
                rpcUrl: 'https://rpc.invalid',
                chainId: 1,
                gasPriceWei: BigInt.from(1000000000),
                gasLimit: 75000,
              )
            : await wallet.sendTokenTransaction(
                tokenAddress: _contract,
                toAddress: _recipient,
                amountInBaseUnits: amount,
                rpcUrl: 'https://rpc.invalid',
                chainId: 1,
                gasPriceWei: BigInt.from(1000000000),
                gasLimit: 75000,
              );
        expect(hash, _hash);
        expect(
          rpc.rawTransaction,
          await _referenceTransaction(
            data,
            gasLimit: 75000,
            valueWei: isNative ? amount : BigInt.zero,
          ),
        );
        expect(rpc.methods, [
          'eth_getTransactionCount',
          'eth_sendRawTransaction',
        ]);
      },
    );
  }

  test(
    'shared adapter rejects invalid fields before RPC and redacts its account',
    () async {
      final rpc = _Rpc('');
      addTearDown(rpc.client.dispose);
      final account = await EvmTransactionService.verifyAccount(
        sender: EthereumAddress.fromHex(_sender),
        privateKeyHex: _key,
      );
      expect(account.toString(), isNot(contains(_key)));
      await expectLater(
        EvmTransactionService.broadcastLegacy(
          client: rpc.client,
          account: account,
          chainId: 0,
          to: EthereumAddress.fromHex(_contract),
          valueWei: BigInt.zero,
          gasPriceWei: BigInt.one,
          gasLimit: 21000,
        ),
        throwsArgumentError,
      );
      expect(rpc.methods, isEmpty);
    },
  );

  for (final tokenType in ['ERC721', 'ERC1155']) {
    test('$tokenType production transfer signs canonical bytes in Rust', () async {
      final expectedData = tokenType == 'ERC721'
          ? '0x42842e0e$_senderWord$_recipientWord$_idWord'
          : '0xf242432a$_senderWord$_recipientWord$_idWord'
                '0000000000000000000000000000000000000000000000000000000000000003'
                '00000000000000000000000000000000000000000000000000000000000000a0'
                '0000000000000000000000000000000000000000000000000000000000000000';
      final rpc = _Rpc(expectedData);
      addTearDown(rpc.client.dispose);
      final hash = await _Wallet(rpc.client).sendNftTransaction(
        contractAddress: _contract,
        fromAddress: _sender,
        toAddress: _recipient,
        tokenId: BigInt.from(42),
        tokenType: tokenType,
        amount: BigInt.from(3),
        rpcUrl: 'https://rpc.invalid',
        chainId: 1,
      );
      expect(hash, _hash);
      expect(rpc.rawTransaction, await _referenceTransaction(expectedData));
      expect(rpc.methods, [
        'eth_gasPrice',
        'eth_estimateGas',
        'eth_getTransactionCount',
        'eth_sendRawTransaction',
      ]);
    });
  }

  test('NFT key/address mismatch fails before RPC', () async {
    final rpc = _Rpc('');
    addTearDown(rpc.client.dispose);
    await expectLater(
      _Wallet(rpc.client, key: '46' * 32).sendNftTransaction(
        contractAddress: _contract,
        fromAddress: _sender,
        toAddress: _recipient,
        tokenId: BigInt.one,
        tokenType: 'ERC721',
        amount: BigInt.one,
        rpcUrl: 'https://rpc.invalid',
        chainId: 1,
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('does not match private key'),
        ),
      ),
    );
    expect(rpc.methods, isEmpty);
  });

  for (final activeAddress in <String?>[_recipient, null]) {
    test(
      'NFT rejects unavailable or different active sender ($activeAddress)',
      () async {
        final rpc = _Rpc('');
        addTearDown(rpc.client.dispose);
        await expectLater(
          _Wallet(rpc.client, address: activeAddress).sendNftTransaction(
            contractAddress: _contract,
            fromAddress: _sender,
            toAddress: _recipient,
            tokenId: BigInt.one,
            tokenType: 'ERC721',
            amount: BigInt.one,
            rpcUrl: 'https://rpc.invalid',
            chainId: 1,
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains(
                activeAddress == null
                    ? 'No wallet found'
                    : 'Transaction sender does not match',
              ),
            ),
          ),
        );
        expect(rpc.methods, isEmpty);
      },
    );
  }
}
