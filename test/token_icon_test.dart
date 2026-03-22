import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/widgets/token_icon.dart';

void main() {
  group('TokenIcon URL normalization', () {
    test('keeps https urls unchanged', () {
      expect(
        TokenIcon.normalizeNetworkImageUrl('https://example.com/logo.png'),
        'https://example.com/logo.png',
      );
    });

    test('normalizes ipfs urls to https gateway urls', () {
      expect(
        TokenIcon.normalizeNetworkImageUrl('ipfs://QmTokenLogoHash'),
        'https://ipfs.io/ipfs/QmTokenLogoHash',
      );
      expect(
        TokenIcon.normalizeNetworkImageUrl('ipfs://ipfs/QmTokenLogoHash'),
        'https://ipfs.io/ipfs/QmTokenLogoHash',
      );
    });

    test('normalizes scheme-relative urls to https', () {
      expect(
        TokenIcon.normalizeNetworkImageUrl('//cdn.example.com/logo.png'),
        'https://cdn.example.com/logo.png',
      );
    });
  });
}
