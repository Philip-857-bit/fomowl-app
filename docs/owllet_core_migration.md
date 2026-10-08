# Owllet shared-core migration

Target: one modular Rust wallet engine shared by mobile, desktop, browser,
embedded wallet applications, and other hosts through separate adapters.

Each implementation step is validated and committed independently. Commit
subjects identify steps; the latest report records their exact SHAs. Changes
preserve existing wallet keys, derivation paths, addresses, and public call APIs.

## Completed foundation

| Step | Result | Commit |
| --- | --- | --- |
| Compatibility baseline | Existing derivation/signature fixtures | `9b5c441` |
| Core boundary | BIP-39 extracted | `e3bee20` |
| Independent validation | Core validated separately in CI | `e6bf43a` |
| Account derivation | EVM, Solana, TRON extracted | `0241607` |
| Solana secret ownership | Adapter input buffers wiped | `411c059` |
| Message signing | Shared message/digest signing | `59bb100` |
| Legacy EVM engine | Alloy EIP-155 signing | `7959268` |
| Native transfers | Rust-owned signatures | `b154ab0` |
| ERC-20 transfers | Rust-owned signatures | `46ee567` |
| Transaction assertions | Exact calldata and complete signed bytes | `f3e2a26` |
| Modular core foundation | Safe derivation cleanup, feature selection, host entropy, capability CI | `a4f4bb5` |
| NFT transfers | ERC-721/ERC-1155 Rust signatures, sender verification, mocked production RPC coverage | `1e27cfb` |
| EVM adapter module | Shared signer verification, pending nonce, and canonical raw broadcast | `5fce8af` |
| Token approvals | Exact-amount approvals signed in Rust; sufficient allowance skips signing | `feat(wallet): migrate token approvals to Rust signing` |

Foundation validation: 26 parent Rust tests, 22 core unit tests plus 4 public-API
contract tests, 15 Dart/FRB tests, Rust formatting/Clippy, and Flutter analysis.
Nine minimal/single-feature/pair-feature configurations are covered by CI.
Reduced runtime dependency trees were also checked locally. Native Windows
release FFI was rebuilt before testing. Other target certification remains open.

## Transaction migration sequence

1. NFT transfers completed: existing calldata and 15% fee buffer retained;
   selected sender verified, pending nonce used, Rust signature broadcast raw.
2. Shared EVM transaction coordination: isolate key/address verification,
   nonce/fee resolution, and Rust signing in a reusable Flutter adapter module.
3. Token approvals: reuse that adapter, preserve exact-amount allowances and
   timeout/callback behavior, reject owner/key mismatch before broadcasting.
4. EIP-1559 and contract creation: add core engine support with independent
   fixtures, then expose it through the adapter.
5. Arbitrary EVM requests, swaps, Relay, and WalletConnect: migrate each path
   separately while preserving approval/permission and backend quote boundaries.

## Subsequent product boundaries

- Consolidate Solana and TRON transaction logic into the reusable core.
- Introduce Rust-owned vault/key lifecycle and opaque account handles, with
  explicit backup/export flows and verified legacy-storage migration.
- Remove production Dart cryptographic fallbacks after each replacement is proven.
- Add further chains inside the core rather than separately in each host.
- Build and validate WASM/native language adapters independently of the engine.
- Assess `no_std`/resource-constrained devices separately from wallets embedded
  in applications; the current core requires `std`.
- Add cross-target CI, fuzzing, and independent security audit before certifying
  new production hosts.

The core must remain independent of UI, RPC, platform storage, and provider
credentials. The Owllet backend continues to own payment/KYC/swap integrations.
Raw keys still cross Dart today; moving signatures is not the completed vault
security boundary. See `rust/owllet-core/README.md` for module responsibilities.
