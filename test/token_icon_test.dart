import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
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

  testWidgets('native ETH on Robinhood shows a chain badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TokenIcon(tokenSymbol: 'ETH', chainId: 4663)),
    );

    expect(
      find.byKey(const ValueKey('token-chain-badge-4663')),
      findsOneWidget,
    );
  });

  testWidgets('native BNB on its L1 has no parent-chain badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TokenIcon(tokenSymbol: 'BNB', chainId: 56)),
    );

    expect(find.byKey(const ValueKey('token-chain-badge-56')), findsNothing);
  });
}
