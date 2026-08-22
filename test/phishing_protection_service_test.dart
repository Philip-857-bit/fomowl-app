import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/security/phishing_protection_service.dart';

void main() {
  group('PhishingProtectionService Tests', () {
    final service = PhishingProtectionService.instance;

    test('Allows safe official dApps', () {
      final uniswap = service.checkUri(Uri.parse('https://app.uniswap.org'));
      expect(uniswap.isBlocked, isFalse);

      final jupiter = service.checkUri(Uri.parse('https://jup.ag'));
      expect(jupiter.isBlocked, isFalse);

      final pancake = service.checkUri(
        Uri.parse('https://pancakeswap.finance'),
      );
      expect(pancake.isBlocked, isFalse);

      final openSea = service.checkUri(Uri.parse('https://opensea.io'));
      expect(openSea.isBlocked, isFalse);

      final fomowl = service.checkUri(Uri.parse('https://owlletapp.com'));
      expect(fomowl.isBlocked, isFalse);
    });

    test('Blocks known malicious drainer domains', () {
      final drainer = service.checkUri(
        Uri.parse('https://airdrop-claim-portal.com'),
      );
      expect(drainer.isBlocked, isTrue);
      expect(drainer.threatCategory, 'Malicious Drainer');

      final metamaskScam = service.checkUri(
        Uri.parse('https://metamask-security-update.com'),
      );
      expect(metamaskScam.isBlocked, isTrue);
    });

    test('Blocks homoglyph / Cyrillic lookalike attacks', () {
      // Punycode "xn--"
      final punycode = service.checkUri(
        Uri.parse('https://xn--uniswp-e1a.org'),
      );
      expect(punycode.isBlocked, isTrue);
      expect(punycode.threatCategory, 'Homograph Phishing Attack');

      // Unicode Cyrillic 'а' replacing Latin 'a'
      final cyrillicAttack = service.checkUri(
        Uri.parse('https://pаncakeswap.finance'),
      );
      expect(cyrillicAttack.isBlocked, isTrue);
    });

    test('Blocks brand typosquatting & scam keyword combos', () {
      final airdropScam = service.checkUri(
        Uri.parse('https://uniswap-airdrop-rewards.com'),
      );
      expect(airdropScam.isBlocked, isTrue);
      expect(airdropScam.targetedBrand, 'uniswap');

      final jupClaim = service.checkUri(
        Uri.parse('https://jupiter-claim-airdrop.net'),
      );
      expect(jupClaim.isBlocked, isTrue);
      expect(jupClaim.targetedBrand, 'jupiter');

      final typosquat = service.checkUri(Uri.parse('https://un1swap.org'));
      expect(typosquat.isBlocked, isTrue);
      expect(typosquat.threatCategory, 'Typosquatting Phishing');
    });
  });
}
