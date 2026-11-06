import 'burst_api_client.dart';
import 'burst_draft_store.dart';

/// Restores the prepared response, or safely retries an unsent draft.
Future<Map<String, dynamic>> recoverBurstDraft({
  required Map<String, dynamic> saved,
  required BurstApiClient api,
  required BurstDraftStore store,
  required String profileId,
  required String wallet,
  required int chainId,
}) async {
  final stored = saved['prepared'];
  if (stored is Map) return Map<String, dynamic>.from(stored);
  final request = Map<String, dynamic>.from(saved['request'] as Map);
  try {
    return await api.prepare(request);
  } on BurstApiException catch (error) {
    // A 400 is returned before a campaign is created. Other failures may have
    // occurred after creation, so keep the idempotent request for recovery.
    if (error.statusCode == 400) {
      await store.clear(profileId, wallet, chainId);
    }
    rethrow;
  }
}
