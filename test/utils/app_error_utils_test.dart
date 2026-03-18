import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/utils/app_error_utils.dart';

void main() {
  group('AppErrorUtils.backendMessage', () {
    const fallback = 'Something went wrong.';

    test('returns fallback for null body', () {
      expect(AppErrorUtils.backendMessage(null, fallback: fallback), fallback);
    });

    test('returns fallback for empty body', () {
      expect(AppErrorUtils.backendMessage('', fallback: fallback), fallback);
    });

    test('returns fallback for non-JSON body', () {
      expect(
        AppErrorUtils.backendMessage('not json', fallback: fallback),
        fallback,
      );
    });

    test('extracts message field from JSON body', () {
      const body = '{"message": "Invalid wallet address"}';
      expect(
        AppErrorUtils.backendMessage(body, fallback: fallback),
        'Invalid wallet address',
      );
    });

    test('returns fallback when JSON has no message field', () {
      const body = '{"error": "something"}';
      expect(
        AppErrorUtils.backendMessage(body, fallback: fallback),
        fallback,
      );
    });

    test('returns fallback when message field is empty', () {
      const body = '{"message": ""}';
      expect(
        AppErrorUtils.backendMessage(body, fallback: fallback),
        fallback,
      );
    });

    test('returns fallback when body contains sensitive terms', () {
      const sensitiveBody = '{"message": "Invalid challenge token"}';
      expect(
        AppErrorUtils.backendMessage(sensitiveBody, fallback: fallback),
        fallback,
      );
    });

    test('returns fallback when body contains database terms', () {
      const sensitiveBody = '{"message": "database error occurred"}';
      expect(
        AppErrorUtils.backendMessage(sensitiveBody, fallback: fallback),
        fallback,
      );
    });

    test('returns actual message for a non-sensitive user-facing error', () {
      const body = '{"message": "Email already in use"}';
      expect(
        AppErrorUtils.backendMessage(body, fallback: fallback),
        'Email already in use',
      );
    });
  });
}
