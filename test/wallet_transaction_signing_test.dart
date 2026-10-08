@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart';
import 'package:eth_sig_util/eth_sig_util.dart';

import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/secure_store.dart';
import 'package:fomowl_wallet/services/evm_transaction_service.dart';
import 'package:fomowl_wallet/services/token_approval_service.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/models/token.dart';
import 'package:fomowl_wallet/services/native_crypto.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/services/cow_limit_order_signing.dart';
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
  _Wallet(
    Web3Client client, {
    this.key = _key,
    this.address = _sender,
    super.typedDataSigner,
  }) : super(
         web3ClientFactory: (_) => client,
         storageService: StorageService(secureStore: _MemoryStore()),
       );

  final String? key;
  final String? address;

  @override
  Future<String?> getCurrentWalletAddress() async => address;

  @override
  Future<String?> getPrivateKey([String? address]) async => key;
}

class _Rpc {
  _Rpc(this.expectedData, {this.allowance = 0, this.baseFeeAvailable = true}) {
    client = Web3Client('https://rpc.invalid', MockClient(_handle));
  }

  final String expectedData;
  final int allowance;
  final bool baseFeeAvailable;
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
      case 'eth_getBlockByNumber':
        expect(params, ['latest', true]);
        result = {
          'timestamp': '0x0',
          if (baseFeeAvailable) 'baseFeePerGas': '0x3b9aca00',
        };
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
  String? toAddress = _contract,
  BigInt? maxFeePerGasWei,
  BigInt? maxPriorityFeePerGasWei,
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
        gasPrice: maxFeePerGasWei == null
            ? EtherAmount.inWei(BigInt.from(1000000000))
            : null,
        maxFeePerGas: maxFeePerGasWei == null
            ? null
            : EtherAmount.inWei(maxFeePerGasWei),
        maxPriorityFeePerGas: maxPriorityFeePerGasWei == null
            ? null
            : EtherAmount.inWei(maxPriorityFeePerGasWei),
        maxGas: gasLimit,
        to: toAddress == null ? null : EthereumAddress.fromHex(toAddress),
        value: EtherAmount.inWei(valueWei ?? BigInt.zero),
        data: Uint8List.fromList(HEX.decode(data.substring(2))),
      ),
      chainId: 1,
      fetchChainIdFromNetworkId: false,
    );
    return '0x${maxFeePerGasWei == null ? '' : '02'}${HEX.encode(bytes)}';
  } finally {
    await client.dispose();
  }
}

