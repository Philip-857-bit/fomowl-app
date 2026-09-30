import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

class AppStoreService {
  AppStoreService({InAppReview? inAppReview})
    : _inAppReview = inAppReview ?? InAppReview.instance;

  static const String androidPackageId = 'com.fomowl.owllet';
  static final Uri _playStoreMarketUri = Uri.parse(
    'market://details?id=$androidPackageId',
  );
  static final Uri _playStoreWebUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=$androidPackageId',
  );

  /// Resolve Owllet's own Play Store listing, including the intent redirect
  /// emitted by Google Play when its page is opened inside a WebView.
  static Uri? resolveOwlletStoreUrl(Uri uri) {
    if (uri.host.toLowerCase() != 'play.google.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.path != '/store/apps/details' ||
        uri.queryParameters['id'] != androidPackageId) {
      return null;
    }
    if (uri.scheme == 'https') return uri;
    if (uri.scheme != 'intent') return null;

    final intentParts = uri.fragment.split(';');
    if (intentParts.first != 'Intent' ||
        intentParts.last != 'end' ||
        !intentParts.contains('scheme=https') ||
        !intentParts.contains('action=android.intent.action.VIEW') ||
        !intentParts.contains('package=com.android.vending')) {
      return null;
    }
    return uri.replace(scheme: 'https', fragment: '');
  }

  final InAppReview _inAppReview;

  Future<void> requestReviewOrOpenStore() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        return;
      }
    } catch (_) {
      // In-app review can be quota-limited or unavailable. Fall back quietly.
    }
    await openStoreListing();
  }

  Future<void> openStoreListing() async {
    try {
      if (await launchUrl(_playStoreMarketUri)) {
        return;
      }
    } catch (_) {}
    await launchUrl(_playStoreWebUri, mode: LaunchMode.externalApplication);
  }
}
