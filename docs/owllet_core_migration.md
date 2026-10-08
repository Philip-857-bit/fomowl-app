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
| Token approvals | Exact-amount approvals signed in Rust; sufficient allowance skips signing | `5e456a0` |
| Typed EVM engine | Explicit legacy/EIP-1559 fee policy and contract creation | `c1d1daf` |
| Typed EVM bridge | General signing API, fee validation, regenerated FRB, creation/type-2 fixtures | `44fc857` |
| Generic EVM requests | Legacy/type-2 calls and creation through the shared signer, host fee discovery retained | `2193d36` |
| Standard swaps | Approved backend transaction routed through Rust wallet signing, quote guards retained | `038ca0d` |
| Relay swaps | Sequential Rust requests; network, value, balance and gas-buffer guards retained | `dc30790` |
| Bridge UI | Verified signing context, reusable preflight module, Rust broadcast | `a11abee` |
| Solana transaction core | v0 building and serialized signer-slot logic extracted; owned FFI secret inputs wiped | `f8c3af7` |
| Solana signer metadata | Reject unavailable builder signers and excess serialized signature slots | `226c3f2` |
| Authoritative typed-data signing | Remove Dart fallback; CoW order/cancellation and nested permit signatures proven compatible | `81370bb` |
| Owned secret inputs | Drop-based cleanup of adapter mnemonic, seed, import-key and signing-key inputs | `1107531` |
| EVM metadata ownership | Derived/imported addresses and unprefixed 64-byte public keys come from Rust | `783265a` |
| Native signing sessions | Rust-resident keys, scoped opaque handles, terminal lock/removal lifecycle, multi-chain signing | `81154ea` |
| Opaque EVM adapter | Dart contexts retain Rust references only; operation scopes explicitly close and dispose signers | `feat(wallet): use opaque Rust EVM signing contexts` |

Foundation validation: 26 parent Rust tests, 22 core unit tests plus 4 public-API
contract tests, 15 Dart/FRB tests, Rust formatting/Clippy, and Flutter analysis.
Minimal/single-feature/pair-feature configurations and chain-specific signing
sessions are covered by CI (12 configurations).
Reduced runtime dependency trees were also checked locally. Native Windows
release FFI was rebuilt before testing. Other target certification remains open.

## Completed transaction milestone

Native, ERC-20, NFT, approval, generic legacy/type-2/creation, standard swap,
Relay swap, and bridge UI transactions use the shared Rust signer. WalletConnect,
dApp, and mini-app callers retain their existing facade and permission checks.
ABI encoding, RPC/fee discovery, quote guards, and confirmations remain in host
modules. No production EVM `sendTransaction` caller or typed-data Dart fallback
remains. The unused credentials API is retained as deprecated compatibility.

The core also owns Solana normalized-instruction compilation and serialized
signer-slot logic. Its builder rejects unavailable additional signers; serialized
signing supports required partial-signature slots and rejects excess slots.
Private-key address/public-key metadata comes from the Rust core.

## Subsequent product boundaries

- Consolidate remaining TRON transaction preparation and import-format parsing.
- Expose the optional Rust signing-session module through platform adapters;
  native Rust hosts can already consume it directly.
- Introduce Rust-owned vault/key lifecycle and opaque account handles, with
  explicit backup/export flows and verified legacy-storage migration.
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
