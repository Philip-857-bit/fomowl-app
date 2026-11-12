import 'burst_api_client.dart';
import 'burst_draft_store.dart';

/// Retains both the previous recovery record and an exact uncertain edit retry.
class BurstDraftEditor {
  const BurstDraftEditor({
    required this.api,
    required this.store,
    required this.profileId,
    required this.wallet,
    required this.chainId,
    required this.validate,
  });

  final BurstApiClient api;
  final BurstDraftStore store;
  final String profileId;
  final String wallet;
  final int chainId;
  final void Function(
    Map<String, dynamic> prepared,
    Map<String, dynamic> request,
  )
  validate;

  Future<Map<String, dynamic>> update({
    required Map<String, dynamic> saved,
    required Map<String, dynamic> request,
  }) async {
    final campaign = (saved['prepared'] as Map)['campaign'] as Map;
    final id = campaign['id'] as String;
    final pending = saved['pendingUpdate'];
    final body = pending is Map
        ? Map<String, dynamic>.from(pending)
        : <String, dynamic>{
            ...request,
            'previousIdempotencyKey':
                (saved['request'] as Map)['idempotencyKey'],
          };
    final nextRequest = Map<String, dynamic>.from(body)
      ..remove('previousIdempotencyKey');
    await store.write(profileId, wallet, chainId, {
      ...saved,
      'pendingUpdate': body,
    });
    final Map<String, dynamic> prepared;
    try {
      prepared = await api.updateDraft(id, body);
    } on BurstApiException catch (error) {
      // These responses definitively reject the edit. Timeouts and server
      // failures retain the exact key/body until the outcome is resolved.
      if (error.statusCode == 400 || error.statusCode == 409) {
        await store.write(
          profileId,
          wallet,
          chainId,
          Map<String, dynamic>.from(saved)..remove('pendingUpdate'),
        );
      }
      rethrow;
    }
    if ((prepared['campaign'] as Map?)?['id'] != id) {
      throw const FormatException('The updated Burst identity changed.');
    }
    validate(prepared, nextRequest);
    await store.write(profileId, wallet, chainId, {
      'request': nextRequest,
      'prepared': prepared,
    });
    return prepared;
  }
}
