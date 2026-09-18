import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/affiliate_attribution_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses Play Store referrer campaign as an affiliate code', () {
    const referrer =
        'utm_source=owllet&utm_medium=affiliate&utm_campaign=AB12CD&affiliate_code=AB12CD';
    expect(
      AffiliateAttributionService.parseCodeFromReferrer(referrer),
      'AB12CD',
    );
  });

  test('parses encoded Play Store referrer strings', () {
    const encoded =
        'utm_source%3Dowllet%26utm_medium%3Daffiliate%26utm_campaign%3DZX9K2P%26affiliate_code%3DZX9K2P';
    expect(
      AffiliateAttributionService.parseCodeFromReferrer(encoded),
      'ZX9K2P',
    );
  });

  test('ignores organic Play referrers and campaign-only noise', () {
    expect(
      AffiliateAttributionService.parseCodeFromReferrer(
        'utm_source=google-play&utm_medium=organic',
      ),
      isNull,
    );
    expect(
      AffiliateAttributionService.parseCodeFromReferrer(
        'utm_source=owllet&utm_campaign=AB12CD',
      ),
      isNull,
    );
  });

  test('parses owllet deep links and rejects malformed codes', () {
    expect(
      AffiliateAttributionService.parseCodeFromUri(
        Uri.parse('owllet://r/AB12CD'),
      ),
      'AB12CD',
    );
    expect(
      AffiliateAttributionService.parseCodeFromUri(
        Uri.parse('https://affiliates.owlletapp.com/r/AB12CD'),
      ),
      'AB12CD',
    );
    expect(AffiliateAttributionService.normalizeCode('ab'), isNull);
    expect(AffiliateAttributionService.normalizeCode('DROP TABLE'), isNull);
    expect(
      AffiliateAttributionService.parseCodeFromUri(
        Uri.parse('https://example.com/?ref=NEWS'),
      ),
      isNull,
    );
    expect(
      AffiliateAttributionService.parseCodeFromUri(
        Uri.parse('https://example.com/r/AB12CD'),
      ),
      isNull,
    );
  });

  test('does not consume an empty Play referrer', () async {
    SharedPreferences.setMockInitialValues({});
    await AffiliateAttributionService.instance.captureInstallReferrer(
      readReferrer: () async => '',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('owllet.install_referrer_consumed.v1'), isNot(true));
  });

  test('first stored affiliate code is not overwritten by a later link', () async {
    SharedPreferences.setMockInitialValues({});
    await AffiliateAttributionService.instance.rememberCode('QZ84KM');
    await AffiliateAttributionService.instance.rememberCode('OTHER1');
    expect(await AffiliateAttributionService.instance.pendingCode(), 'QZ84KM');
  });

  test('does not consume a failed Play referrer read', () async {
    SharedPreferences.setMockInitialValues({});
    await AffiliateAttributionService.instance.captureInstallReferrer(
      readReferrer: () async => throw Exception('play unavailable'),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('owllet.install_referrer_consumed.v1'), isNot(true));
  });

  test('stores a successful Play referrer once', () async {
    SharedPreferences.setMockInitialValues({});
    await AffiliateAttributionService.instance.captureInstallReferrer(
      readReferrer: () async =>
          'utm_source=owllet&utm_medium=affiliate&affiliate_code=QZ84KM',
    );
    expect(await AffiliateAttributionService.instance.pendingCode(), 'QZ84KM');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('owllet.install_referrer_consumed.v1'), isTrue);

    await AffiliateAttributionService.instance.captureInstallReferrer(
      readReferrer: () async => 'affiliate_code=OTHER1',
    );
    expect(await AffiliateAttributionService.instance.pendingCode(), 'QZ84KM');
  });
}
