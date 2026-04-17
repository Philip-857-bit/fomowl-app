import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_environment.dart';
import '../../utils/app_error_utils.dart';
import 'home_banner_item.dart';

class HomeBannerService {
  HomeBannerService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  Future<List<HomeBannerItem>> fetchHomeBanners() async {
    final response = await _client.get(AppEnvironment.content('/home-banners'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        AppErrorUtils.backendMessage(
          response.body,
          fallback: 'Unable to load home promotions.',
        ),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const <HomeBannerItem>[];
    }
    final items = decoded['banners'];
    if (items is! List) {
      return const <HomeBannerItem>[];
    }

    return items
        .whereType<Map>()
        .map((item) => HomeBannerItem.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
