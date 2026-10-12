@Tags(['ffi'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart' as crypto;
import 'package:fomowl_wallet/models/evm_outbound_transaction.dart';
import 'package:fomowl_wallet/models/evm_fee_quote.dart';
import 'package:fomowl_wallet/services/evm_outbound_store.dart';
import 'package:fomowl_wallet/services/evm_replacement_service.dart';
import 'package:fomowl_wallet/services/evm_transaction_service.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';
import 'helpers/bitcoin_memory_store.dart';

// Public BIP-39 test-vector key; offline fixtures only.
const key = '1ab42cc412b618bdea3a599e3c9bae199ebf030895b039e9db1e30dafb12b727';
const sender = '0x9858effd232b4033e47d90003d41ec34ecaeda94';
const recipient = '0x3535353535353535353535353535353535353535';
String quantity(BigInt value) => '0x${value.toRadixString(16)}';
String txHash(String raw) =>
    '0x${HEX.encode(crypto.keccak256(crypto.hexToBytes(raw)))}';
Future<String> reference(EvmTransactionFields fields) async {
  final client = Web3Client(
    'https://rpc.invalid',
    MockClient((_) async => throw StateError('Offline reference')),
  );
  try {
    final bytes = await client.signTransaction(
      EthPrivateKey.fromHex(key),
      Transaction(
        nonce: fields.nonce,
        to: EthereumAddress.fromHex(fields.destination),
        value: EtherAmount.inWei(fields.valueWei),
        data: Uint8List.fromList(HEX.decode(fields.dataHex.substring(2))),
        maxGas: fields.gasLimit,
        gasPrice: fields.gasPriceWei == null
            ? null
            : EtherAmount.inWei(fields.gasPriceWei!),
        maxFeePerGas: fields.maxFeePerGasWei == null
            ? null
            : EtherAmount.inWei(fields.maxFeePerGasWei!),
        maxPriorityFeePerGas: fields.maxPriorityFeePerGasWei == null
            ? null
            : EtherAmount.inWei(fields.maxPriorityFeePerGasWei!),
      ),
      chainId: fields.chainId,
      fetchChainIdFromNetworkId: false,
    );
    return '0x${fields.type == EvmTransactionType.dynamicFee ? '02' : ''}${HEX.encode(bytes)}';
  } finally {
    await client.dispose();
  }
}

Map<String, dynamic> pending(EvmOutboundTransaction entry) => {
  'hash': entry.hash,
  'from': entry.fields.sender,
  'to': entry.fields.destination,
  'nonce': quantity(BigInt.from(entry.fields.nonce)),
  'gas': quantity(BigInt.from(entry.fields.gasLimit)),
  'value': quantity(entry.fields.valueWei),
  'input': entry.fields.dataHex,
  'type': entry.fields.type == EvmTransactionType.dynamicFee ? '0x2' : '0x0',
  'chainId': quantity(BigInt.from(entry.fields.chainId)),
  'blockNumber': null,
  'blockHash': null,
  if (entry.fields.gasPriceWei != null)
    'gasPrice': quantity(entry.fields.gasPriceWei!),
  if (entry.fields.maxFeePerGasWei != null)
    'maxFeePerGas': quantity(entry.fields.maxFeePerGasWei!),
  if (entry.fields.maxPriorityFeePerGasWei != null)
    'maxPriorityFeePerGas': quantity(entry.fields.maxPriorityFeePerGasWei!),
};

class FixtureWallet extends WalletService {
  FixtureWallet(MemoryStore store)
    : super(storageService: StorageService(secureStore: store));
  @override
  Future<String?> getCurrentWalletAddress() async => sender;
  @override
  Future<String?> getPrivateKey([String? address]) async => key;
}

class Rpc {
  late final Web3Client client = Web3Client(
    'https://rpc.invalid',
    MockClient(call),
  );
  final transactions = <String, Map<String, dynamic>>{};
  final methods = <String>[];
  bool dynamicFees = true;
  int chainId = 1;
  int confirmedNonce = 7;
  Object? receipt;
  String code = '0x';
  BigInt balance = BigInt.from(10).pow(20);
  int gas = 50000;
  int blockGasLimit = 30000000;
  bool timeoutSend = false;
  bool wrongHash = false;
  String? raw;
  Future<http.Response> call(http.Request request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final method = body['method'] as String;
    final args = body['params'] as List;
    methods.add(method);
    final Object? result;
    switch (method) {
      case 'eth_chainId':
        result = quantity(BigInt.from(chainId));
      case 'eth_getTransactionReceipt':
        result = receipt;
      case 'eth_getTransactionByHash':
        result = transactions[args.single];
      case 'eth_getTransactionCount':
        expect(args[1], 'latest');
        result = quantity(BigInt.from(confirmedNonce));
      case 'eth_getCode':
        result = code;
      case 'eth_getBalance':
        result = quantity(balance);
      case 'eth_getBlockByNumber':
        result = {
          'number': '0x100',
          'gasLimit': quantity(BigInt.from(blockGasLimit)),
          if (dynamicFees) 'baseFeePerGas': '0x3b9aca00',
        };
      case 'eth_gasPrice':
        result = '0x3b9aca00';
      case 'eth_estimateGas':
        final tx = args.first as Map<String, dynamic>;
        result = quantity(BigInt.from(tx['to'] == sender ? 21000 : gas));
      case 'eth_feeHistory':
        result = {
          'oldestBlock': '0xfe',
          'baseFeePerGas': List.filled(3, dynamicFees ? '0x3b9aca00' : '0x0'),
          'reward': List.generate(
            2,
            (_) => ['0x3b9aca00', '0x77359400', '0xb2d05e00'],
          ),
        };
      case 'eth_sendRawTransaction':
        raw = args.single as String;
        if (timeoutSend) {
          throw TimeoutException('fixture-sensitive-provider-context');
        }
        result = wrongHash ? '0x${'aa' * 32}' : txHash(raw!);
      default:
        throw StateError('Unexpected method $method');
    }
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class Fixture {
  final memory = MemoryStore();
  final rpc = Rpc();
  late final journal = EvmOutboundStore(memory);
  late final wallet = FixtureWallet(memory);
  late final service = EvmReplacementService(
    journal: journal,
    client: rpc.client,
    currentSender: () async => activeSender,
    openSigner: () async {
      opens++;
      signer = await wallet.getEvmSigningAccount();
      afterOpen?.call();
      return signer!;
    },
    now: () => clock,
  );
  String activeSender = sender;
  DateTime clock = DateTime.utc(2026, 10, 12);
  int opens = 0;
  void Function()? afterOpen;
  EvmSigningAccount? signer;
  late EvmOutboundTransaction original;
  late EvmOutboundReservation reservation;
  Future<void> init({
    bool typed = true,
    String data = '0x',
    int gasLimit = 75000,
  }) async {
    rpc.dynamicFees = typed;
    final fields = EvmTransactionFields(
      chainId: 1,
      sender: sender,
      nonce: 7,
      destination: recipient,
      valueWei: BigInt.from(1000),
      dataHex: data,
      gasLimit: gasLimit,
      gasPriceWei: typed ? null : BigInt.from(1000000000),
      maxFeePerGasWei: typed ? BigInt.from(3000000000) : null,
      maxPriorityFeePerGasWei: typed ? BigInt.from(1000000000) : null,
    );
    original = EvmOutboundTransaction(
      fields: fields,
      hash: txHash(await reference(fields)),
      state: EvmOutboundState.unknown,
      createdAt: clock,
    );
    reservation = await journal.reserve(original);
    journal.beginProviderSend(reservation);
    await journal.submitted(reservation, original.hash);
    rpc.transactions[original.hash] = pending(original);
  }

  Future<EvmPreparedReplacement> prepare([
    EvmReplacementKind kind = EvmReplacementKind.speedUp,
  ]) => service.prepare(sender, 1, original.hash, kind, isCurrent: () => true);
}

void main() {
  setUpAll(() async => RustLib.init());
  setUp(WalletVaultService.unlock);
  for (final typed in [true, false]) {
    for (final kind in EvmReplacementKind.values) {
      test(
        '${typed ? 'type-2' : 'legacy'} ${kind.name} preserves nonce and signs exact approved fields',
        () async {
          final f = Fixture();
          addTearDown(f.rpc.client.dispose);
          await f.init(typed: typed, data: '0x010203');
          final prepared = await f.prepare(kind);
          expect(prepared.fields.nonce, 7);
          expect(prepared.fields.chainId, 1);
          expect(prepared.fields.sender, sender);
          expect(prepared.fields.type, f.original.fields.type);
          if (kind == EvmReplacementKind.speedUp) {
            expect(prepared.fields.destination, recipient);
            expect(prepared.fields.valueWei, BigInt.from(1000));
            expect(prepared.fields.dataHex, '0x010203');
            expect(prepared.fields.gasLimit, f.original.fields.gasLimit);
          } else {
            expect(prepared.fields.destination, sender);
            expect(prepared.fields.valueWei, BigInt.zero);
            expect(prepared.fields.dataHex, '0x');
          }
          expect(
            prepared.fields.effectivePrice(
              typed ? BigInt.from(1000000000) : BigInt.zero,
            ),
            greaterThan(
              f.original.fields.effectivePrice(
                typed ? BigInt.from(1000000000) : BigInt.zero,
              ),
            ),
          );
          final result = await f.service.submit(
            prepared,
            isCurrent: () => true,
          );
          expect(f.rpc.raw, await reference(prepared.fields));
          expect(result, txHash(f.rpc.raw!));
          expect(f.signer!.isClosed, isTrue);
          final entries = await f.journal.list(sender);
          expect(entries, hasLength(2));
          expect(entries.last.rootHash, f.original.hash);
          expect(entries.last.replacesHash, f.original.hash);
          expect(entries.last.state, EvmOutboundState.submitted);
          expect(
            f.rpc.methods.where((m) => m == 'eth_sendRawTransaction'),
            hasLength(1),
          );
        },
      );
    }
  }
  test(
    'fee bump rounds upward, increases zero tips and meets 12.5 percent policy',
    () {
      expect(EvmReplacementService.bumped(BigInt.zero), BigInt.one);
      expect(EvmReplacementService.bumped(BigInt.one), BigInt.two);
      expect(EvmReplacementService.bumped(BigInt.from(100)), BigInt.from(113));
    },
  );
  for (final problem in [
    'receipt',
    'nonce',
    'missing',
    'chain',
    'from',
    'to',
    'value',
    'input',
    'gas',
    'tip',
    'mined',
    'balance',
    'code',
    'gas-change',
  ]) {
    test('$problem refuses preparation before signing or broadcast', () async {
      final f = Fixture();
      addTearDown(f.rpc.client.dispose);
      await f.init();
      final tx = f.rpc.transactions[f.original.hash]!;
      switch (problem) {
        case 'receipt':
          f.rpc.receipt = {'status': '0x0'};
        case 'nonce':
          f.rpc.confirmedNonce = 8;
        case 'missing':
          f.rpc.transactions.clear();
        case 'chain':
          f.rpc.chainId = 56;
        case 'from':
          tx['from'] = recipient;
        case 'to':
          tx['to'] = sender;
        case 'value':
          tx['value'] = '0x0';
        case 'input':
          tx['input'] = '0x01';
        case 'gas':
          tx['gas'] = '0x5208';
        case 'tip':
          tx['maxPriorityFeePerGas'] = '0x1';
        case 'mined':
          tx['blockNumber'] = '0x100';
        case 'balance':
          f.rpc.balance = BigInt.zero;
        case 'code':
          f.rpc.code = '0xef0100${'11' * 20}';
        case 'gas-change':
          f.rpc.gas = 100000;
      }
      await expectLater(
        f.prepare(
          problem == 'code'
              ? EvmReplacementKind.cancel
              : EvmReplacementKind.speedUp,
        ),
        throwsA(isA<EvmReplacementException>()),
      );
      expect(f.opens, 0);
      expect(f.rpc.raw, isNull);
    });
  }
  for (final problem in [
    'expired',
    'wallet',
    'confirmed',
    'record',
    'context',
  ]) {
    test('$problem after approval prevents replacement broadcast', () async {
      final f = Fixture();
      addTearDown(f.rpc.client.dispose);
      await f.init();
      final prepared = await f.prepare();
      switch (problem) {
        case 'expired':
          f.clock = f.clock.add(const Duration(seconds: 31));
        case 'wallet':
          f.activeSender = recipient;
        case 'confirmed':
          f.rpc.receipt = {'status': '0x1'};
        case 'record':
          await f.journal.reserve(
            EvmOutboundTransaction(
              fields: EvmTransactionFields(
                chainId: 56,
                sender: sender,
                nonce: 8,
                destination: recipient,
                valueWei: BigInt.zero,
                dataHex: '0x',
                gasLimit: 21000,
                gasPriceWei: BigInt.one,
              ),
              hash: '0x${'bb' * 32}',
              state: EvmOutboundState.unknown,
              createdAt: f.clock,
            ),
          );
      }
      await expectLater(
        f.service.submit(prepared, isCurrent: () => problem != 'context'),
        throwsA(
          anyOf(isA<EvmReplacementException>(), isA<EvmFeeQuoteException>()),
        ),
      );
      expect(f.opens, 0);
      expect(f.rpc.raw, isNull);
    });
  }
  for (final mismatch in [false, true]) {
    test(
      '${mismatch ? 'wrong provider hash' : 'broadcast timeout'} retains exact replacement and blocks blind retry',
      () async {
        final f = Fixture();
        addTearDown(f.rpc.client.dispose);
        await f.init();
        final prepared = await f.prepare();
        f.rpc.timeoutSend = !mismatch;
        f.rpc.wrongHash = mismatch;
        await expectLater(
          f.service.submit(prepared, isCurrent: () => true),
          throwsA(isA<EvmReplacementException>()),
        );
        final saved = (await EvmOutboundStore(f.memory).list(sender)).last;
        expect(saved.state, EvmOutboundState.unknown);
        expect(saved.hash, txHash(f.rpc.raw!));
        expect(saved.fields.sameAs(prepared.fields), isTrue);
        await expectLater(f.prepare(), throwsA(isA<EvmReplacementException>()));
        expect(
          f.rpc.methods.where((method) => method == 'eth_sendRawTransaction'),
          hasLength(1),
        );
        expect(f.signer!.isClosed, isTrue);
      },
    );
  }
  test(
    'availability hides controls after confirmation and denies delegated-account Cancel',
    () async {
      final f = Fixture();
      addTearDown(f.rpc.client.dispose);
      await f.init();
      var value = await f.service.availability(
        sender,
        1,
        f.original.hash,
        isCurrent: () => true,
      );
      expect(value.pending, isTrue);
      expect(value.canCancel, isTrue);
      f.rpc.code = '0xef0100${'11' * 20}';
      value = await f.service.availability(
        sender,
        1,
        f.original.hash,
        isCurrent: () => true,
      );
      expect(value.pending, isTrue);
      expect(value.canCancel, isFalse);
      f.rpc.receipt = {'status': '0x1'};
      value = await f.service.availability(
        sender,
        1,
        f.original.hash,
        isCurrent: () => true,
      );
      expect(value.pending, isFalse);
    },
  );
  test(
    'wallet change while custody opens closes signer without broadcasting',
    () async {
      final f = Fixture();
      addTearDown(f.rpc.client.dispose);
      await f.init();
      final prepared = await f.prepare();
      f.afterOpen = () => f.activeSender = recipient;
      await expectLater(
        f.service.submit(prepared, isCurrent: () => true),
        throwsA(isA<EvmReplacementException>()),
      );
      expect(f.signer!.isClosed, isTrue);
      expect(f.rpc.raw, isNull);
      expect(await f.journal.list(sender), hasLength(1));
    },
  );
  test(
    'fee-only replacement refuses an original gas limit above current block capacity',
    () async {
      final f = Fixture();
      addTearDown(f.rpc.client.dispose);
      await f.init();
      f.rpc.blockGasLimit = 70000;
      await expectLater(f.prepare(), throwsA(isA<EvmReplacementException>()));
      expect(f.opens, 0);
      expect(f.rpc.raw, isNull);
    },
  );
  test('another service cannot reuse a prepared approval', () async {
    final f = Fixture();
    addTearDown(f.rpc.client.dispose);
    await f.init();
    final prepared = await f.prepare();
    final other = EvmReplacementService(
      journal: f.journal,
      client: f.rpc.client,
      currentSender: () => Future.value(sender),
      openSigner: f.wallet.getEvmSigningAccount,
    );
    await expectLater(
      other.submit(prepared, isCurrent: () => true),
      throwsA(isA<EvmReplacementException>()),
    );
    expect(f.rpc.raw, isNull);
  });
}
