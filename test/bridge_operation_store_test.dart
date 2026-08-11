import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/services/bridge_operation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists, restores, and clears a pending bridge by wallet', () async {
    final store = BridgeOperationStore();
    final operation = PendingBridgeOperation(
      walletAddress: 'TWallet',
      requestId: 'near:TDeposit',
      originTxHash: 'abc123',
      originChainId: 728126428,
      destinationChainId: 1399811149,
      sellToken: 'TRX',
      buyToken: 'SOL',
      amount: 25,
      amountUsd: 8.5,
      createdAt: DateTime.utc(2026, 8, 8),
      deadline: DateTime.utc(2026, 8, 8, 0, 10),
    );

    await store.save(operation);
    final restored = await store.load('TWallet');

    expect(restored, isNotNull);
    expect(restored!.requestId, operation.requestId);
    expect(restored.originTxHash, operation.originTxHash);
    expect(restored.sellToken, 'TRX');
    expect(restored.buyToken, 'SOL');
    expect(restored.amount, 25);
    expect(restored.amountUsd, 8.5);
    expect(restored.deadline, operation.deadline);

    await store.clear('TWallet');
    expect(await store.load('TWallet'), isNull);
  });

  test(
    'rejects incomplete operations instead of storing false recovery data',
    () {
      final store = BridgeOperationStore();
      final operation = PendingBridgeOperation(
        walletAddress: 'TWallet',
        requestId: '',
        originTxHash: 'abc123',
        originChainId: 728126428,
        destinationChainId: 1,
        createdAt: DateTime.now(),
      );

      expect(store.save(operation), throwsArgumentError);
    },
  );

  test('preserves case when storing non-EVM wallet addresses', () async {
    final store = BridgeOperationStore();
    final operation = PendingBridgeOperation(
      walletAddress: 'CaseSensitiveWallet',
      requestId: 'near:TDeposit',
      originTxHash: 'abc123',
      originChainId: 728126428,
      destinationChainId: 1399811149,
      createdAt: DateTime.utc(2026, 8, 8),
    );

    await store.save(operation);

    expect(await store.load('casesensitivewallet'), isNull);
    expect(await store.load('CaseSensitiveWallet'), isNotNull);
  });

  test('normalizes EVM wallet address casing', () async {
    final store = BridgeOperationStore();
    final operation = PendingBridgeOperation(
      walletAddress: '0xABCDEFabcdefABCDEFabcdefABCDEFabcdefABCD',
      requestId: 'relay:deposit',
      originTxHash: '0x123',
      originChainId: 1,
      destinationChainId: 8453,
      createdAt: DateTime.utc(2026, 8, 8),
    );

    await store.save(operation);

    expect(
      await store.load('0xabcdefabcdefabcdefabcdefabcdefabcdefabcd'),
      isNotNull,
    );
  });
}
