# Burst draft editing

Drafts reopen the existing Burst creation form with saved token or NFT allocations. `Review Burst` saves the edited draft and obtains new unsigned transaction plans and fee quotes before showing confirmation. Dismissing confirmation or selecting `Edit draft` returns to the form if submission has not begun. Leaving unsaved changes requires confirmation.

The app retains the previous prepared response and an exact pending update request until the server confirms a replacement. After an interrupted save, Review retries the same update key and body. A stale revision asks the user to close and reopen the draft. Missing tokens or changed token decimals require selecting an available asset; they never silently change the distribution amount.

After approval, the executor locks the current backend transaction reference before writing its local broadcast marker and broadcasting. Locked, submitted, confirmed, and unknown submission outcomes use recovery instead of editing. The backend validates creator profile, wallet, revision, and transaction state atomically. Historical request keys remain reserved so delayed prepare retries cannot recreate a superseded or deleted draft.

## Rollout

1. Deploy the sibling `backend` changes with migration `20261112010000_burst_draft_idempotency_keys.sql`. The migration backfills current request keys; existing campaigns remain readable.
2. Release the Flutter app after the updated backend is available. This app requires the new begin endpoint before broadcasting a new Burst transaction; it fails without broadcasting if the endpoint is unavailable.
3. Verify on a test wallet: create and dismiss confirmation; reopen and edit the amount/guests; save; check fees; delete an unsent draft; interrupt a save and retry; start submission and confirm that subsequent opens use recovery.

No deployment or live transaction is performed by the implementation task. Old signed transactions cannot be revoked by an API update; clients must use the reference lock and existing refreshed-plan checks before broadcast.

## API

- `GET /api/burst/campaigns/{id}/draft` returns `{request, prepared, editable}`.
- `PUT /api/burst/campaigns/{id}/draft` accepts the full prepare request plus `previousIdempotencyKey`, and returns the new prepared envelope. A new `idempotencyKey` identifies each edit; repeated identical saves return the same preparation while that revision remains current. Superseded keys return a conflict.
- `POST /api/burst/transactions/{reference}/begin` returns `{locked: true}` when the exact current reference is reserved against edits.
