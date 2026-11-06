import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'burst_sign_in.dart';

class BurstConnectionFailure implements Exception {
  const BurstConnectionFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// An in-memory credential that is revalidated against its parent account and
/// the backend before it is reused. It is never persisted or sent to a web app.
class BurstSessionSnapshot {
  BurstSessionSnapshot._(this._session, this._identity, this._parentToken);
  final Map<String, dynamic> _session;
  final BurstSignInIdentity _identity;
  final String? _parentToken;
}

/// Native holds the full account token. Only the server-issued Burst credential
/// is returned to JavaScript, with a fixed account and selected wallet.
class BurstAccountSessionService {
  BurstAccountSessionService({
    required this.client,
    required this.api,
    required this.readAccountToken,
    required this.readIdentity,
    required this.confirm,
    required this.authenticate,
    required this.signMessage,
  });

  final http.Client client;
  final Uri Function(String path) api;
  final Future<String?> Function() readAccountToken;
  final Future<BurstSignInIdentity> Function() readIdentity;
  final Future<bool> Function(String message, String address) confirm;
  final Future<bool> Function() authenticate;
  final Future<String> Function(String address, String message) signMessage;
  final BurstSignInController _signer = BurstSignInController();
  Map<String, dynamic>? _cached;
  BurstSignInIdentity? _identity;
  String? _parentToken;
  bool _busy = false;

  BurstSessionSnapshot? takeReusableSession() {
    final cached = _cached;
    final identity = _identity;
    final parent = _parentToken;
    if (_busy ||
        cached == null ||
        identity == null ||
        !_matches(cached, identity)) {
      return null;
    }
    final snapshot = BurstSessionSnapshot._(Map.of(cached), identity, parent);
    _cached = null;
    _identity = null;
    _parentToken = null;
    return snapshot;
  }

  void restoreReusableSession(BurstSessionSnapshot snapshot) {
    if (_busy || _cached != null) {
      throw StateError('Burst connection is in use.');
    }
    _cached = Map.of(snapshot._session);
    _identity = snapshot._identity;
    _parentToken = snapshot._parentToken;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    String? token, [
    Map<String, dynamic>? body,
  ]) async {
    final headers = {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    final response =
        await (method == 'POST'
                ? client.post(
                    api(path),
                    headers: headers,
                    body: jsonEncode(body),
                  )
                : method == 'DELETE'
                ? client.delete(api(path), headers: headers)
                : client.get(api(path), headers: headers))
            .timeout(const Duration(seconds: 20));
    Map<String, dynamic> value;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      value = decoded;
    } catch (_) {
      throw const BurstConnectionFailure(
        'BACKEND_UNAVAILABLE',
        'The Burst connection service is unavailable. Try again.',
      );
    }
    if (response.statusCode != 200) {
      throw BurstConnectionFailure(
        response.statusCode == 401 &&
                token != null &&
                token.isNotEmpty &&
                !token.startsWith('bs_')
            ? 'ACCOUNT_REQUIRED'
            : value['error'] is String
            ? value['error'] as String
            : 'CONNECTION_FAILED',
        value['message'] is String
            ? value['message'] as String
            : 'Unable to connect this wallet.',
      );
    }
    final data = value['success'] == true ? value['data'] : value;
    if (data is! Map<String, dynamic>) {
      throw const BurstConnectionFailure(
        'INVALID_SESSION',
        'Invalid Burst connection response.',
      );
    }
    return data;
  }

  bool _matches(Map<String, dynamic> session, BurstSignInIdentity identity) {
    final expiry = session['expiresAt'];
    final parsed = expiry is String ? DateTime.tryParse(expiry) : null;
    return (identity.profileId.isEmpty ||
            session['profileId'] == identity.profileId) &&
        session['address'] is String &&
        (session['address'] as String).toLowerCase() ==
            identity.address.toLowerCase() &&
        parsed != null &&
        parsed.isAfter(DateTime.now().toUtc());
  }

  Map<String, dynamic> _publicSession(Map<String, dynamic> session) => {
    'token': session['token'],
    'profileId': session['profileId'],
    'address': session['address'],
    'expiresAt': session['expiresAt'],
    if (session['linkedWallets'] is List)
      'linkedWallets': session['linkedWallets'],
  };

  Future<void> _requireCurrent(
    BurstSignInIdentity identity,
    String? accountToken,
  ) async {
    if (!identity.matches(await readIdentity()) ||
        accountToken != await readAccountToken()) {
      throw const BurstConnectionFailure(
        'CONTEXT_CHANGED',
        'Your account or wallet changed. Connect again.',
      );
    }
  }

