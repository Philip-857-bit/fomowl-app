import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_offramp_intent.dart';

const reference = 'OWL-PAY-1234567890';
const destination =
    'bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr';

Map<String, dynamic> plan() => {
  'reference': reference,
  'action': 'transfer',
  'networkKey': 'bitcoin:mainnet',
  'chainFamily': 'bitcoin',
  'assetSymbol': 'BTC',
  'nativeSymbol': 'BTC',
  'decimals': 8,
  'fundingExpiresAt': '2099-01-01T00:00:00Z',
  'tokenContract': null,
  'toAddress': destination,
  'amountBaseUnits': '4730',
};

void main() {
  test('funding expiry requires an exact valid UTC deadline', () {
    for (final expiry in [
      null,
      '',
      'invalid',
      '2099-02-30T00:00:00Z',
      '2099-01-01T00:00:00+01:00',
    ]) {
      expect(
        () => BitcoinOfframpIntent.fromWithdrawalPlan(reference, {
          ...plan(),
          'fundingExpiresAt': expiry,
        }),
        throwsFormatException,
      );
    }
    // Expired submissions remain decodable for tracking after restart.
    final saved = BitcoinOfframpIntent.fromWithdrawalPlan(reference, {
      ...plan(),
      'fundingExpiresAt': '2020-01-01T00:00:00Z',
    });
    expect(saved.fundingExpiresAt, DateTime.utc(2020));
    expect(
      saved.matches(BitcoinOfframpIntent.fromWithdrawalPlan(reference, plan())),
      isFalse,
    );
  });
  test(
    'server intent preserves exact reference, destination and integer sats',
    () {
      final intent = BitcoinOfframpIntent.fromWithdrawalPlan(reference, plan());
      expect(intent.reference, reference);
      expect(intent.destination, destination);
      expect(intent.amountSat, BigInt.from(4730));
      expect(
        intent.matches(
          BitcoinOfframpIntent.fromWithdrawalPlan(reference, plan()),
        ),
        isTrue,
      );
    },
  );

  test(
    'other withdrawal, network, asset and conversion instructions fail closed',
    () {
      for (final changed in [
        {'reference': 'OWL-PAY-other'},
        {'networkKey': 'bitcoin:testnet4'},
        {'networkKey': 'evm:1'},
        {'chainFamily': 'evm'},
        {'assetSymbol': 'WBTC'},
        {'nativeSymbol': 'ETH'},
        {'decimals': 18},
        {'decimals': 8.0},
        {'tokenContract': 'fake-token'},
        {'action': 'swap_then_transfer'},
        {'sourceNetworkKey': 'evm:1'},
        {'quoteMode': 'EXACT_OUTPUT'},
        {'toAddress': 'not-a-bitcoin-address'},
      ]) {
        expect(
          () => BitcoinOfframpIntent.fromWithdrawalPlan(reference, {
            ...plan(),
            ...changed,
          }),
          throwsFormatException,
        );
      }
    },
  );

  test('amount accepts only bounded canonical satoshi strings', () {
    for (final amount in [
      null,
      4730,
      4730.0,
      '0',
      '-1',
      '04730',
      '47.30',
      '4.73e3',
      ' 4730',
      '2100000000000001',
    ]) {
      expect(
        () => BitcoinOfframpIntent.fromWithdrawalPlan(reference, {
          ...plan(),
          'amountBaseUnits': amount,
        }),
        throwsFormatException,
      );
    }
    final maximum = BitcoinOfframpIntent.fromWithdrawalPlan(reference, {
      ...plan(),
      'amountBaseUnits': '2100000000000000',
    });
    expect(maximum.amountSat, BigInt.from(2100000000000000));
  });
}
