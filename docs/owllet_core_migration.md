# Owllet shared-core migration

Target: one modular Rust wallet engine shared by mobile, desktop, browser,
embedded wallet applications, and other hosts through separate adapters.

Each implementation step is validated and committed independently. Commit
subjects identify steps; the latest report records their exact SHAs. Changes
preserve existing wallet keys, derivation paths, addresses, and public signing
facades. The unused Dart credentials API is retired; signer injection now accepts
an opaque account rather than a private key.

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
| Opaque EVM adapter | Dart contexts retain Rust references only; operation scopes explicitly close and dispose signers | `2c5f104` |
| Authoritative mnemonic engine | Remove BIP-39 Dart fallbacks; unavailable engine and invalid checksum fail closed | `1698ec4` |
| Encrypted EVM record engine | Authenticated versioned records, address binding, opaque session opening | `d85ddf9` |
| Native encrypted EVM bridge | Wrapping-key generation and opaque record opening through FRB | `187239b` |
| All-family vault engine | Independently enabled EVM/Solana/TRON records and explicit recovery export | `e5b73ce` |
| All-family custody bridge | Scoped signing methods and verified/restart-safe migration loader | `d38d13b` |

Foundation validation: 26 parent Rust tests, 22 core unit tests plus 4 public-API
contract tests, 15 Dart/FRB tests, Rust formatting/Clippy, and Flutter analysis.
Minimal/single-feature/pair-feature configurations and chain-specific signing
sessions are covered by CI. The current matrix also includes chain/vault builds
and vault without a chain (16 configurations).
Reduced runtime dependency trees were also checked locally. Native Windows
release FFI was rebuilt before testing. Other target certification remains open.

## Completed transaction milestone

Native, ERC-20, NFT, approval, generic legacy/type-2/creation, standard swap,
Relay swap, and bridge UI transactions use the shared Rust signer. WalletConnect,
dApp, and mini-app callers retain their existing facade and permission checks.
ABI encoding, RPC/fee discovery, quote guards, and confirmations remain in host
modules. No production EVM `sendTransaction` caller or typed-data Dart fallback
remains. The unused Dart credentials API has now been removed.

The core also owns Solana normalized-instruction compilation and serialized
signer-slot logic. Its builder rejects unavailable additional signers; serialized
signing supports required partial-signature slots and rejects excess slots.
Private-key address/public-key metadata comes from the Rust core.

## Completed native key-custody migration

All currently managed EVM, Solana, and TRON accounts migrate automatically after
unlock when the shell opens; new/imported accounts migrate before their creation
operation succeeds. Each versioned protected-storage record contains authenticated
ciphertext and wrapping material in one platform-protected value. A candidate is
opened, written, read back exactly, and authenticated again before legacy private-
key copies are removed. Interrupted cleanup resumes from the verified record.
Corrupt existing records are authoritative and fail closed; they never silently
fall back to legacy keys. A batch continues migrating other healthy accounts and
reports any failed accounts, preserving their recovery material.

Ordinary transaction, message, approval, typed-permit, bridge, and serialized-wire
signing opens Rust custody and passes only payloads through the signing boundary.
Tests verify that subsequent signing does not reload raw keys or mnemonics. App
custody starts locked. Successful existing PIN/biometric authentication unlocks it;
application locking, wallet switching, removal, logout, and reset revoke open
contexts and pending opens. EVM broadcast checks custody again after signing.
Existing mnemonic backups, derivation indexes, addresses, keypair export formats,
wallet switching, and private-key export remain available. Explicit exports are
separate from ordinary signing and retain existing host authentication flows.

## Additional host/product work

The native Flutter/shared-core migration does not create desktop/browser products.
Separate WASM/native language adapters, new chains, resource-constrained `no_std`
certification, cross-target CI, fuzzing, and independent audit remain product work.
The current core requires `std`. Host storage/authentication, RPC, UI, and backend
provider integrations remain outside the core. The Owllet backend owns payment,
KYC, and swap provider credentials.

