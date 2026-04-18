import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/app_environment.dart';
import '../../utils/app_error_utils.dart';

class AdminApiService {
  AdminApiService({required this.adminSecret, http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final String adminSecret;
  final http.Client _client;
  final bool _ownsClient;

  @visibleForTesting
  Map<String, String> buildHeaders({bool json = false}) {
    return {
      'X-Admin-Secret': adminSecret,
      if (json) 'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> fetchHealth() async {
    return _getMap(
      AppEnvironment.api('/health'),
      fallback: 'Unable to load backend health.',
    );
  }

  Future<Map<String, dynamic>> fetchStats(int chainId) async {
    return _getMap(
      AppEnvironment.blockchain('/$chainId/admin/stats'),
      fallback: 'Unable to load admin statistics.',
    );
  }

  Future<Map<String, dynamic>> fetchOps(int chainId) async {
    return _getMap(
      AppEnvironment.blockchain('/$chainId/admin/ops'),
      fallback: 'Unable to load operations overview.',
    );
  }

  Future<Map<String, dynamic>> fetchErrorLogs(
    int chainId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    return _getMap(
      AppEnvironment.blockchain('/$chainId/admin/errors', {
        'page': '$page',
        'pageSize': '$pageSize',
      }),
      fallback: 'Unable to load server error audit.',
    );
  }

  Future<Map<String, dynamic>> fetchFeedback(
    int chainId, {
    int page = 1,
    int pageSize = 25,
    String? walletAddress,
  }) async {
    final query = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
    final normalizedWallet = walletAddress?.trim();
    if (normalizedWallet != null && normalizedWallet.isNotEmpty) {
      query['walletAddress'] = normalizedWallet;
    }
    return _getMap(
      AppEnvironment.blockchain('/$chainId/admin/feedback', query),
      fallback: 'Unable to load feedback.',
    );
  }

  Future<String> exportFeedback(
    int chainId, {
    required String format,
    String? walletAddress,
  }) async {
    final query = <String, String>{'format': format, 'pageSize': '10000'};
    final normalizedWallet = walletAddress?.trim();
    if (normalizedWallet != null && normalizedWallet.isNotEmpty) {
      query['walletAddress'] = normalizedWallet;
    }
    final response = await _client.get(
      AppEnvironment.blockchain('/$chainId/admin/feedback', query),
      headers: buildHeaders(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to export feedback.',
        ),
      );
    }
    return response.body;
  }

  Future<List<Map<String, dynamic>>> fetchMaintainers(int chainId) async {
    final response = await _getMap(
      AppEnvironment.blockchain('/$chainId/admin/maintainers'),
      fallback: 'Unable to load maintainers.',
    );
    final maintainers = response['maintainers'];
    if (maintainers is List) {
      return maintainers
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addMaintainer(
    int chainId, {
    required String walletAddress,
    String? name,
  }) async {
    return _postMap(
      AppEnvironment.blockchain('/$chainId/admin/maintainers'),
      body: {
        'walletAddress': walletAddress.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
      fallback: 'Unable to add maintainer.',
    );
  }

  Future<Map<String, dynamic>> deactivateMaintainer(
    int chainId, {
    required String walletAddress,
  }) async {
    final response = await _client.delete(
      AppEnvironment.blockchain('/$chainId/admin/maintainers/$walletAddress'),
      headers: buildHeaders(),
    );
    return _decodeMapResponse(
      response,
      fallback: 'Unable to deactivate maintainer.',
    );
  }

  Future<Map<String, dynamic>> fetchRegistry(
    int chainId, {
    String? query,
    int page = 1,
    int pageSize = 40,
  }) async {
    final params = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
    final normalizedQuery = query?.trim();
    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      params['q'] = normalizedQuery;
    }
    return _getMap(
      AppEnvironment.blockchain('/$chainId/admin/registry', params),
      fallback: 'Unable to load token registry.',
    );
  }

  Future<Map<String, dynamic>> updateRegistryEntry(
    int chainId, {
    required String contractAddress,
    required bool isCertified,
    String? imageUrl,
  }) async {
    final response = await _client.patch(
      AppEnvironment.blockchain('/$chainId/admin/registry/$contractAddress'),
      headers: buildHeaders(json: true),
      body: jsonEncode({
        'isCertified': isCertified,
        if (imageUrl != null && imageUrl.trim().isNotEmpty)
          'imageUrl': imageUrl.trim(),
      }),
    );
    return _decodeMapResponse(
      response,
      fallback: 'Unable to update token registry.',
    );
  }

  Future<Map<String, dynamic>> sendBroadcast(
    int chainId, {
    required String title,
    required String message,
  }) async {
    return _postMap(
      AppEnvironment.blockchain('/$chainId/admin/broadcast'),
      body: {'title': title.trim(), 'message': message.trim()},
      fallback: 'Unable to broadcast push notification.',
    );
  }

  Future<Map<String, dynamic>> sendTestPush(
    int chainId, {
    required String walletAddress,
    required String title,
    required String message,
  }) async {
    return _postMap(
      AppEnvironment.blockchain('/$chainId/admin/actions/test-push'),
      body: {
        'walletAddress': walletAddress.trim(),
        'title': title.trim(),
        'message': message.trim(),
      },
      fallback: 'Unable to send test push.',
    );
  }

  Future<List<Map<String, dynamic>>> fetchDiscoverDapps() async {
    final response = await _getMap(
      AppEnvironment.discover('/admin/dapps'),
      fallback: 'Unable to load Discover DApps.',
    );
    final dapps = response['dapps'];
    if (dapps is List) {
      return dapps
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createDiscoverDapp({
    required Map<String, dynamic> payload,
  }) async {
    return _postMap(
      AppEnvironment.discover('/admin/dapps'),
      body: payload,
      fallback: 'Unable to create Discover DApp.',
    );
  }

  Future<Map<String, dynamic>> updateDiscoverDapp({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.patch(
      AppEnvironment.discover('/admin/dapps/$id'),
      headers: buildHeaders(json: true),
      body: jsonEncode(payload),
    );
    return _decodeMapResponse(
      response,
      fallback: 'Unable to update Discover DApp.',
    );
  }

  Future<Map<String, dynamic>> refreshDiscoverDappMetadata({
    required String id,
  }) async {
    return _postMap(
      AppEnvironment.discover('/admin/dapps/$id/refresh-metadata'),
      body: const <String, dynamic>{},
      fallback: 'Unable to refresh DApp metadata.',
    );
  }

  Future<AdminHomeBannerFeed> fetchHomeBanners() async {
    final response = await _getMap(
      AppEnvironment.content('/admin/home-banners'),
      fallback: 'Unable to load home promos.',
    );
    final banners = response['banners'];
    if (banners is List) {
      return AdminHomeBannerFeed(
        banners: banners
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList(),
        showFallbackSocialBanner: response['showFallbackSocialBanner'] != false,
      );
    }
    return AdminHomeBannerFeed(
      banners: const <Map<String, dynamic>>[],
      showFallbackSocialBanner: response['showFallbackSocialBanner'] != false,
    );
  }

  Future<Map<String, dynamic>> createHomeBanner({
    required Map<String, dynamic> payload,
  }) async {
    return _postMap(
      AppEnvironment.content('/admin/home-banners'),
      body: payload,
      fallback: 'Unable to create home promo.',
    );
  }

  Future<Map<String, dynamic>> updateHomeBanner({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.patch(
      AppEnvironment.content('/admin/home-banners/$id'),
      headers: buildHeaders(json: true),
      body: jsonEncode(payload),
    );
    return _decodeMapResponse(
      response,
      fallback: 'Unable to update home promo.',
    );
  }

  Future<Map<String, dynamic>> updateHomeBannerSettings({
    required bool showFallbackSocialBanner,
  }) async {
    return _postPatchMap(
      AppEnvironment.content('/admin/home-banners/settings'),
      body: {'showFallbackSocialBanner': showFallbackSocialBanner},
      fallback: 'Unable to update home promo settings.',
    );
  }

  Future<Map<String, dynamic>> uploadHomeBannerImage({
    required List<int> bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      AppEnvironment.content('/admin/home-banners/upload'),
    );
    request.headers.addAll(buildHeaders());
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _decodeMapResponse(
      response,
      fallback: 'Unable to upload home promo image.',
    );
  }

  Future<Map<String, dynamic>> _getMap(
    Uri uri, {
    required String fallback,
  }) async {
    final response = await _client.get(uri, headers: buildHeaders());
    return _decodeMapResponse(response, fallback: fallback);
  }

  Future<Map<String, dynamic>> _postMap(
    Uri uri, {
    required Map<String, dynamic> body,
    required String fallback,
  }) async {
    final response = await _client.post(
      uri,
      headers: buildHeaders(json: true),
      body: jsonEncode(body),
    );
    return _decodeMapResponse(response, fallback: fallback);
  }

  Future<Map<String, dynamic>> _postPatchMap(
    Uri uri, {
    required Map<String, dynamic> body,
    required String fallback,
  }) async {
    final response = await _client.patch(
      uri,
      headers: buildHeaders(json: true),
      body: jsonEncode(body),
    );
    return _decodeMapResponse(response, fallback: fallback);
  }

  Map<String, dynamic> _decodeMapResponse(
    http.Response response, {
    required String fallback,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        AppErrorUtils.backendMessage(response.body, fallback: fallback),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception(fallback);
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

class AdminHomeBannerFeed {
  const AdminHomeBannerFeed({
    required this.banners,
    required this.showFallbackSocialBanner,
  });

  final List<Map<String, dynamic>> banners;
  final bool showFallbackSocialBanner;
}
