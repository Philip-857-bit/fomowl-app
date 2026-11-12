# Editable Burst drafts

Implement the draft editing flow approved in conversation: reopen saved fields before any submission; refresh fees and transaction plans after edits; preserve recovery once submission begins.

## Approach

Update the existing backend campaign atomically rather than delete and create from the app. This preserves the Burst entry and prevents partial replacements or duplicate campaigns on retries. Purely local editing cannot invalidate server transaction plans safely. Creating a replacement campaign would change identity unnecessarily.

## Contract

- GET `/burst/campaigns/{id}/draft` returns `{request, prepared, editable}` for the authenticated creator wallet. Reconstruct the original request and NFT allocations from stored data.
- PUT on the same path accepts the full prepare request plus `previousIdempotencyKey`. It keeps the campaign database ID, validates through existing preparation rules, refreshes fee quotes, regenerates plans and on-chain salt, and invalidates old references atomically. Same new key and body retries return the same prepared response. Stale revisions conflict.
- POST `/burst/transactions/{reference}/begin` locks campaign editing before broadcast, without marking a transaction as broadcast. Retry is safe; recovery remains available. The backend rejects editing/deletion once locked, submitted, confirmed, or otherwise uncertain.
- App opens drafts in the existing creation form with fields restored; saving calls PUT and opens confirmation. Pending submissions continue to recovery, including journal records with unknown broadcast outcomes.
- Preserve existing local recovery data until replacement succeeds; persist update requests before sending so timeouts can retry without duplicating work. Validation failures leave the previous draft intact.
- Existing non-native assets must restore by address and decimals; unavailable assets are shown as unavailable instead of silently changing the selected asset. Restore NFT allocations and revalidate current ownership before preparation.
- No deployment, commits, or live financial transactions are part of this task.

## Verification

Backend tests cover owner/wallet/network boundaries, stale edits, idempotency, regenerated plans, lock/edit ordering and unchanged old drafts after failure. Flutter tests cover restored fields, edited requests, preserved recovery on failures, and submission locking.
