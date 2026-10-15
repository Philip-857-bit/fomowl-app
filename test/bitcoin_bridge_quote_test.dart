import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_bridge_quote.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15);
  final request = BitcoinBridgeRequest(
    originChainId: relayBitcoinChainId,
    destinationChainId: 8453,
    originCurrency: relayBitcoinCurrency,
    destinationCurrency: '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913',
    sender: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
    recipient: '0x03508bb71268bba25ecacc8f620e01866650532c',
    amount: BigInt.from(100000),
  );
  Map<String, dynamic> wire() => {
    'committed': true,
    'requestId': '0x${'1' * 64}',
    'intent': {
      'origin': {
        'chainId': relayBitcoinChainId,
        'providerChain': 'bitcoin',
        'family': 'bitcoin',
        'currency': relayBitcoinCurrency,
        'decimals': 8,
      },
      'destination': {
        'chainId': 8453,
        'providerChain': 'base',
        'family': 'evm',
        'currency': request.destinationCurrency,
        'decimals': 6,
      },
      'sender': request.sender,
      'recipient': request.recipient,
      'refundTo': request.sender,
      'amount': '100000',
    },
    'amountOut': '79000000',
    'minimumAmountOut': '78000000',
    'approvalExpiresAt': now.millisecondsSinceEpoch ~/ 1000 + 120,
    'providerDeadline': now.millisecondsSinceEpoch ~/ 1000 + 300,
    'bitcoinDepositAddress':
        'bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr',
    'originSteps': <Object?>[],
    'display': {
      'amountOutUsd': '79',
      'bridgeFeeUsd': null,
      'platformFeeUsd': null,
    },
  };
  BitcoinBridgeQuote parse(Map<String, dynamic> data) =>
      BitcoinBridgeQuote.fromJson(data, expected: request, now: now);

  test(
    'committed quote retains exact integer route facts and independent deadlines',
    () {
      final quote = parse(wire());
      expect(quote.request.amount, BigInt.from(100000));
      expect(quote.minimumAmountOut, BigInt.from(78000000));
      expect(quote.depositAddress, startsWith('bc1p'));
      expect(quote.originSteps, isEmpty);
      expect(quote.approvalExpiresAt, now.add(const Duration(minutes: 2)));
    },
  );
  test('preview cannot expose a Bitcoin deposit or signable origin steps', () {
    final data = wire()..['committed'] = false;
    expect(() => parse(data), throwsFormatException);
    data['bitcoinDepositAddress'] = null;
    expect(parse(data).committed, isFalse);
    data['originSteps'] = [
      {'id': 'deposit'},
    ];
    expect(() => parse(data), throwsFormatException);
  });
  test('changed recipient refund amount and decimals fail closed', () {
    for (final key in ['recipient', 'refundTo', 'amount']) {
      final data = wire();
      (data['intent'] as Map)[key] = 'changed';
      expect(() => parse(data), throwsFormatException);
    }
    final data = wire();
    ((data['intent'] as Map)['origin'] as Map)['decimals'] = 8.0;
    expect(() => parse(data), throwsFormatException);
  });
  test(
    'expired quote wrong-network funding and excessive Bitcoin amounts fail closed',
    () {
      final expired = wire()
        ..['approvalExpiresAt'] = now.millisecondsSinceEpoch ~/ 1000;
      expect(() => parse(expired), throwsFormatException);
      expect(
        () => parse(wire()..['bitcoinDepositAddress'] = 'tb1pwrongnetwork'),
        throwsFormatException,
      );
      expect(
        () => parse(wire()..['minimumAmountOut'] = '99999999999999999'),
        throwsFormatException,
      );
      expect(() => parse(wire()..['amountOut'] = 79.0), throwsFormatException);
    },
  );
  test('mutating transport maps cannot mutate the approved quote', () {
    final data = wire();
    final quote = parse(data);
    (data['intent'] as Map)['amount'] = '1';
    quote.toJson()['amountOut'] = '1';
    expect(quote.request.amount, BigInt.from(100000));
    expect(quote.toJson()['amountOut'], '79000000');
    expect(() => quote.originSteps.add({}), throwsUnsupportedError);
    expect(() => quote.display['amountOutUsd'] = '1', throwsUnsupportedError);
  });
}
