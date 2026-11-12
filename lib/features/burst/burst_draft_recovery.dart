import 'burst_api_client.dart';
import 'burst_draft_store.dart';

/// Prune drafts only when the backend confirms the campaign was removed.
/// A timeout, pause, or authentication failure must not discard recovery data.
Future<Map<String, dynamic>?> readRecoverableBurstDraft({
  required BurstApiClient api,
  required BurstDraftStore store,
  required String profileId,
  required String wallet,
  required int chainId,
}) async {
  final saved = await store.read(profileId, wallet, chainId);
  final prepared = saved?['prepared'];
  final campaign = prepared is Map ? prepared['campaign'] : null;
  final id = campaign is Map ? campaign['id'] : null;
  if (id is! String || id.isEmpty) return saved;
  try {
    await api.campaign(id);
  } on BurstApiException catch (error) {
    if (error.statusCode == 404 || error.statusCode == 410) {
      await store.clearCampaign(profileId, wallet, chainId, id);
      return null;
    }
  } catch (_) {
    // Keep local recovery available while the backend cannot be reached.
  }
  return saved;
}

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
