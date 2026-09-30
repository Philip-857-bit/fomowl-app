import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/app_store_service.dart';

void main() {
  test('Google Play intent redirect preserves the affiliate referrer', () {
    final intent = Uri.parse(
      'intent://play.google.com/store/apps/details?id=com.fomowl.owllet'
      '&referrer=utm_source%3Dowllet%26affiliate_code%3DAB12CD'
      '#Intent;scheme=https;action=android.intent.action.VIEW;'
      'package=com.android.vending;end',
    );

    final resolved = AppStoreService.resolveOwlletStoreUrl(intent);

    expect(resolved?.scheme, 'https');
    expect(resolved?.host, 'play.google.com');
    expect(resolved?.fragment, isEmpty);
    expect(
      resolved?.queryParameters['referrer'],
      'utm_source=owllet&affiliate_code=AB12CD',
    );
  });

  test('only Owllet Play Store links may bypass Discover', () {
    expect(
      AppStoreService.resolveOwlletStoreUrl(
        Uri.parse(
          'https://play.google.com/store/apps/details?id=com.fomowl.owllet',
        ),
      ),
      isNotNull,
    );
    for (final url in <String>[
      'intent://play.google.com.evil.example/store/apps/details?id=com.fomowl.owllet#Intent;scheme=https;action=android.intent.action.VIEW;package=com.android.vending;end',
      'intent://play.google.com/store/apps/details?id=other.app#Intent;scheme=https;action=android.intent.action.VIEW;package=com.android.vending;end',
      'intent://play.google.com/store/apps/details?id=com.fomowl.owllet#Intent;scheme=https;action=android.intent.action.VIEW;package=other.app;end',
      'http://play.google.com/store/apps/details?id=com.fomowl.owllet',
    ]) {
      expect(AppStoreService.resolveOwlletStoreUrl(Uri.parse(url)), isNull);
    }
  });
}
