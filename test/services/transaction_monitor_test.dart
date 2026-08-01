import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/transaction_monitor.dart';

void main() {
  group('TransactionMonitor EVM confirmation classification', () {
    final monitor = TransactionMonitor();

    test('only an explicit false receipt status is failed', () {
      expect(
        monitor.confirmationStatusFromEvmReceipt(true),
        TransactionConfirmationStatus.confirmed,
      );
      expect(
        monitor.confirmationStatusFromEvmReceipt(false),
        TransactionConfirmationStatus.failed,
      );
      expect(
        monitor.confirmationStatusFromEvmReceipt(null),
        TransactionConfirmationStatus.pending,
      );
    });
  });

  group('TransactionMonitor non-EVM confirmation classification', () {
    final monitor = TransactionMonitor();

    test('keeps an explicitly pending Solana transaction pending', () {
      expect(
        monitor.nonEvmStatusForTest(const <String, dynamic>{
          'pending': true,
        }, 'solana:mainnet'),
        TransactionConfirmationStatus.pending,
      );
    });

    test('does not treat an incomplete Solana response as success', () {
      expect(
        monitor.nonEvmStatusForTest(
          const <String, dynamic>{},
          'solana:mainnet',
        ),
        TransactionConfirmationStatus.pending,
      );
    });

    test('recognizes explicit Solana success and failure', () {
      expect(
        monitor.nonEvmStatusForTest(const <String, dynamic>{
          'status': 1,
        }, 'solana:mainnet'),
        TransactionConfirmationStatus.confirmed,
      );
      expect(
        monitor.nonEvmStatusForTest(const <String, dynamic>{
          'status': 0,
        }, 'solana:mainnet'),
        TransactionConfirmationStatus.failed,
      );
    });

    test('recognizes Tron success but leaves an empty response pending', () {
      expect(
        monitor.nonEvmStatusForTest(const <String, dynamic>{
          'result': 'SUCCESS',
        }, 'tron:mainnet'),
        TransactionConfirmationStatus.confirmed,
      );
      expect(
        monitor.nonEvmStatusForTest(const <String, dynamic>{}, 'tron:mainnet'),
        TransactionConfirmationStatus.pending,
      );
    });
  });
}