Wrapping material crosses the FFI boundary and is protected by existing platform
secure storage. Import, initial migration, derivation, and explicit export can
still transiently cross Dart; this is not a hardware enclave or an all-copy memory
wiping guarantee. Normal migrated signing returns no raw private key.

## Encrypted-record engine step

Previous step: `1698ec4` makes mnemonic engine failures fail closed.
The optional core `vault` module now seals EVM keys using AES-256-GCM and opens
records directly into a scoped signing session. Version/algorithm/family/address
metadata is authenticated or strictly validated; malformed and tampered records
fail closed. Hosts supply secure wrapping keys and unique nonces. CI includes
a vault-only feature configuration. Existing Flutter storage and legacy keys
remain untouched. Native bindings and verified non-destructive storage migration
are subsequent steps. Commit: `feat(wallet-core): add authenticated EVM vault records`.

## Native encrypted-record adapter step

Core vault commit: `d85ddf9`. Native/FRB APIs now generate host-managed wrapping
material, seal legacy EVM keys with fresh native nonces, and authenticate records
into the existing opaque signing account. Owned native secret inputs are guarded
with `Zeroizing`; wrapping material still crosses the FFI boundary and must be
protected by platform storage. No API returns a decrypted private key.
The Flutter wrapper exposes the new operations; an FFI test verifies the official
EIP-155 transaction bytes after vault open, wrong wrapping keys/length/address
rejection, and terminal session closure. Storage migration remains a separate
non-destructive step. Commit: `feat(wallet): expose encrypted vault signing through FRB`.

Validation: 45 full core tests, 21 vault-only tests, 31 native adapter tests,
48 Flutter FFI/transaction tests; Rust formatting/Clippy, scoped Dart analysis,
and the native Windows release build passed.

## All-family vault engine

Previous adapter step: `187239b`. The vault now supports independently enabled
EVM, Solana, and TRON families, retaining EVM version-1 compatibility. Family and
address are authenticated; base58 addresses keep exact case. Explicit recovery
export validates the record and account identity separately from ordinary opaque
open. CI covers each chain/vault combination and vault without a chain.
Commit: `feat(wallet-core): extend authenticated vaults across chain families`.

## All-family native custody and verified loader

Engine commit: `e5b73ce`. The generic FRB account provides EVM transaction and
message signing, TRON hashing/typed permits, and Solana instruction/wire signing.
Ordinary calls use opaque accounts; explicit export is separate. The reusable
Flutter vault loader protects complete key/ciphertext records with the existing
platform store, authenticates candidates and persisted readback, coalesces same-
account migrations, and rejects corruption without fallback or cleanup.
Validation: 49 core tests, each chain/vault feature tests and Clippy, 32 native
tests, release rebuild, and eight all-family Flutter loader failure/restart tests.
Commit: `feat(wallet): add all-family vault custody and verified migration loader`.

## Verified protected-storage integration

Previous custody adapter: `d38d13b`. All signing paths now use authenticated vault
records and scoped Rust accounts. Storage verifies persisted ciphertext before
legacy cleanup; ordinary reads use custody, and explicit export decrypts only at
the recovery boundary. Switching/removal/reset and app unlock/lock are integrated.
Commit: `feat(wallet): complete verified vault storage and signing migration`.

Final validation: all 662 Flutter tests passed with one existing skip; 49 core
tests and 32 native adapter tests passed. Full Flutter analysis, Rust formatting
and Clippy passed. Twenty dedicated vault/migration tests cover family identity,
private-key/keypair export, restart/retry, interrupted writes/readback, corrupted
records, concurrent opens, application lock during migration/nonce lookup,
wallet switching/removal/reset, and migration of other healthy accounts after
a failure. Legacy 64-byte Solana keypair storage retains standard 64-byte export
rather than appending its public key a second time. Native Windows release FFI
was rebuilt before native-boundary testing.

The implementation is complete for currently managed native Flutter families.
Real-device records migrate on the next unlocked shell opening; no real wallet
records were accessed by these fixture tests. New host products/adapters remain
separate work described above.
