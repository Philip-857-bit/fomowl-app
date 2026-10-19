import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_bill_funding_plan.dart';

void main() {
  const reference = 'OWL-BTC-BILL-11111111111111111111111111111111';
  Map<String, dynamic> invoice() => {
    'reference': reference,
    'walletIdentity': '0xwallet',
    'action': 'transfer',
    'quoteMode': 'owllet_bitcoin_bill',
    'networkKey': 'bitcoin:mainnet',
    'chainFamily': 'bitcoin',
    'assetSymbol': 'BTC',
    'nativeSymbol': 'BTC',
    'decimals': 8,
    'amountBaseUnits': '1065',
    'expiresAt': 2000000000,
    'toAddress': 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
    'collectionPaymentId': 'collection',
    'billProvider': 'vtpass',
    'bill': {
      'serviceType': 'airtime',
      'serviceId': 'mtn',
      'beneficiary': '08011111111',
      'amountKobo': 160000,
    },
  };
  test('server bill invoice retains exact sats and public bill summary', () {
    final plan = BitcoinBillFundingPlan.fromServer(
      reference,
      ' 0xWALLET ',
      invoice(),
    );
    expect(plan.amountSat, BigInt.from(1065));
    expect(plan.amountKobo, BigInt.from(160000));
    expect(plan.serviceType, 'airtime');
    expect(plan.expiresAt.isUtc, isTrue);
  });
  test('cross-purpose network wallet and fractional amounts fail closed', () {
    for (final change in <String, dynamic>{
      'quoteMode': 'breet',
      'networkKey': 'bitcoin:testnet4',
      'walletIdentity': '0xother',
      'amountBaseUnits': 1065,
      'decimals': 8.0,
      'tokenContract': 'token',
      'billProvider': 'breet',
    }.entries) {
      final value = invoice()..[change.key] = change.value;
      expect(
        () => BitcoinBillFundingPlan.fromServer(reference, '0xwallet', value),
        throwsFormatException,
      );
    }
    expect(
      () => BitcoinBillFundingPlan.fromServer(
        'withdrawal',
        '0xwallet',
        invoice(),
      ),
      throwsFormatException,
    );
  });
}
