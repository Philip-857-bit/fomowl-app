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
