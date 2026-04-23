import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/cow_limit_order_signing.dart';

void main() {
  test('CoW order typed data matches domain and field order', () {
    final order = buildCowLimitOrderPayload(
      sellToken: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
      buyToken: '0x6b175474e89094c44da98b954eedeac495271d0f',
      receiver: '0x111111125421ca6dc452d289314280a0f8842a65',
      sellAmount: '1000000',
      buyAmount: '998000000000000000',
      validTo: 1700000000,
    );
    final typedData = buildCowOrderTypedData(chainId: 1, order: order);

    expect(typedData['primaryType'], 'Order');
    expect(typedData['domain'], {
      'name': cowDomainName,
      'version': cowDomainVersion,
      'chainId': 1,
      'verifyingContract': cowSettlementContracts[1],
    });
    expect(typedData['types']['Order'], cowOrderFields);
    expect(typedData['message']['feeAmount'], '0');
    expect(typedData['message']['kind'], 'sell');
    expect(typedData['message']['appData'], cowZeroAppDataHash);
  });

  test('CoW cancellation typed data uses orderUids bytes array', () {
    final typedData = buildCowOrderCancellationTypedData(
      chainId: 42161,
      orderUids: const ['0xabc123'],
    );

    expect(typedData['primaryType'], 'OrderCancellations');
    expect(
      typedData['types']['OrderCancellations'],
      cowOrderCancellationsFields,
    );
    expect(typedData['message']['orderUids'], const ['0xabc123']);
  });

  test('Never preset maps to one year', () {
    final now = DateTime(2026, 4, 22, 10, 30);
    final validTo = resolveCowNeverValidTo(now: now);

    expect(
      validTo,
      now.add(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000,
    );
  });

  test('Vault relayer is available only on supported limit networks', () {
    expect(cowVaultRelayerForChain(1), cowVaultRelayerAddress);
    expect(cowVaultRelayerForChain(10), isNull);
  });
}
