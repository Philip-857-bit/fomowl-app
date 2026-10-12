# Transaction infrastructure implementation

Specification: user roadmap attached as `pasted-text-1.txt`, 12 October 2026.

Baselines:

- Mobile `feat/bitcoin-wallet`: `f592740f753899ec5cd080fd8d5ed1f306e436c4`.
- Backend `develop`: `3ed44778bf2d032e62f26fff94bddf50bbfc160f`.
- Immutable Owllet Core v0.2.0: `930eca151035eec9432d7f41b1b221bd5d27e829`.

The companion `owllet-transaction-infrastructure-progress.json` report in the parent workspace directory
records exact commit SHAs after each commit exists, without amending that commit.

No automatic PR merges, deployments, SDK tags/releases or production rollout changes.
Each step must pass its validation and GitHub CI before the next implementation begins.

## Step 1 â€” Bitcoin submission journal reconciliation

Scope: mobile only; no SDK, FRB, backend or transaction/signing-policy changes.

Wallet refresh starts bounded background status checks for persisted submissions.
Only an exact entry whose status is found, confirmed and has at least one
confirmation can be removed. Pending, missing, malformed, timeout, rate-limit
and provider-error observations retain the reservation. No elapsed-time release.

Opaque protected-storage revisions invalidate in-flight observations when any
submission mutation intervenes, including removal/restoration of an identical
txid and input set. Fresh observations are captured before each lookup. Other
wallets and networks remain isolated. Live submitters retain their rejection
capability until they finish. Existing proven-rejection release and manual
internal-Testnet4 legacy recovery are unchanged.

Checks are coalesced per wallet/network and bounded to 32 entries, an eight-second
request deadline and a thirty-second batch budget. Cursors rotate across batches
so earlier unresolved entries do not starve later confirmations. Batch expiry
only cancels checks; it never proves a release condition. Reconciliation does not
hold the protected-storage queue during network calls or delay wallet UI.

Tests cover mainnet/Testnet4, restart persistence, multiple confirmations,
unconfirmed/not-found/error retention, stale identical-entry recreation,
foreign storage, wallet invalidation/deletion, dropped persistence, malformed
status/storage, bounded rotation/coalescing and automatic non-blocking refresh.

Validation and exact final SHA are recorded in the companion report after execution.
Pending steps remain pending; this document does not claim mainnet rollout readiness.

## Step 2 — Runtime EVM fee quotes

Ordinary native/ERC20 sends use a reusable immutable integer-wei fee quote.
A validated latest-block base-fee field selects EIP-1559/type 2, including a
valid zero base fee. Its absence retains legacy/type 0. RPC chain identity is
verified; malformed observations and transport failures do not invent support
or fees. Optional fee-history/priority methods fall back only when explicitly
unsupported. Recent reward percentiles provide Economy/Normal/Priority; Normal
is the default and identical effective prices hide redundant choices.

Quotes bind sender, chain, destination, value, calldata and the exact RPC client.
They expire after thirty seconds. Confirmation refreshes expired fees and asks
for another review; approved fee fields reach the existing opaque Rust signer
without a silent refresh. A second freshness check runs after nonce discovery.
Explicit legacy fee parameters remain supported. NFT, swap, bridge and
WalletConnect execution paths remain unchanged.

The primary card shows Network fee and meaningful Speed. Collapsed Advanced
details contain transaction type, gas limit, and legacy gas price or dynamic
base/priority/max fees. The primary execution-gas fee is an "Up to" cap;
integer cap cost is also used for native MAX reservation. These standard EVM
gas fields do not include rollup data fees separately charged outside those
fields, and this step does not claim a universal full L2 fee estimate.

Validation and exact SHA are recorded in the companion report after execution.
No SDK/FRB API, backend contract, deployment or production rollout change.

## Remaining roadmap

3. EVM Speed Up/Cancel with authoritative outbound metadata.
4. Separate Owllet Core v0.2.1 Bitcoin RBF candidate and release preparation.
5. Verified new SDK pin and Bitcoin Speed Up integration.
6. Gas sponsorship policy/accounting foundation.
7. Live-catalog-gated Bitcoin Breet off-ramp.
8. Owllet crypto collection foundation, without merchants.
9. BTC-funded bill collection and exact-once prefunded provider dispatch.
10. Applicable existing OwlletPay user-flow integration only.
11. Runtime-capability-gated Bitcoin Bridge; ordinary BTC Swap remains disabled.
12. Discover browsing remains accessible across chains.
13. Shared, chain-appropriate advanced transaction details.
14. One bounded gas sponsorship pilot.
15. Full transaction, payment, lifecycle and security readiness audit.

The immutable v0.2.0 release must not be rewritten. A required merge, deployment,
release, unavailable provider capability or other stop condition in the user
roadmap must be reported before proceeding with dependent work.
