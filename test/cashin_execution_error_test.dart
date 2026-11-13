import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:fomowl_wallet/features/mini_apps/cashin_execution_error.dart';

void main() {
  test('a direct USDC transfer does not become a failed swap', () {
    expect(
      cashinExecutionErrorMessage(
        const FormatException('Please retry in 1 seconds.'),
        isTransfer: true,
      ),
      'Transfer could not continue: Please retry in 1 seconds.',
    );
  });
  test('before a plan is loaded use a neutral payment label', () {
    expect(
      cashinExecutionErrorMessage(
        const FormatException('Execution plan unavailable.'),
      ),
      'Payment could not continue: Execution plan unavailable.',
    );
  });
  test(
    'throttling pauses payment without claiming the transfer or swap failed',
    () {
      const error = CashinExecutionRequestException(
        'Please retry in 1 seconds.',
        statusCode: 429,
        retryAfter: Duration(seconds: 1),
      );
      final message = cashinExecutionErrorMessage(error, isTransfer: true);
      expect(message, 'OwlletPay is busy. Please wait 1 second and try again.');
      expect(message.toLowerCase(), isNot(contains('failed')));
    },
  );
  test('a read-only execution lookup honors Retry-After once', () async {
    var calls = 0;
    final waits = <Duration>[];
    final response = await readCashinExecutionResponse(
      () async {
        calls++;
        return calls == 1
            ? http.Response('{}', 429, headers: {'Retry-After': '1'})
            : http.Response('{}', 200);
      },
      wait: (duration) async {
        waits.add(duration);
      },
    );
    expect(response.statusCode, 200);
    expect(calls, 2);
    expect(waits, [const Duration(seconds: 1)]);
  });
  test('persistent rate limiting does not create a retry storm', () async {
    var calls = 0;
    final response = await readCashinExecutionResponse(() async {
      calls++;
      return http.Response('{}', 429, headers: {'Retry-After': '1'});
    }, wait: (_) async {});
    expect(response.statusCode, 429);
    expect(calls, 2);
  });
  test(
    'long throttles and non-rate-limit errors are not automatically replayed',
    () async {
      for (final status in [429, 400, 401, 500]) {
        var calls = 0;
        final response = await readCashinExecutionResponse(
          () async {
            calls++;
            return http.Response('{}', status, headers: {'Retry-After': '60'});
          },
          wait: (_) async {
            fail('Unexpected automatic retry');
          },
        );
        expect(response.statusCode, status);
        expect(calls, 1);
      }
    },
  );
}
