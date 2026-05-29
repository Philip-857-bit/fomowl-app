import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/utils/rpc_url_validator.dart';

void main() {
  group('isBlockedRpcHost', () {
    test('blocks loopback, private, link-local, CGNAT and internal hosts', () {
      for (final host in [
        'localhost',
        'foo.localhost',
        'service.internal',
        'printer.local',
        '127.0.0.1',
        '10.0.0.5',
        '172.16.4.2',
        '172.31.255.255',
        '192.168.1.1',
        '169.254.169.254',
        '100.64.0.1',
        '0.0.0.0',
        '255.255.255.255',
        '::1',
        'fd00::1',
        'fe80::1',
        '[::1]',
        '::ffff:127.0.0.1',
        '::ffff:192.168.0.1',
      ]) {
        expect(isBlockedRpcHost(host), isTrue, reason: 'should block $host');
      }
    });

    test('allows public hosts and public IPs', () {
      for (final host in [
        'eth.llamarpc.com',
        'mainnet.infura.io',
        'bsc-dataseed.binance.org',
        '1.1.1.1',
        '8.8.8.8',
        '172.32.0.1', // just outside 172.16/12
      ]) {
        expect(isBlockedRpcHost(host), isFalse, reason: 'should allow $host');
      }
    });
  });

  group('validateCustomRpcUrl', () {
    test('accepts a well-formed public https URL', () {
      expect(validateCustomRpcUrl('https://eth.llamarpc.com'), isNull);
      expect(validateCustomRpcUrl('https://rpc.ankr.com/eth/abc123'), isNull);
    });

    test('rejects empty, non-https, malformed and private hosts', () {
      expect(validateCustomRpcUrl(''), isNotNull);
      expect(validateCustomRpcUrl('   '), isNotNull);
      expect(validateCustomRpcUrl('http://eth.llamarpc.com'), isNotNull);
      expect(validateCustomRpcUrl('ftp://eth.llamarpc.com'), isNotNull);
      expect(validateCustomRpcUrl('not a url'), isNotNull);
      expect(validateCustomRpcUrl('https://'), isNotNull);
      expect(validateCustomRpcUrl('https://127.0.0.1:8545'), isNotNull);
      expect(validateCustomRpcUrl('https://192.168.1.10:8545'), isNotNull);
      expect(validateCustomRpcUrl('https://localhost:8545'), isNotNull);
    });
  });
}
