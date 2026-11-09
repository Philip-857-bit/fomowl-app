import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fomowl_wallet/services/blockchain/asset_chain_bridge_client.dart';

void main() {
  const testSecretKey = 'test_secret_key_12345';
  const testClientName = 'fomowl-adversarial-tester';
  const emptyHash =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  group('Adversarial Suite 1: Python Oracle Test Vector Cross-Validation', () {
    late List<Map<String, dynamic>> oracleVectors;

    setUpAll(() {
      final file = File('test/adversarial_vectors.json');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        oracleVectors = (jsonDecode(content) as List<dynamic>)
            .cast<Map<String, dynamic>>();
      } else {
        oracleVectors = [];
      }
    });

    test('Verify all 24 Python oracle test vectors match AssetChainApiGuardSigner', () {
      expect(oracleVectors, isNotEmpty, reason: 'adversarial_vectors.json must exist');
      for (final vec in oracleVectors) {
        final name = vec['name'] as String;
        final key = vec['key'] as String;
        final method = vec['method'] as String;
        final path = vec['path'] as String;
        final ts = vec['ts'] as String;
        final body = vec['body'] as String?;
        final expectedCanonical = vec['canonical'] as String;
        final expectedSig = vec['signature'] as String;

        final actualCanonical = AssetChainApiGuardSigner.buildCanonicalString(
          method: method,
          path: path,
          timestamp: ts,
          body: body,
        );

        expect(
          actualCanonical,
          expectedCanonical,
          reason: 'Canonical string mismatch on vector $name',
        );

        final actualSig = AssetChainApiGuardSigner.calculateSignature(
          canonicalString: actualCanonical,
          clientSecret: key,
        );

        expect(
          actualSig,
          expectedSig,
          reason: 'HMAC-SHA256 signature mismatch on vector $name',
        );
      }
    });
  });

  group('Adversarial Suite 2: Body Variations & UTF-8 Cryptographic Integrity', () {
    test('Null body and empty string body produce identical empty SHA-256 hash', () {
      final canonNull = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens',
        timestamp: '1710000000',
        body: null,
      );
      final canonEmpty = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens',
        timestamp: '1710000000',
        body: '',
      );

      expect(canonNull, contains(emptyHash));
      expect(canonEmpty, contains(emptyHash));
      expect(canonNull, equals(canonEmpty));

      final sigNull = AssetChainApiGuardSigner.calculateSignature(
        canonicalString: canonNull,
        clientSecret: testSecretKey,
      );
      final sigEmpty = AssetChainApiGuardSigner.calculateSignature(
        canonicalString: canonEmpty,
        clientSecret: testSecretKey,
      );
      expect(sigNull, equals(sigEmpty));
    });

    test('Whitespace-only body produces hash of spaces, NOT emptyBodySha256', () {
      final canonSpaces = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'POST',
        path: '/transactions',
        timestamp: '1710000100',
        body: '   ',
      );
      expect(canonSpaces.contains(emptyHash), isFalse);
    });

    test('Complex unicode multibyte strings retain canonical integrity', () {
      const unicodeBody = '{"name":"Owllet \u{1F989} \u{1F680} \u4E2D\u6587 \u20AC \u00A3 \u20BF"}';
      final canon = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'POST',
        path: '/transactions',
        timestamp: '1710000100',
        body: unicodeBody,
      );
      expect(canon.split('\n')[3].length, 64);

      final sig = AssetChainApiGuardSigner.calculateSignature(
        canonicalString: canon,
        clientSecret: testSecretKey,
      );
      expect(sig.length, 64);
    });

    test('Formatting whitespace differences alter body hash deterministically', () {
      const compactJson = '{"a":1,"b":2}';
      const spacedJson = '{\n  "a": 1,\n  "b": 2\n}';

      final canonCompact = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'POST',
        path: '/transactions',
        timestamp: '1710000100',
        body: compactJson,
      );
      final canonSpaced = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'POST',
        path: '/transactions',
        timestamp: '1710000100',
        body: spacedJson,
      );

      expect(canonCompact.split('\n')[3], isNot(equals(canonSpaced.split('\n')[3])));
    });
  });

  group('Adversarial Suite 3: Path and URL Canonicalization Stress', () {
    test('Query params with percent-encoded delimiters are cleanly stripped', () {
      final canon = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/transactions?user=0x1111&symbol=%23USDC%26more%3Dyes&nested=%2Fapi%2Fv1%3Fpage%3D2',
        timestamp: '1710000050',
      );
      expect(canon.split('\n')[1], '/transactions');
    });

    test('Multiple question marks in URL string are stripped from the first question mark', () {
      final canon = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens?a=1?b=2?c=3',
        timestamp: '1710000000',
      );
      expect(canon.split('\n')[1], '/tokens');
    });

    test('Empty path string normalizes to root slash /', () {
      final canon = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '',
        timestamp: '1710000000',
      );
      expect(canon.split('\n')[1], '/');
    });

    test('Path missing leading slash receives leading slash', () {
      final canon = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: 'blockchain/sign',
        timestamp: '1710000200',
      );
      expect(canon.split('\n')[1], '/blockchain/sign');
    });

    test('Trailing slash in path is preserved', () {
      final canon = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens/',
        timestamp: '1710000000',
      );
      expect(canon.split('\n')[1], '/tokens/');
    });

    test('Duplicate slashes behavior in canonical string', () {
      final canon = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '//tokens///list',
        timestamp: '1710000000',
      );
      expect(canon.split('\n')[1], '//tokens///list');
    });

    test('Hash anchor # in URL without query parameters vs with query parameters', () {
      final canonWithQuery = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens?user=1#anchor',
        timestamp: '1710000000',
      );
      expect(canonWithQuery.split('\n')[1], '/tokens');

      final canonDirectHash = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens#anchor',
        timestamp: '1710000000',
      );
      expect(canonDirectHash.split('\n')[1], '/tokens#anchor');
    });
  });

  group('Adversarial Suite 4: Method Normalization & Timestamp Formats', () {
    test('Case-insensitivity and whitespace trimming for HTTP methods', () {
      final methods = ['get', 'GET', 'Get', ' gEt ', 'POST', 'post', '  PoSt  ', 'PUT', 'put'];
      for (final m in methods) {
        final canon = AssetChainApiGuardSigner.buildCanonicalString(
          method: m,
          path: '/tokens',
          timestamp: '1710000000',
        );
        final normalizedMethod = canon.split('\n')[0];
        expect(normalizedMethod, m.trim().toUpperCase());
      }
    });

    test('Timestamp handling: epoch seconds, ms, and padded whitespace', () {
      final canonSec = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens',
        timestamp: '1710000000',
      );
      expect(canonSec.split('\n')[2], '1710000000');

      final canonMs = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens',
        timestamp: '1710000000000',
      );
      expect(canonMs.split('\n')[2], '1710000000000');

      final canonPadded = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens',
        timestamp: '   1710000000   ',
      );
      expect(canonPadded.split('\n')[2], '1710000000');
    });

    test('Header generator defaults to current epoch seconds when timestamp is omitted', () {
      final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final headers = AssetChainApiGuardSigner.generateHeaders(
        method: 'GET',
        path: '/tokens',
        clientName: testClientName,
        clientSecret: testSecretKey,
      );
      final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final ts = int.parse(headers['x-timestamp']!);
      expect(ts, greaterThanOrEqualTo(before));
      expect(ts, lessThanOrEqualTo(after));
      expect(headers['x-signature']!.length, 64);
    });
  });

  group('Adversarial Suite 5: Key Length Boundary & Character Extremes', () {
    test('Secret key with length > 64 bytes triggers HMAC SHA-256 key pre-hashing correctly', () {
      final longKey = 'K' * 128;
      final canon = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens',
        timestamp: '1710000000',
      );
      final sig = AssetChainApiGuardSigner.calculateSignature(
        canonicalString: canon,
        clientSecret: longKey,
      );
      expect(sig.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(sig), isTrue);
    });

    test('Empty secret key is processed without throwing', () {
      final canon = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens',
        timestamp: '1710000000',
      );
      final sig = AssetChainApiGuardSigner.calculateSignature(
        canonicalString: canon,
        clientSecret: '',
      );
      expect(sig, 'cafb80558a927fa8a2dcec3fd1b8e661ca5cc8bddee9578a50edd22088416679');
    });

    test('Unicode multibyte secret key generates valid hexadecimal signature', () {
      const unicodeKey = '密匙_🔑_secret';
      final canon = AssetChainApiGuardSigner.buildCanonicalString(
        method: 'GET',
        path: '/tokens',
        timestamp: '1710000000',
      );
      final sig = AssetChainApiGuardSigner.calculateSignature(
        canonicalString: canon,
        clientSecret: unicodeKey,
      );
      expect(sig, '2ccc951661fe772f52c75122ce22518ab3313dbb023d64c3a2ea0671c0fe5007');
    });
  });

  group('Adversarial Suite 6: HTTP Client Robustness Under Failure Conditions', () {
    test('HTTP 500 HTML error body is safely captured in exception message', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<html><body>500 Internal Server Error</body></html>', 500);
      });
      final client = AssetChainBridgeClient(
        baseUrl: 'https://bridge-testnet.assetchain.org',
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      try {
        await client.getTokens();
        fail('Expected AssetChainBridgeException');
      } on AssetChainBridgeException catch (e) {
        expect(e.statusCode, 500);
        expect(e.message, contains('500 Internal Server Error'));
        expect(e.isBadRequest, isFalse);
        expect(e.isUnauthorized, isFalse);
      }
    });

    test('HTTP 502 Bad Gateway with empty body produces HTTP 502 message', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 502);
      });
      final client = AssetChainBridgeClient(
        baseUrl: 'https://bridge-testnet.assetchain.org',
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      try {
        await client.getBridges();
        fail('Expected AssetChainBridgeException');
      } on AssetChainBridgeException catch (e) {
        expect(e.statusCode, 502);
        expect(e.message, 'HTTP 502');
      }
    });

    test('HTTP 404 Route Not Found has isNotFound == true', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Endpoint not found'}), 404);
      });
      final client = AssetChainBridgeClient(
        baseUrl: 'https://bridge-testnet.assetchain.org',
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      try {
        await client.getTokens();
        fail('Expected AssetChainBridgeException');
      } on AssetChainBridgeException catch (e) {
        expect(e.statusCode, 404);
        expect(e.isNotFound, isTrue);
      }
    });

    test('JSON array error response does not crash parser', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(['Error 1', 'Error 2']), 400);
      });
      final client = AssetChainBridgeClient(
        baseUrl: 'https://bridge-testnet.assetchain.org',
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      try {
        await client.getTokens();
        fail('Expected AssetChainBridgeException');
      } on AssetChainBridgeException catch (e) {
        expect(e.statusCode, 400);
        expect(e.isBadRequest, isTrue);
      }
    });

    test('BaseUrl with trailing slash does not cause double slash issues', () async {
      late http.Request captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'success': true, 'data': []}), 200);
      });

      final client = AssetChainBridgeClient(
        baseUrl: 'https://bridge-testnet.assetchain.org/',
        clientName: testClientName,
        clientSecret: testSecretKey,
        httpClient: mockClient,
      );

      await client.getTokens();
      expect(captured.url.path, '/tokens');
      expect(captured.headers['x-signature'], isNotEmpty);
    });
  });
}