void main() {
  setUpAll(() async {
    await RustLib.init();
    WalletVaultService.unlock();
  });

  test('closed Rust account cannot sign or fetch a nonce', () async {
    final rpc = _Rpc('');
    addTearDown(rpc.client.dispose);
    final account = await _Wallet(rpc.client).getEvmSigningAccount();
    await account.close();
    await account.close();
    expect(account.isClosed, isTrue);
    await expectLater(
      EvmTransactionService.broadcastLegacy(
        client: rpc.client,
        account: account,
        chainId: 1,
        to: EthereumAddress.fromHex(_contract),
        valueWei: BigInt.zero,
        gasPriceWei: BigInt.one,
        gasLimit: 21000,
      ),
      throwsStateError,
    );
    expect(rpc.methods, isEmpty);
  });

  final cowOrder = buildCowOrderTypedData(
    chainId: 1,
    order: buildCowLimitOrderPayload(
      sellToken: _contract,
      buyToken: _recipient,
      receiver: _sender,
      sellAmount: '1000',
      buyAmount: '2000',
      validTo: 2000000000,
    ),
  );
  final cancellation = buildCowOrderCancellationTypedData(
    chainId: 1,
    orderUids: ['0x${'ab' * 56}', '0x${'cd' * 56}'],
  );
  final permit = {
    'types': {
      'EIP712Domain': [
        {'name': 'name', 'type': 'string'},
        {'name': 'chainId', 'type': 'uint256'},
        {'name': 'verifyingContract', 'type': 'address'},
      ],
      'TokenPermissions': [
        {'name': 'token', 'type': 'address'},
        {'name': 'amount', 'type': 'uint256'},
      ],
      'PermitTransferFrom': [
        {'name': 'permitted', 'type': 'TokenPermissions'},
        {'name': 'spender', 'type': 'address'},
        {'name': 'nonce', 'type': 'uint256'},
        {'name': 'deadline', 'type': 'uint256'},
      ],
    },
    'primaryType': 'PermitTransferFrom',
    'domain': {'name': 'Permit2', 'chainId': 1, 'verifyingContract': _contract},
    'message': {
      'permitted': {'token': _contract, 'amount': '1000'},
      'spender': _recipient,
      'nonce': '7',
      'deadline': '2000000000',
    },
  };

  for (final data in [cowOrder, cancellation, permit]) {
    test(
      'Rust EIP-712 matches legacy bytes for ${data['primaryType']}',
      () async {
        final json = jsonEncode(data);
        final reference = EthSigUtil.signTypedData(
          privateKey: _key,
          jsonData: json,
          version: TypedDataVersion.V4,
        );
        final signature = await NativeCrypto.signTypedData(
          privateKeyHex: _key,
          jsonData: json,
        );
        expect(signature, reference);
      },
    );
  }

  test(
    'typed-data signing fails closed when its Rust boundary fails',
    () async {
      final rpc = _Rpc('');
      addTearDown(rpc.client.dispose);
      var attempts = 0;
      final wallet = _Wallet(
        rpc.client,
        typedDataSigner: ({required account, required jsonData}) async {
          attempts++;
          throw StateError('Rust signer unavailable');
        },
      );
      await expectLater(
        wallet.signTypedData(jsonEncode(cowOrder)),
        throwsStateError,
      );
      expect(attempts, 1);
      expect(rpc.methods, isEmpty);
    },
  );

  for (final typed in [false, true]) {
    for (final creation in [false, true]) {
      test(
        'generic production request signs ${typed ? 'typed' : 'legacy'} ${creation ? 'creation' : 'call'}',
        () async {
          const data = '0x60006000';
          final rpc = _Rpc(data);
          addTearDown(rpc.client.dispose);
          final maxFee = typed ? BigInt.from(30000000000) : null;
          final priority = typed ? BigInt.from(1000000000) : null;
          final result = await _Wallet(rpc.client).sendRawTransactionRequest(
            rpcUrl: 'https://rpc.invalid',
            chainId: 1,
            toAddress: creation ? null : _contract,
            valueInWei: BigInt.zero,
            dataHex: data,
            gasLimit: 60000,
            nonce: 7,
            gasPriceWei: typed ? null : BigInt.from(1000000000),
            maxFeePerGasWei: maxFee,
            maxPriorityFeePerGasWei: priority,
          );
          expect(result, _hash);
          expect(
            rpc.rawTransaction,
            await _referenceTransaction(
              data,
              gasLimit: 60000,
              toAddress: creation ? null : _contract,
              maxFeePerGasWei: maxFee,
              maxPriorityFeePerGasWei: priority,
            ),
          );
          expect(rpc.methods, ['eth_sendRawTransaction']);
        },
      );
    }
  }

  test('generic request rejects mixed fee policies before RPC', () async {
    final rpc = _Rpc('');
    addTearDown(rpc.client.dispose);
    await expectLater(
      _Wallet(rpc.client).sendRawTransactionRequest(
        rpcUrl: 'https://rpc.invalid',
        chainId: 1,
        toAddress: _contract,
        gasPriceWei: BigInt.one,
        maxFeePerGasWei: BigInt.two,
      ),
      throwsArgumentError,
    );
    expect(rpc.methods, isEmpty);
  });

  for (final typed in [false, true]) {
    test(
      'generic request resolves ${typed ? 'EIP-1559' : 'legacy'} missing fees, gas and pending nonce',
      () async {
        const data = '0x60006000';
        final rpc = _Rpc(data);
        addTearDown(rpc.client.dispose);
        final priority = typed ? BigInt.from(1000000000) : null;
        final hash = await _Wallet(rpc.client).sendRawTransactionRequest(
          rpcUrl: 'https://rpc.invalid',
          chainId: 1,
          toAddress: _contract,
          dataHex: data,
          valueInWei: BigInt.zero,
          maxPriorityFeePerGasWei: priority,
        );
        expect(hash, _hash);
        expect(
          rpc.rawTransaction,
          await _referenceTransaction(
            data,
            gasLimit: 50000,
            maxFeePerGasWei: typed ? BigInt.from(3000000000) : null,
            maxPriorityFeePerGasWei: priority,
          ),
        );
        expect(rpc.methods, [
          typed ? 'eth_getBlockByNumber' : 'eth_gasPrice',
          'eth_getTransactionCount',
          'eth_estimateGas',
          'eth_sendRawTransaction',
        ]);
      },
    );
  }

  test('missing EIP-1559 base fee fails closed without broadcast', () async {
    final rpc = _Rpc('', baseFeeAvailable: false);
    addTearDown(rpc.client.dispose);
    await expectLater(
      _Wallet(rpc.client).sendRawTransactionRequest(
        rpcUrl: 'https://rpc.invalid',
        chainId: 1,
        toAddress: _contract,
        maxPriorityFeePerGasWei: BigInt.from(1000000000),
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('base fee'),
        ),
      ),
    );
    expect(rpc.methods, ['eth_getBlockByNumber']);
  });

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
      final account = await _Wallet(rpc.client).getEvmSigningAccount();
      addTearDown(account.close);
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

class _MemoryStore implements SecureStore {
  final _values = <String, String>{};
  @override
  Future<String?> read({required String key}) async => _values[key];
  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }
}
