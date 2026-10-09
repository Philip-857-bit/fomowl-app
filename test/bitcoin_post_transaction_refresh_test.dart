import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/bitcoin/bitcoin_post_transaction_refresh.dart';

void main() {
  test(
    'refreshes immediately and retries delayed provider state after an outage',
    () {
      fakeAsync((clock) {
        var calls = 0;
        final service = BitcoinPostTransactionRefresh();
        service.schedule(
          isCurrent: () => true,
          refresh: () async {
            calls++;
            if (calls == 1) throw StateError('Fixture outage');
          },
        );
        clock.flushMicrotasks();
        expect(calls, 1);
        clock.elapse(const Duration(seconds: 3));
        expect(calls, 2);
        clock.elapse(const Duration(seconds: 10));
        expect(calls, 3);
        expect(clock.nonPeriodicTimerCount, 0);
        service.dispose();
      });
    },
  );
  test('rescheduling does not overlap refresh requests', () {
    fakeAsync((clock) {
      var calls = 0;
      final pending = Completer<void>();
      final service = BitcoinPostTransactionRefresh();
      Future<void> refresh() {
        calls++;
        return calls == 1 ? pending.future : Future.value();
      }

      service.schedule(isCurrent: () => true, refresh: refresh);
      service.schedule(isCurrent: () => true, refresh: refresh);
      clock.flushMicrotasks();
      expect(calls, 1);
      pending.complete();
      clock.flushMicrotasks();
      expect(calls, 2);
      service.dispose();
      clock.flushMicrotasks();
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });
  test('wallet switch prevents delayed refreshes', () {
    fakeAsync((clock) {
      var calls = 0;
      var current = true;
      final service = BitcoinPostTransactionRefresh();
      service.schedule(
        isCurrent: () => current,
        refresh: () async {
          calls++;
        },
      );
      clock.flushMicrotasks();
      current = false;
      clock.elapse(const Duration(seconds: 30));
      expect(calls, 1);
      expect(clock.nonPeriodicTimerCount, 0);
      service.dispose();
    });
  });
}
