import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/utils/rpc_url_validator.dart';

void main() {
  group('isBlockedRpcHost', () {
    test('allows regular DNS names', () {
      expect(isBlockedRpcHost('example.com'), isFalse);
      expect(isBlockedRpcHost('api.mainnet.com'), isFalse);
      expect(isBlockedRpcHost('fomowl.com'), isFalse);
      expect(isBlockedRpcHost('rpc.ankr.com'), isFalse);
    });

    test('blocks local and internal names', () {
      expect(isBlockedRpcHost('localhost'), isTrue);
      expect(isBlockedRpcHost('my-pc.localhost'), isTrue);
      expect(isBlockedRpcHost('dev.local'), isTrue);
      expect(isBlockedRpcHost('test.internal'), isTrue);
      expect(isBlockedRpcHost('LOCALHOST'), isTrue); // Case insensitivity
    });

    test('blocks empty hosts', () {
      expect(isBlockedRpcHost(''), isTrue);
      expect(isBlockedRpcHost('   '), isTrue);
      expect(isBlockedRpcHost('[]'), isTrue);
    });

    group('IPv4', () {
      test('blocks loopback', () {
        expect(isBlockedRpcHost('127.0.0.1'), isTrue);
        expect(isBlockedRpcHost('127.255.255.255'), isTrue);
      });

      test('blocks private', () {
        expect(isBlockedRpcHost('10.0.0.1'), isTrue);
        expect(isBlockedRpcHost('10.255.255.255'), isTrue);

        expect(isBlockedRpcHost('172.16.0.0'), isTrue);
        expect(isBlockedRpcHost('172.31.255.255'), isTrue);

        expect(isBlockedRpcHost('192.168.0.0'), isTrue);
        expect(isBlockedRpcHost('192.168.255.255'), isTrue);
      });

      test('blocks link-local', () {
        expect(isBlockedRpcHost('169.254.0.0'), isTrue);
        expect(isBlockedRpcHost('169.254.255.255'), isTrue);
      });

      test('blocks CGNAT', () {
        expect(isBlockedRpcHost('100.64.0.0'), isTrue);
        expect(isBlockedRpcHost('100.127.255.255'), isTrue);
      });

      test('blocks 0.0.0.0/8', () {
        expect(isBlockedRpcHost('0.0.0.0'), isTrue);
        expect(isBlockedRpcHost('0.255.255.255'), isTrue);
      });

      test('blocks broadcast', () {
        expect(isBlockedRpcHost('255.255.255.255'), isTrue);
      });

      test('allows public', () {
        expect(isBlockedRpcHost('8.8.8.8'), isFalse);
        expect(isBlockedRpcHost('1.1.1.1'), isFalse);
        expect(isBlockedRpcHost('142.250.190.46'), isFalse);
      });
    });

    group('IPv6', () {
      test('blocks loopback', () {
        expect(isBlockedRpcHost('::1'), isTrue);
      });

      test('blocks unspecified', () {
        expect(isBlockedRpcHost('::'), isTrue);
      });

      test('blocks ULA', () {
        expect(isBlockedRpcHost('fc00::'), isTrue);
        expect(
          isBlockedRpcHost('fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff'),
          isTrue,
        );
      });

      test('blocks link-local', () {
        expect(isBlockedRpcHost('fe80::'), isTrue);
        expect(
          isBlockedRpcHost('febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff'),
          isTrue,
        );
      });

      test('blocks IPv4-mapped blocked addresses', () {
        expect(isBlockedRpcHost('::ffff:127.0.0.1'), isTrue);
        expect(isBlockedRpcHost('::ffff:10.0.0.1'), isTrue);
        expect(isBlockedRpcHost('::ffff:192.168.1.1'), isTrue);
      });

      test('allows IPv4-mapped public addresses', () {
        expect(isBlockedRpcHost('::ffff:8.8.8.8'), isFalse);
      });

      test('allows public', () {
        expect(isBlockedRpcHost('2606:4700:4700::1111'), isFalse);
        expect(isBlockedRpcHost('2001:4860:4860::8888'), isFalse);
      });

      test('strips brackets correctly', () {
        expect(isBlockedRpcHost('[::1]'), isTrue);
        expect(isBlockedRpcHost('[2606:4700:4700::1111]'), isFalse);
      });
    });
  });

  group('validateCustomRpcUrl', () {
    test('returns error for null or empty input', () {
      expect(validateCustomRpcUrl(null), 'RPC URL is required.');
      expect(validateCustomRpcUrl(''), 'RPC URL is required.');
      expect(validateCustomRpcUrl('   '), 'RPC URL is required.');
    });

    test('returns error for invalid URIs', () {
      expect(validateCustomRpcUrl('not a url'), 'Enter a valid RPC URL.');
      expect(
        validateCustomRpcUrl('https:///no-host'),
        'Enter a valid RPC URL.',
      );
    });

    test('returns error for non-HTTPS schemes', () {
      expect(
        validateCustomRpcUrl('http://example.com'),
        'RPC URL must use https://.',
      );
      expect(
        validateCustomRpcUrl('wss://example.com'),
        'RPC URL must use https://.',
      );
      expect(
        validateCustomRpcUrl('ftp://example.com'),
        'RPC URL must use https://.',
      );
    });

    test('returns error for blocked hosts', () {
      expect(
        validateCustomRpcUrl('https://localhost'),
        'RPC host is not allowed (private or local address).',
      );
      expect(
        validateCustomRpcUrl('https://127.0.0.1'),
        'RPC host is not allowed (private or local address).',
      );
      expect(
        validateCustomRpcUrl('https://[::1]'),
        'RPC host is not allowed (private or local address).',
      );
      expect(
        validateCustomRpcUrl('https://192.168.1.100'),
        'RPC host is not allowed (private or local address).',
      );
    });

    test('returns null for valid public URLs', () {
      expect(validateCustomRpcUrl('https://example.com'), isNull);
      expect(validateCustomRpcUrl('https://api.mainnet.com/rpc'), isNull);
      expect(validateCustomRpcUrl('https://8.8.8.8'), isNull);
      expect(validateCustomRpcUrl('https://[2606:4700:4700::1111]'), isNull);
    });

    test('trims whitespace', () {
      expect(validateCustomRpcUrl('  https://example.com  '), isNull);
    });
  });
}
