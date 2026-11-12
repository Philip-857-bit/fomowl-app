import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../mini_apps/burst_account_session.dart';

/// An authenticated request is supplied by the native wallet session. The
/// account credential and wallet signing remain outside the API client.
typedef BurstAuthorizedRequest =
    Future<http.Response> Function(http.Request request);

class BurstApiException implements Exception {
  const BurstApiException(this.message, {this.code, this.statusCode});
  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class BurstApiClient {
  BurstApiClient({
    required this.api,
    required this.client,
    required this.authorize,
  });

  /// Resolves paths against Owllet's configured backend API, including /api.
  final Uri Function(String path) api;
  final http.Client client;
  final BurstAuthorizedRequest authorize;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Map<String, String>? queryParameters,
  }) async {
    final base = api('/burst$path');
    final request = http.Request(
      method,
      queryParameters == null
          ? base
          : base.replace(queryParameters: queryParameters),
    );
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response =
          await (authenticated
                  ? authorize(request)
                  : client.send(request).then(http.Response.fromStream))
              .timeout(const Duration(seconds: 20));
    } on BurstConnectionFailure catch (error) {
      throw BurstApiException(error.message, code: error.code);
    } on TimeoutException {
      throw const BurstApiException('Unable to reach Burst. Try again.');
    } on http.ClientException {
      throw const BurstApiException('Unable to reach Burst. Try again.');
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw BurstApiException(
        'Burst returned an invalid response.',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw BurstApiException(
        'Burst returned an invalid response.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] == false) {
      throw BurstApiException(
        decoded['message'] is String
            ? decoded['message'] as String
            : 'Unable to complete the Burst request.',
        code: decoded['error'] is String ? decoded['error'] as String : null,
        statusCode: response.statusCode,
      );
    }
    final data = decoded['success'] == true ? decoded['data'] : decoded;
    if (data is! Map<String, dynamic>) {
      throw const BurstApiException('Burst returned an invalid response.');
    }
    return data;
  }

  Future<Map<String, dynamic>> config(int chainId, {bool recovery = false}) =>
      _request(
        'GET',
        '/config',
        authenticated: false,
        queryParameters: {'chainId': '$chainId', if (recovery) 'recovery': '1'},
      );

  Future<Map<String, dynamic>> networks() =>
      _request('GET', '/networks', authenticated: false);

  Future<Map<String, dynamic>> campaigns() => _request('GET', '/campaigns');
  Future<Map<String, dynamic>> participations() =>
      _request('GET', '/participations');
  Future<Map<String, dynamic>> participation(String id) =>
      _request('GET', '/participations/${Uri.encodeComponent(id)}');
  Future<Map<String, dynamic>> leave(String id) =>
      _request('DELETE', '/participations/${Uri.encodeComponent(id)}');
  Future<Map<String, dynamic>> campaign(String id) =>
      _request('GET', '/campaigns/${Uri.encodeComponent(id)}');
  Future<Map<String, dynamic>> campaignCode(String id) =>
      _request('GET', '/campaigns/${Uri.encodeComponent(id)}/code');
  Future<Map<String, dynamic>> deleteCampaign(String id) =>
      _request('DELETE', '/campaigns/${Uri.encodeComponent(id)}');
  Future<Map<String, dynamic>> prepare(Map<String, dynamic> draft) =>
      _request('POST', '/campaigns/prepare', body: draft);
  Future<Map<String, dynamic>> draft(String id) =>
      _request('GET', '/campaigns/${Uri.encodeComponent(id)}/draft');
  Future<Map<String, dynamic>> updateDraft(
    String id,
    Map<String, dynamic> body,
  ) => _request(
    'PUT',
    '/campaigns/${Uri.encodeComponent(id)}/draft',
    body: body,
  );
  Future<void> beginExecution(String reference) async {
    final result = await _request(
      'POST',
      '/transactions/${Uri.encodeComponent(reference)}/begin',
    );
    if (result['locked'] != true) {
      throw StateError(
        'Unable to lock this Burst before submission. Try again.',
      );
    }
  }

  Future<Map<String, dynamic>> previewJoin(String code) =>
      _request('GET', '/join/${Uri.encodeComponent(code)}');
  Future<Map<String, dynamic>> join(String code) =>
      _request('POST', '/join/${Uri.encodeComponent(code)}');
  Future<Map<String, dynamic>> finalize(String id) =>
      _request('POST', '/campaigns/${Uri.encodeComponent(id)}/finalize');
  Future<Map<String, dynamic>> prepareRecovery(String id, String action) =>
      _request(
        'POST',
        '/campaigns/${Uri.encodeComponent(id)}/recovery',
        body: {'action': action},
      );
  Future<Map<String, dynamic>> proof(String id) =>
      _request('GET', '/campaigns/${Uri.encodeComponent(id)}/proof');
  Future<Map<String, dynamic>> claim(String id) =>
      _request('POST', '/campaigns/${Uri.encodeComponent(id)}/claim');
  Future<Map<String, dynamic>> saveMessage(String id, String message) =>
      _request(
        'PUT',
        '/campaigns/${Uri.encodeComponent(id)}/message',
        body: {'message': message},
      );
  Future<Map<String, dynamic>> messages(String id, {String? after}) => _request(
    'GET',
    '/campaigns/${Uri.encodeComponent(id)}/messages',
    queryParameters: after == null ? null : {'after': after},
  );
  Future<Map<String, dynamic>> execution(String reference) => _request(
    'GET',
    '/transactions/${Uri.encodeComponent(reference)}/execution',
  );
  Future<Map<String, dynamic>> recordTransaction(
    String campaignId,
    String operation,
    bool confirm,
    Map<String, dynamic> data,
  ) => _request(
    'POST',
    '/campaigns/${Uri.encodeComponent(campaignId)}/transactions/'
        '${Uri.encodeComponent(operation)}/${confirm ? 'confirm' : 'submit'}',
    body: data,
  );
}
