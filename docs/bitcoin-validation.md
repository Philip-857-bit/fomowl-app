# Bitcoin integration validation

The mobile adapter is pinned to owllet-core 0.2.0 at
`930eca151035eec9432d7f41b1b221bd5d27e829`.

## Offline native Testnet4 harness

`test/bitcoin_testnet4_native_flow_test.dart` uses the real Rust SDK through FRB,
with synthetic outpoints and an unfunded public BIP mnemonic fixture. It covers
BIP-84/BIP-86 receive/change, sealed account custody, three integer fee rates,
transaction verification, PSBT finalization parity, lock/reopen and wrong-network
recipient rejection. Other Bitcoin host tests use mocked backend responses for
address discovery, balances, history, broadcast and confirmation monitoring.

Run after building the host native Rust library:

```powershell
$env:FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR='C:/path/to/app/rust/target/debug/'
flutter test --concurrency=1 test/bitcoin_testnet4_native_flow_test.dart
```

## Live validation remains paused

The user requested that physical Android phone validation remain paused.
No funded Testnet4 transaction or real confirmation has been asserted by these
fixtures. Before production enablement, use a fresh disposable test-only wallet
and record evidence for new/existing seed migration, restart, QR receive, gap
scanning, multiple UTXOs, exact spend/change/dust, all fee tiers, BIP-84/BIP-86
sends, RBF sequence, pending/confirmed status and history. Also exercise app lock,
wallet switch, wrong network, insufficient funds, stale provider data and outages.
Never commit the live wallet's mnemonic or any funded private material.

Bitcoin must remain disabled by default until backend availability, native builds,
review and the intended rollout stage are approved. This native SDK change requires
a normal binary release, not a Shorebird-only patch.

## Pending submission journal

Before broadcasting, the host atomically persists the txid and selected outpoints
in protected storage. Subsequent sends exclude these outpoints, including after
restart. Separate signed objects cannot submit competing spends. Even a rejected
or timed-out provider response retains the reservation: transport errors do not
prove the transaction was never accepted. There is no timer-based release or RBF
replacement construction. The journal has a 1024-entry / 512 KiB bound and fails
closed at capacity; a future explicit chain-confirmed reconciliation/replacement
flow is required for pruning. Wallet deletion/reset removes this public journal
alongside custody. This is host concurrency protection, not an SPV proof of UTXOs.

## Native build compatibility

The unsigned review builds retain Android API 37 and install Google's
`platforms;android-37.0` package. iOS deployment metadata is aligned to 15.0,
the minimum required by the existing Firebase core/messaging plugins. This
binary therefore does not support iOS 13 or 14. No signing certificates or
production Firebase credentials are required by the review builds.

## Final automated gate coverage

The `Bitcoin wallet integration` PR workflow enforces Rust format, strict Clippy,
all-target/all-feature tests, the independent public SDK consumer, consumer lint,
full Flutter analysis/tests, an ARM64 Android debug APK and an unsigned iOS
simulator build. Review the checks on the current head of
[mobile PR #96](https://github.com/Philip-857-bit/fomowl-app/pull/96) before merge.

The tested application source baseline at `dea609d` passed 37 Rust adapter tests,
767 Flutter tests (one existing skipped test), strict lint/analysis, the native
consumer for all four families and the unsigned iOS build. Android CI exposed
runner disk exhaustion, so its review workflow disables Rust debug symbols and
frees unused tools on the disposable runner. Those resource changes do not alter
wallet protocol behavior. The final branch head must still pass its own checks.

[Backend PR #47](https://github.com/Philip-857-bit/Fomowl-Backend/pull/47) at
`b53db805cdee8664ccece846269be5577cdaed63` passed its full locked Rust test suite, strict Clippy, dependency audit
and GitHub CI. Merge the stable backend contract before the mobile product.

The immutable SDK currently accepts P2WPKH and P2TR recipient scripts.
Legacy P2PKH/P2SH recipients, mixed input policies, WIF/XPRV import UI, Lightning,
multisig, tapscript, Bitcoin swaps and Bitcoin WalletConnect are outside this
milestone. Funded Testnet4 broadcasts have been observed during physical phone
testing. Confirmation, recovery and lifecycle checks remain production rollout
gates; automated fixtures and compile checks do not replace them.

## Network preference semantics

Runtime policy and backend capabilities admit Bitcoin availability. Seed-wallet
provisioning adds wallet support and custody independently of the user’s enabled
network families. Settings → Manage Networks provides the Bitcoin switch only
for an admitted, provisioned seed wallet. Enabling verifies provisioning;
disabling preserves custody and selects an enabled supported fallback. Runtime
refresh and restart respect the saved preference, including an outdated saved
active network. Private-key-only imports cannot opt in.

The locked Firebase core 4.12.1 and messaging 16.4.3 Swift packages both declare
minimum iOS 15.0. The binary minimum changed from iOS 13 to iOS 15; this cleanup
retains that dependency requirement without downgrading Firebase.

## Legacy submission recovery

Send provides a saved-attempt inspector showing the exact transaction ID and
reserved outpoints. Mainnet and production builds are read-only. Internal
Testnet4 builds permit an explicit manual override only for legacy entries,
after the user acknowledges a known pre-broadcast rejection and authenticates.
The coordinator checks the transaction twice, refreshes discovery, and verifies
every expected input is confirmed, unspent and owned using SDK-derived scripts.
Authentication expiry, wallet changes, known transactions, provider errors and
changed snapshots prevent release. A missing transaction alone never releases
an entry, and recovery never signs or broadcasts a transaction.

Journal schema v2 preserves existing reservations and marks only pre-upgrade
entries as legacy. New uncertain submissions cannot use this override. Removal
compares the exact storage scope, transaction and input set atomically; stale
snapshots cannot remove later attempts. The protected storage key is unchanged.
After v2 is written, older builds with a v1-only parser cannot read the journal
and fail closed; reinstalling an older APK is not a recovery method. SDK vault
records, derivation, signing and the immutable Owllet Core pin are unchanged.
