import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/connectivity_recovery.dart';

void main() {
  test('requests one refresh when connectivity returns', () {
    final recovery = ConnectivityRecovery();

    expect(recovery.shouldRefresh(false), isFalse);
    expect(recovery.shouldRefresh(true), isTrue);
    expect(recovery.shouldRefresh(true), isFalse);

    recovery.finishRefresh(succeeded: true);
    expect(recovery.shouldRefresh(true), isFalse);
  });

  test('can refresh again after a later offline transition', () {
    final recovery = ConnectivityRecovery();

    recovery.shouldRefresh(false);
    expect(recovery.shouldRefresh(true), isTrue);
    recovery.finishRefresh(succeeded: true);
    recovery.shouldRefresh(false);
    expect(recovery.shouldRefresh(true), isTrue);
  });

  test('retries a failed refresh while connectivity remains online', () {
    final recovery = ConnectivityRecovery();

    recovery.shouldRefresh(false);
    expect(recovery.shouldRefresh(true), isTrue);
    recovery.finishRefresh(succeeded: false);

    expect(recovery.hasPendingRetry, isTrue);
    expect(recovery.shouldRefresh(true), isTrue);

    recovery.finishRefresh(succeeded: true);
    expect(recovery.hasPendingRetry, isFalse);
    expect(recovery.shouldRefresh(true), isFalse);
  });
}
