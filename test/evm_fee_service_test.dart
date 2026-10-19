import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/json_rpc.dart';
import 'package:fomowl_wallet/models/evm_fee_quote.dart';
import 'package:fomowl_wallet/services/evm_fee_service.dart';

final sender = '0x${'11' * 20}';
final recipient = '0x${'22' * 20}';
final now = DateTime.utc(2026, 10, 12);
String hex(BigInt value) => '0x${value.toRadixString(16)}';
Map<String, dynamic> history({
  int base = 100,
  List<int> tips = const [1, 3, 7],
}) => {
  'oldestBlock': '0x8',
  'baseFeePerGas': [
    '0x${base.toRadixString(16)}',
    '0x${base.toRadixString(16)}',
    '0x${base.toRadixString(16)}',
  ],
  'reward': [
    tips.map((n) => '0x${n.toRadixString(16)}').toList(),
    tips.map((n) => '0x${n.toRadixString(16)}').toList(),
  ],
};

class FeeRpc {
  final scope = Object();
  final calls = <(String, List<dynamic>)>[];
  final replies = <String, Object?>{
    'eth_chainId': '0x1',
    'eth_getBlockByNumber': {
      'number': '0x9',
      'gasLimit': '0x1c9c380',
      'baseFeePerGas': '0x64',
    },
    'eth_gasPrice': '0x67',
    'eth_estimateGas': '0x5208',
    'eth_feeHistory': history(),
    'eth_maxPriorityFeePerGas': '0x3',
  };
  DateTime clock = now;
  void Function(String)? afterCall;
  Future<Object?> call(String method, List<dynamic> params) async {
    calls.add((method, params));
    afterCall?.call(method);
    final value = replies[method];
    if (value is Exception) throw value;
    if (value is Future<Object?>) return value;
    return value;
  }

  Future<EvmFeeQuotes> quote({
    int chainId = 1,
    BigInt? value,
    Uint8List? data,
  }) => EvmFeeService(rpc: call, rpcScope: scope, now: () => clock).quote(
    chainId: chainId,
    sender: sender,
    destination: recipient,
    valueWei: value ?? BigInt.one,
    data: data ?? Uint8List(0),
  );
}

