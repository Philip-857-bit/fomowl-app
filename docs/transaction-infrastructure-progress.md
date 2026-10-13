# Transaction infrastructure implementation

Specification: user roadmap attached as `pasted-text-1.txt`, 12 October 2026.

Baselines:

- Mobile `feat/bitcoin-wallet`: `f592740f753899ec5cd080fd8d5ed1f306e436c4`.
- Backend `develop`: `8ac22294a30d2b53abfc6df7fae6696a446e0546` (adopted from the original
  `3ed44778bf2d032e62f26fff94bddf50bbfc160f` baseline after user review).
- Immutable Owllet Core v0.2.0: `930eca151035eec9432d7f41b1b221bd5d27e829`.

The companion `owllet-transaction-infrastructure-progress.json` report in the parent workspace directory
records exact commit SHAs after each commit exists, without amending that commit.

No automatic PR merges, deployments, SDK tags/releases or production rollout changes.
Each step must pass its validation and GitHub CI before the next implementation begins.

Newer fast-forward baselines may be adopted when intervening changes do not materially
overlap the current step or its contracts/security assumptions. Before backend changes,
refresh develop and inspect all changes since the last recorded backend baseline.

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

## Step 2 â€” Runtime EVM fee quotes

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

Local validation: 105 focused tests and the full Flutter suite (994 passed, one
existing skip) passed; formatting passed with no changes. Exact SHA and CI results
are recorded in the companion report after execution.
No SDK/FRB API, backend contract, deployment or production rollout change.

## Step 3 â€” EVM pending transaction replacement

Forward-created ordinary native/ERC20 sends persist the exact public Rust-signed
sender, chain, nonce, destination, value, calldata, gas limit, fee fields and local
transaction hash before provider broadcast. Metadata lives in platform-protected
storage with serialized mutation, storage read-back, bounded records and wallet
lifecycle invalidation. Previous history rows are never signing authority.
Existing NFT, swap, bridge and WalletConnect execution paths remain unchanged;
transactions without this trusted record do not expose replacement controls.

Speed Up preserves the original intent, gas limit, sender, chain and nonce.
Cancel is a zero-value, empty-calldata self-transfer, offered only after proving
that the sender has no deployed/delegated code. Both use the opaque Rust signer.
A 12.5% integer-rounded-up bump floor applies to legacy price or both type-2
fee cap and priority cap, with current network Priority observations as a floor.
This exceeds Geth's usual 10% default but does not claim every provider has the
same policy: https://geth.ethereum.org/docs/fundamentals/command-line-options

The device checks full pending transaction fields, chain identity, receipt,
confirmed nonce, wallet context and fresh fees before approval/signing. Changed
gas requirements, insufficient balance and infeasible block gas limits fail
closed. Approvals bind their producing service and protected snapshot;
intervening writes, removals and wallet/network switches invalidate them.

Review shows old/new estimated fees, additional estimated cost, maximum execution
fee and original transaction identity. Explicit approval and authentication are
required; cancel/back never submits. Cancel warns the original may confirm first.
Replacement does not guarantee inclusion time or successful cancellation.
Controls recheck status and disappear after confirmed observations.

Provider sends seal a one-use reservation capability. A proven no-provider abort
may reject only its live reservation before that seal. Once send begins, timeout,
error or mismatched txid retains the exact attempt and blocks blind replacement
retry. Submitted requires the provider txid to match the local signed-transaction
hash. Local pending entries join history before backend indexing. Normal-send
ambiguity uses Unknown presentation and disables reuse of that confirmation screen.
No timer or missing hash releases funds. Confirmed nonce progression settles earlier
same-chain nonce reservations without asserting which transaction succeeded;
receipt/explorer data remains authoritative.

Local validation: 105 focused tests and the full Flutter suite (994 passed, one
existing skip) passed; formatting passed with no changes. Exact SHA and CI results
are recorded in the companion report after execution.
No SDK/FRB, backend contract, release, deployment or production rollout change.

## Step 4 — Owllet Core Bitcoin RBF candidate

Implementation: `8126e4dfcefe735b2634636fef48329d2a7ccda4`.
Version preparation: `9918187371812e059bb4a6a07b8550c33318f43c`.
The v0.2.1 candidate preserves recipient intent, homogeneous purpose, original
inputs and internal change. It increases absolute fee and fee rate using core
rules and fails closed on invalid originals or unsupported descendant context.
Core tests, strict Clippy, independent consumer and Linux/Windows capability CI
passed. No tag, release or merge was created; v0.2.0 remains immutable.

## Step 5 — Bitcoin Speed Up (validation in progress)

Both native manifests pin `=0.2.1` at the exact candidate above. FRB files were
regenerated with the official generator. Protected public outbound metadata
supports SDK reconstruction; it carries no private signing material.

Speed Up requires an Owllet-created RBF transaction, the exact active persisted
attempt, verified signed transaction metadata and fresh positive backend context.
Review shows original fee, replacement fee, additional fee and new rate. Approval
is single-use and expires after 30 seconds. Opaque custody and safe unlock
navigation remain authoritative. Context and SDK intent are rechecked around
authentication and before submission. Bitcoin Cancel is not implemented.

Replacement candidates share one input reservation. Definitive pre-provider
rejection restores the prior candidate; ambiguous outcomes retain the reservation
and block blind retries. Exact positive confirmation of either original or
replacement reconciles the chain once. Display-only receipt aliases suppress
stale local history; fresh provider observations remain authoritative.

Local evidence so far: 38 native Rust tests and the independent consumer passed;
33 RBF coordinator/widget tests, 19 network-service tests, 81 lifecycle regressions
and seven history tests passed. The full Flutter suite passed 1,034 tests with one existing skip. Final
analysis and native revalidation passed. Exact-head CI gates are pending, so
this step is not marked complete.

Linux CI migration is isolated in separate infrastructure commits and worktrees.
UpCloud runners execute existing checks serially under a shared worker-lifetime
lock. Backend build/tests, audit, Discover and Actions job-container smoke passed;
production container passed after installing Buildx. Updated app gates are
still pending. macOS remains
hosted. Optional Discover software-emulator performance remains unverified.

## Remaining roadmap

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