  Future<Map<String, dynamic>> connect({bool interactive = false}) async {
    if (_busy) {
      throw const BurstConnectionFailure(
        'REQUEST_PENDING',
        'A wallet connection is already open.',
      );
    }
    _busy = true;
    try {
      final accountToken = await readAccountToken();
      final identity = await readIdentity();
      if (_cached != null &&
          (_identity == null ||
              !_identity!.matches(identity) ||
              _parentToken != accountToken ||
              !_matches(_cached!, identity))) {
        await _clear();
      }
      if (_cached != null) {
        try {
          final verified = await _request(
            'GET',
            '/burst/auth/session',
            _cached!['token'] as String,
          );
          if (!_matches(verified, identity)) {
            throw const BurstConnectionFailure(
              'INVALID_SESSION',
              'The wallet connection no longer matches your account.',
            );
          }
          await _requireCurrent(identity, accountToken);
          return _publicSession({...verified, 'token': _cached!['token']});
        } on BurstConnectionFailure catch (error) {
          await _clear();
          if (!{
            'BURST_CONNECTION_EXPIRED',
            'BURST_CONNECTION_REQUIRED',
            'INVALID_SESSION',
          }.contains(error.code)) {
            rethrow;
          }
        }
      }
      if (!interactive) {
        throw const BurstConnectionFailure(
          'CONNECTION_REQUIRED',
          'Connect a wallet to continue.',
        );
      }
      final challenge = await _request(
        'POST',
        '/burst/auth/challenge',
        accountToken,
        {'address': identity.address},
      );
      final challengeId = challenge['challengeId'];
      final message = challenge['message'];
      if ((identity.profileId.isNotEmpty &&
              challenge['profileId'] != identity.profileId) ||
          challenge['address'] != identity.address.toLowerCase() ||
          message is! String ||
          challengeId is! String ||
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(challengeId) ||
          !message.contains('\nChallenge: $challengeId\n')) {
        throw const BurstConnectionFailure(
          'INVALID_CHALLENGE',
          'The wallet connection challenge does not match your account.',
        );
      }
      await _requireCurrent(identity, accountToken);
      final signed = await _signer.sign(
        miniAppId: 'burst',
        payload: {'message': message, 'address': identity.address},
        readIdentity: readIdentity,
        confirm: confirm,
        authenticate: authenticate,
        signMessage: signMessage,
      );
      await _requireCurrent(identity, accountToken);
      final session = await _request(
        'POST',
        '/burst/auth/connect',
        accountToken,
        {
          'challengeId': challenge['challengeId'],
          'signature': signed['signature'],
        },
      );
      final token = session['token'];
      if (token is! String ||
          !RegExp(r'^bs_[0-9a-f]{64}$').hasMatch(token) ||
          !_matches(session, identity)) {
        throw const BurstConnectionFailure(
          'INVALID_SESSION',
          'The backend did not verify this account and wallet.',
        );
      }
      try {
        await _requireCurrent(identity, accountToken);
      } catch (_) {
        try {
          await _request('DELETE', '/burst/auth/session', token);
        } catch (_) {}
        rethrow;
      }
      _cached = _publicSession(session);
      _identity = identity;
      _parentToken = accountToken;
      return Map<String, dynamic>.from(_cached!);
    } finally {
      _busy = false;
    }
  }

  Future<void> _clear() async {
    final old = _cached;
    _cached = null;
    _identity = null;
    _parentToken = null;
    if (old?['token'] is String) {
      try {
        await _request(
          'DELETE',
          '/burst/auth/session',
          old!['token'] as String,
        );
      } catch (_) {
        /* The server also enforces the short expiry and parent logout. */
      }
    }
  }

  Future<void> disconnect() async {
    if (_busy) {
      throw const BurstConnectionFailure(
        'REQUEST_PENDING',
        'Wait for the current wallet connection to finish.',
      );
    }
    await _clear();
  }

  Future<http.Response> sendAuthorized(
    String walletAddress,
    Future<http.Response> Function(Map<String, String> headers) send,
    Map<String, String> headers,
  ) async {
    final session = await connect();
    if ((session['address'] as String).toLowerCase() !=
        walletAddress.toLowerCase()) {
      throw const BurstConnectionFailure(
        'CONTEXT_CHANGED',
        'Select the connected Burst wallet again.',
      );
    }
    final response = await send({
      ...headers,
      'Authorization': 'Bearer ${session['token']}',
    });
    if (response.statusCode == 401) await _clear();
    return response;
  }
}