void main() {
  test(
    'null base-fee field is malformed rather than legacy capability',
    () async {
      final rpc = FeeRpc();
      rpc.replies['eth_getBlockByNumber'] = <String, dynamic>{
        ...(rpc.replies['eth_getBlockByNumber'] as Map<String, dynamic>),
        'baseFeePerGas': null,
      };
      await expectLater(rpc.quote(), throwsA(isA<EvmFeeQuoteException>()));
    },
  );
  test('request deadline must be positive and bounded', () {
    final rpc = FeeRpc();
    for (final deadline in [
      Duration.zero,
      const Duration(seconds: -1),
      const Duration(seconds: 31),
    ]) {
      expect(
        () => EvmFeeService(
          rpc: rpc.call,
          rpcScope: rpc.scope,
          timeout: deadline,
        ),
        throwsA(isA<EvmFeeQuoteException>()),
      );
    }
  });

  test(
    'runtime base-fee presence selects type 2 and observed reward tiers',
    () async {
      final rpc = FeeRpc();
      final quotes = await rpc.quote();
      expect(quotes.hasDistinctTiers, isTrue);
      final normal = quotes.forTier(EvmFeeTier.normal);
      expect(normal.type, EvmTransactionType.dynamicFee);
      expect(normal.baseFeePerGasWei, BigInt.from(100));
      expect(normal.maxPriorityFeePerGasWei, BigInt.from(3));
      expect(normal.maxFeePerGasWei, BigInt.from(203));
      expect(normal.gasPriceWei, isNull);
      expect(normal.gasLimit, 23100);
      expect(normal.estimatedTotalFeeWei, BigInt.from(23100 * 103));
      expect(normal.maximumTotalFeeWei, BigInt.from(23100 * 203));
      expect(
        quotes.forTier(EvmFeeTier.economy).maxPriorityFeePerGasWei,
        BigInt.one,
      );
      expect(
        quotes.forTier(EvmFeeTier.priority).maxPriorityFeePerGasWei,
        BigInt.from(7),
      );
      expect(rpc.calls.map((c) => c.$1), [
        'eth_chainId',
        'eth_getBlockByNumber',
        'eth_gasPrice',
        'eth_estimateGas',
        'eth_feeHistory',
      ]);
    },
  );
  test(
    'valid zero base fee still proves type 2, even on an unknown chain ID',
    () async {
      final rpc = FeeRpc();
      rpc.replies['eth_chainId'] = '0xf423f';
      rpc.replies['eth_getBlockByNumber'] = {
        'number': '0x9',
        'gasLimit': '0x1c9c380',
        'baseFeePerGas': '0x0',
      };
      rpc.replies['eth_gasPrice'] = '0x3';
      rpc.replies['eth_feeHistory'] = history(base: 0);
      final quote = (await rpc.quote(
        chainId: 999999,
      )).forTier(EvmFeeTier.normal);
      expect(quote.type, EvmTransactionType.dynamicFee);
      expect(quote.maxFeePerGasWei, BigInt.from(3));
    },
  );
  test(
    'legacy chains retain type 0 and meaningful observed gas-price tiers',
    () async {
      final rpc = FeeRpc();
      rpc.replies['eth_getBlockByNumber'] = {
        'number': '0x9',
        'gasLimit': '0x1c9c380',
      };
      rpc.replies['eth_feeHistory'] = history(base: 0, tips: [110, 120, 140]);
      final quotes = await rpc.quote();
      expect(quotes.hasDistinctTiers, isTrue);
      expect(quotes.forTier(EvmFeeTier.normal).type, EvmTransactionType.legacy);
      expect(quotes.forTier(EvmFeeTier.normal).gasPriceWei, BigInt.from(120));
      expect(quotes.forTier(EvmFeeTier.normal).maxFeePerGasWei, isNull);
    },
  );
  test(
    'unsupported history on legacy chains yields equal validated recommended rates',
    () async {
      final rpc = FeeRpc();
      rpc.replies['eth_getBlockByNumber'] = {
        'number': '0x9',
        'gasLimit': '0x1c9c380',
      };
      rpc.replies['eth_feeHistory'] = const RPCError(
        -32601,
        'unsupported',
        null,
      );
      final quotes = await rpc.quote();
      expect(quotes.hasDistinctTiers, isFalse);
      expect(quotes.forTier(EvmFeeTier.normal).gasPriceWei, BigInt.from(103));
      expect(rpc.calls.any((c) => c.$1 == 'eth_maxPriorityFeePerGas'), isFalse);
    },
  );
  for (final unsupportedTip in [false, true]) {
    test(
      'unsupported history falls back safely to validated tip/gas data; tip unsupported=$unsupportedTip',
      () async {
        final rpc = FeeRpc();
        rpc.replies['eth_feeHistory'] = const RPCError(
          -32601,
          'unsupported',
          null,
        );
        if (unsupportedTip) {
          rpc.replies['eth_maxPriorityFeePerGas'] = const RPCError(
            -32004,
            'unsupported',
            null,
          );
        }
        final quotes = await rpc.quote();
        expect(quotes.hasDistinctTiers, isFalse);
        expect(
          quotes.forTier(EvmFeeTier.normal).maxPriorityFeePerGasWei,
          BigInt.from(3),
        );
        expect(
          quotes.forTier(EvmFeeTier.normal).type,
          EvmTransactionType.dynamicFee,
        );
      },
    );
  }
  test(
    'empty-block zero rewards cannot override a valid network fee recommendation',
    () async {
      final rpc = FeeRpc()
        ..replies['eth_feeHistory'] = history(tips: [0, 0, 0]);
      final quotes = await rpc.quote();
      expect(quotes.hasDistinctTiers, isFalse);
      expect(
        quotes.forTier(EvmFeeTier.normal).maxPriorityFeePerGasWei,
        BigInt.from(3),
      );
    },
  );
  test(
    'gas buffering uses checked integer arithmetic and respects block capacity',
    () async {
      final rpc = FeeRpc()..replies['eth_estimateGas'] = '0x5209';
      expect((await rpc.quote()).forTier(EvmFeeTier.normal).gasLimit, 23102);
      rpc.replies['eth_getBlockByNumber'] = {
        'number': '0x9',
        'gasLimit': '0x5209',
        'baseFeePerGas': '0x64',
      };
      expect((await rpc.quote()).forTier(EvmFeeTier.normal).gasLimit, 21001);
    },
  );
  for (final condition in [
    'wrong-chain',
    'empty-block',
    'null-block',
    'bad-base',
    'bad-price',
    'zero-gas',
    'excess-gas',
    'bad-history',
    'null-history',
    'bad-reward',
    'inconsistent-legacy',
    'fee-overflow',
    'provider-outage',
    'history-outage',
  ]) {
    test('$condition fails closed without fee fabrication', () async {
      final rpc = FeeRpc();
      switch (condition) {
        case 'wrong-chain':
          rpc.replies['eth_chainId'] = '0x2';
        case 'empty-block':
          rpc.replies['eth_getBlockByNumber'] = <String, dynamic>{};
        case 'null-block':
          rpc.replies['eth_getBlockByNumber'] = null;
        case 'bad-base':
          rpc.replies['eth_getBlockByNumber'] = {
            'number': '0x9',
            'gasLimit': '0x1c9c380',
            'baseFeePerGas': '100',
          };
        case 'bad-price':
          rpc.replies['eth_gasPrice'] = '0x00';
        case 'zero-gas':
          rpc.replies['eth_estimateGas'] = '0x0';
        case 'excess-gas':
          rpc.replies['eth_estimateGas'] = '0xffffffffffffffff';
        case 'bad-history':
          rpc.replies['eth_feeHistory'] = <String, dynamic>{};
        case 'null-history':
          rpc.replies['eth_feeHistory'] = null;
        case 'bad-reward':
          rpc.replies['eth_feeHistory'] = history(tips: [7, 3, 1]);
        case 'inconsistent-legacy':
          rpc.replies['eth_getBlockByNumber'] = {
            'number': '0x9',
            'gasLimit': '0x1c9c380',
          };
        case 'fee-overflow':
          rpc.replies['eth_getBlockByNumber'] = {
            'number': '0x9',
            'gasLimit': '0x1c9c380',
            'baseFeePerGas': hex(BigInt.one << 127),
          };
        case 'provider-outage':
          rpc.replies['eth_gasPrice'] = Exception('secret-provider-token');
        case 'history-outage':
          rpc.replies['eth_feeHistory'] = const RPCError(
            -32002,
            'secret-provider-token',
            null,
          );
      }
      await expectLater(
        rpc.quote(),
        throwsA(
          isA<EvmFeeQuoteException>().having(
            (e) => e.toString(),
            'safe message',
            isNot(contains('secret-provider-token')),
          ),
        ),
      );
    });
  }
  test(
    'quotes become invalid when lookup takes beyond the approval freshness window',
    () async {
      final rpc = FeeRpc();
      rpc.afterCall = (method) {
        if (method == 'eth_feeHistory') {
          rpc.clock = now.add(const Duration(seconds: 31));
        }
      };
      await expectLater(rpc.quote(), throwsA(isA<EvmFeeQuoteException>()));
    },
  );
  test(
    'immutable public intent binds wallet, chain, destination, value, data and RPC scope',
    () async {
      final rpc = FeeRpc();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final quotes = await rpc.quote(data: bytes);
      final quote = quotes.forTier(EvmFeeTier.normal);
      bytes[0] = 9;
      expect(quote.intent.dataHex, '010203');
      expect(
        quote.intent.matches(
          chainId: 1,
          sender: sender,
          destination: recipient,
          valueWei: BigInt.one,
          data: Uint8List.fromList([1, 2, 3]),
          rpcScope: rpc.scope,
        ),
        isTrue,
      );
      for (final tuple in [
        (2, sender, recipient, BigInt.one, rpc.scope),
        (1, recipient, recipient, BigInt.one, rpc.scope),
        (1, sender, sender, BigInt.one, rpc.scope),
        (1, sender, recipient, BigInt.two, rpc.scope),
        (1, sender, recipient, BigInt.one, Object()),
      ]) {
        expect(
          quote.intent.matches(
            chainId: tuple.$1,
            sender: tuple.$2,
            destination: tuple.$3,
            valueWei: tuple.$4,
            data: Uint8List.fromList([1, 2, 3]),
            rpcScope: tuple.$5,
          ),
          isFalse,
        );
      }
      expect(() => quotes.tiers.clear(), throwsUnsupportedError);
      expect(quote.isFresh(now.add(const Duration(seconds: 30))), isFalse);
      expect(quote.isFresh(now.subtract(const Duration(seconds: 1))), isFalse);
    },
  );
}
