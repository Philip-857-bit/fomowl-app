import 'dart:async';

import 'package:http/http.dart' as http;

import '../mini_apps/burst_account_session.dart';
import '../mini_apps/burst_sign_in.dart';
import 'burst_api_client.dart';

/// Holds the account-bound session in native memory and binds every request to
/// the wallet that opened the feature. A wallet switch requires a new session.
class BurstNativeSession {
  BurstNativeSession({
    required this.client,
    required this.api,
    required this.readAccountToken,
    required this.readIdentity,
    required Future<bool> Function(String message, String address) confirm,
    required Future<bool> Function() authenticate,
    required Future<String> Function(String address, String message)
    signMessage,
  }) {
    _connection = BurstAccountSessionService(
      client: client,
      api: api,
      readAccountToken: readAccountToken,
      readIdentity: readIdentity,
      confirm: confirm,
      authenticate: authenticate,
      signMessage: signMessage,
    );
    final reusable = _reusable;
    _reusable = null;
    if (reusable != null) _connection.restoreReusableSession(reusable);
  }

  static BurstSessionSnapshot? _reusable;

  final http.Client client;
  final Uri Function(String path) api;
  final Future<String?> Function() readAccountToken;
  final Future<BurstSignInIdentity> Function() readIdentity;
  late final BurstAccountSessionService _connection;
  BurstSignInIdentity? _openedIdentity;
  Future<BurstApiClient>? _opening;
  bool _closed = false;
  bool _revocationRequested = false;
  int _activeRequests = 0;
  Completer<void>? _drained;

  Future<BurstApiClient> open() {
    if (_closed) throw StateError('Burst was closed.');
    final current = _opening;
    if (current != null) return current;
    final pending = _open();
    _opening = pending;
    return pending.whenComplete(() {
      if (identical(_opening, pending)) _opening = null;
    });
  }

  Future<BurstApiClient> _open() async {
    final identity = await readIdentity();
    if (_closed) throw StateError('Burst was closed.');
    await _connection.connect(interactive: true);
    if (_closed) {
      await _connection.disconnect();
      throw StateError('Burst was closed.');
    }
    final currentIdentity = await readIdentity();
    if (_closed || !identity.matches(currentIdentity)) {
      await _connection.disconnect();
      throw const BurstConnectionFailure(
        'CONTEXT_CHANGED',
        'Your wallet or network changed. Open Burst again.',
      );
    }
    _openedIdentity = identity;
    return BurstApiClient(api: api, client: client, authorize: _authorize);
  }

  Future<http.Response> _authorize(http.Request request) async {
    if (_closed) throw StateError('Burst was closed.');
    _activeRequests++;
    try {
      final identity = _openedIdentity;
      if (identity == null ||
          !identity.matches(await readIdentity()) ||
          _closed) {
        throw const BurstConnectionFailure(
          'CONTEXT_CHANGED',
          'Your wallet or network changed. Open Burst again.',
        );
      }
      return await _connection.sendAuthorized(identity.address, (
        headers,
      ) async {
        if (!identity.matches(await readIdentity()) || _closed) {
          throw const BurstConnectionFailure(
            'CONTEXT_CHANGED',
            'Your wallet or network changed. Open Burst again.',
          );
        }
        request.headers.addAll(headers);
        return http.Response.fromStream(await client.send(request));
      }, request.headers);
    } finally {
      _activeRequests--;
      if (_activeRequests == 0 && _drained != null) {
        _drained!.complete();
        _drained = null;
      }
    }
  }

  Future<void> close({bool retainForReuse = false}) async {
    if (!retainForReuse) _revocationRequested = true;
    _closed = true;
    _openedIdentity = null;
    final pending = _opening;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // A failed opening may still need its connection cleared.
      }
    }
    if (_activeRequests > 0) {
      _drained ??= Completer<void>();
      await _drained!.future;
    }
    _openedIdentity = null;
    if (retainForReuse && !_revocationRequested && pending == null) {
      final reusable = _connection.takeReusableSession();
      if (reusable != null) {
        _reusable = reusable;
        return;
      }
    }
    await _connection.disconnect();
  }
}
