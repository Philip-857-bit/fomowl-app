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
      expect(AppErrorUtils.backendMessage(body, fallback: fallback), fallback);
    });

    test('returns fallback when message field is empty', () {
      const body = '{"message": ""}';
      expect(AppErrorUtils.backendMessage(body, fallback: fallback), fallback);
    });

    test('returns fallback when body contains sensitive terms', () {
      const sensitiveBody = '{"message": "Invalid challenge token"}';
      expect(
        AppErrorUtils.backendMessage(sensitiveBody, fallback: fallback),
        'Authentication failed. Please try again.',
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

    test(
      'sanitizes infra-detail message containing "connection refused" to connection fallback',
      () {
        const body =
            '{"message": "dial tcp 10.0.0.5:5432: connect: connection refused"}';
        expect(
          AppErrorUtils.backendMessage(body, fallback: fallback),
          'Connection failed. Please check your internet and try again.',
        );
      },
    );

    test(
      'sanitizes infra-detail message containing "timed out" to connection fallback',
      () {
        const body = '{"message": "request timed out after 30s"}';
        expect(
          AppErrorUtils.backendMessage(body, fallback: fallback),
          'Connection failed. Please check your internet and try again.',
        );
      },
    );

    test('sanitizes messages with backend/RPC details to fallback', () {
      const body = '{"message": "upstream rpc node unreachable"}';
      expect(AppErrorUtils.backendMessage(body, fallback: fallback), fallback);
    });

    test('maps raw Jupiter quote failures to a route message', () {
      const body =
          '{"error":"Swap failed","message":"Jupiter /order failed: {\\"requestId\\":\\"abc\\",\\"error\\":\\"Failed to get quotes\\"}"}';
      expect(
        AppErrorUtils.backendMessage(body, fallback: fallback),
        'Amount is too low for this swap. Try a larger amount.',
      );
    });

    test('maps Solana insufficient lamports failures to a clear message', () {
      const body =
          '{"error":"Failed to broadcast Solana transaction","message":"RPC error: Transaction simulation failed: Attempt to debit an account but found no record of a prior credit."}';
      expect(
        AppErrorUtils.backendMessage(body, fallback: fallback),
        'Insufficient SOL to cover the transfer amount and network fee.',
      );
    });

    test('maps missing Solana recipient token account to a clear message', () {
      const body =
          '{"error":"Failed to build SPL transfer","message":"Destination token account ABC does not exist. The recipient must have an associated token account for mint XYZ."}';
      expect(
        AppErrorUtils.backendMessage(body, fallback: fallback),
        'The recipient does not have a token account for this asset. They must first receive or create an account for this token before you can send it.',
      );
    });

    test('keeps Solana inactive recipient guidance user-facing', () {
      const body =
          '{"error":"Solana transfer amount too low","message":"This Solana recipient account is not active yet. Send at least 0.000890880 SOL to activate it, or send to an address that already has SOL."}';
      expect(
        AppErrorUtils.backendMessage(body, fallback: fallback),
        'This Solana recipient account is not active yet. Send at least 0.000890880 SOL to activate it, or send to an address that already has SOL.',
      );
    });

    test('sanitizes Jupiter request identifiers without route details', () {
      const body =
          '{"message":"Jupiter /order failed: {\\"requestId\\":\\"abc\\"}"}';
      expect(AppErrorUtils.backendMessage(body, fallback: fallback), fallback);
    });

    test('returns fallback when backend message exposes a remote URL', () {
      const body =
          '{"message": "Request to https://core.owlletapp.com/api failed"}';
      expect(AppErrorUtils.backendMessage(body, fallback: fallback), fallback);
    });
  });

  group('AppErrorUtils.userMessage', () {
    const fallback = 'Something went wrong.';

    test('returns fallback when raw error exposes backend URL', () {
      expect(
        AppErrorUtils.userMessage(
          'https://core.owlletapp.com/api/swap/quote failed',
          fallback: fallback,
        ),
        fallback,
      );
    });

    test('maps Jupiter quote errors to a route message', () {
      expect(
        AppErrorUtils.userMessage(
          'Jupiter /order failed: {"requestId":"abc","error":"Failed to get quotes"}',
          fallback: fallback,
        ),
        'Amount is too low for this swap. Try a larger amount.',
      );
    });
  });
}
