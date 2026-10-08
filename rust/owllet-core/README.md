# Owllet Core

Owllet's shared Rust wallet engine for mobile apps, desktop apps, browser
extensions, wallets embedded in other applications, and native integrations.
The current crate is an early engine foundation, not a complete wallet SDK.

## Boundaries

| Module | Responsibility |
| --- | --- |
| `mnemonic` | BIP-39 generation, validation, and seed derivation |
| `accounts::derivation` | Shared BIP-32/secp256k1 and SLIP-0010 primitives |
| `accounts::{evm,solana,tron}` | Chain-specific paths and address derivation |
| `signing::{evm,secp256k1,solana,tron}` | Message, typed-data, and digest signing |
| `transactions::evm` | Offline legacy/EIP-1559 signing and contract creation with Alloy |
| `transactions::solana` | v0 instruction compilation and required-signer-slot signing of serialized legacy/v0 transactions |
| `session` (optional) | Rust-owned transient keys, opaque scoped account handles, lock/removal lifecycle |

Use module-qualified APIs in new integrations. Existing root re-exports remain
available for Flutter compatibility. Share primitives across chains; keep chain
formats and transaction rules inside their own modules. The core forbids unsafe
code in its own source; dependencies retain their own implementations.

Core code must not import Flutter, browser/desktop APIs, RPC clients, platform
storage, application UI, or payment/KYC/swap provider credentials. Platform
adapters translate boundary values and errors and own platform resources. They
must delegate cryptographic work rather than copy the engine implementation.

## Choose capabilities

Default features preserve the existing mobile adapter: `evm`, `solana`, `tron`,
and `mnemonic-generation`. Consumers can disable defaults and select only what
they need:

```toml
[dependencies]
owllet-core = { path = "../owllet-core", default-features = false, features = ["evm"] }
```

| Feature | Capability |
| --- | --- |
| none | Mnemonic validation, seed derivation, host-supplied mnemonic entropy |
| `mnemonic-generation` | Convenience generation using `rand` and native entropy |
| `secp256k1` | Shared secp256k1 derivation and digest signing primitives |
| `evm` | EVM accounts/messages and Alloy legacy/EIP-1559 transactions; includes `secp256k1` |
| `solana` | Solana accounts, message signatures, and transaction compilation/signing |
| `tron` | TRON accounts and raw-hash signatures; includes `secp256k1` |
| `signing-session` | Process-local signing sessions; select at least one chain feature to expose this module |

Cargo features are additive: a dependency graph may enable more features than
one consumer explicitly requests. They control compiled capabilities, not user
authorization or permissions. Feature combinations have independent CI tests.

Browser and device hosts can avoid the native RNG convenience feature and pass
128 bits of cryptographically secure entropy to `generate_mnemonic_from_entropy`.
The host owns the supplied entropy buffer and must wipe it when no longer needed.
Never substitute timestamps, identifiers, or a non-cryptographic RNG.

## Rust-resident signing sessions

Native and embedded Rust hosts can select `features = ["evm", "signing-session"]`
and use `session::SigningSession`. After host authentication, import owned key
material once and perform normal signing through the returned `AccountHandle`.
`account_info` returns only the family and public address. There is no private-key
export API in this module. Existing raw-key primitives remain available for
compatibility and explicit low-level integrations.

Handles are opaque Rust values with weak references, not serializable IDs or
authorization tokens. A foreign session cannot use them. Removing an account,
locking, or dropping its session invalidates access; keeping cloned handles does
not retain the owned key buffers. Locks are terminal: after a new authenticated
unlock, create a fresh session and re-import from host-managed secure storage.

This module is an in-memory custody foundation. It performs no authentication,
permission prompts, encrypted persistence, network calls, or hardware access.
The host must serialize session mutation and apply its lifecycle policy. Flutter
EVM transactions use an opaque Rust signing context through FRB, with explicit
close/disposal at operation boundaries. Its legacy key import still crosses
Dart once; transaction signing no longer sends or retains a key in its Dart
context. Other family adapters and encrypted vault/storage migration are
separate steps, with verification before any legacy data removal.

## Host integrations and current support

| Host | Integration boundary |
| --- | --- |
| Flutter mobile or desktop | Existing `rust/` Flutter Rust Bridge adapter |
| Native Rust desktop/CLI/service | Direct crate API, with RPC and storage supplied by the host |
| Browser extension or web embedded wallet | Future WASM adapter, secure browser entropy, and browser lifecycle handling |
| Wallet embedded in a native application | Direct Rust API or a dedicated language/FFI adapter |
| Constrained hardware/firmware | Requires a separate `no_std` and dependency/resource assessment |

The crate currently requires Rust `std` and allocation. Selectable chain features
do not establish `no_std`, hardware-wallet, or browser support. WASM adapters,
cross-target builds, and platform-specific lifecycle tests remain future work.
Keep adapters outside the core; create additional crates when those integrations
are implemented rather than coupling this crate to every host SDK.

## Secret ownership and compatibility

Existing derivation paths and public adapter signatures are preserved. A host
must retain the same mnemonic/private key, account index, and derivation path to
retain the same wallet address. Moving the engine does not require moving funds.

Today APIs accept borrowed raw keys and some derivation APIs return owned keys.
The Flutter adapter still transfers keys through Dart strings. Rust signing is
not yet a vault or an opaque-handle security boundary. Hosts own cleanup of
borrowed input buffers and returned keys; dependency-owned key objects use their
supported cleanup. BIP-32 serialization uses a `Zeroizing` buffer. Do not overwrite
the byte layout of a live dependency object to attempt secret cleanup. This does
not claim that all seed, mnemonic, chain-code, or language-runtime copies are wiped.

The intended end state adds a separate vault/key-lifecycle module with opaque
wallet/account handles. Normal signing should operate on handles, while explicit
backup/export remains a separately authorized operation. Preserve existing
wallets using a versioned, verified migration before removing legacy storage.

Remaining engine work includes wiring other EVM transaction paths, complete
Solana/TRON transaction support in this crate, vault ownership, and additional
chains. Add chain implementations here once; reuse them from all hosts. UI,
network orchestration, permissions prompts, and backend provider integrations
continue to have their own boundaries. Audit and fuzz the shared engine before
claiming it is hardened for new deployments.

## Validation

From `rust/`:

```sh
cargo fmt --manifest-path owllet-core/Cargo.toml --all -- --check
cargo clippy --locked --manifest-path owllet-core/Cargo.toml --all-targets --all-features -- -D warnings
cargo test --locked --manifest-path owllet-core/Cargo.toml --all-targets --all-features
cargo test --locked --manifest-path owllet-core/Cargo.toml --no-default-features --features evm --all-targets
```

Keep exact known-address/signature fixtures and the official EIP-155 byte fixture.
`tests/feature_contract.rs` exercises public APIs in minimal and single-chain
builds. The full adapter suite and Dart/FRB tests independently verify the
current Flutter integration. Cross-target support needs additional target CI.

## Optional encrypted EVM records

Enable `vault` to obtain AES-256-GCM authenticated records and opaque signing
custody on open. This feature enables EVM and signing sessions, without adding
platform storage or authentication. The versioned record authenticates its
algorithm, chain family, and account address; unsupported formats and failed
authentication are rejected. Decrypted buffers are guarded with `Zeroizing`.
Hosts must protect the 32-byte wrapping key and supply a unique 12-byte nonce
for every encryption under that key, including retries and restores. The API
does not supply password derivation, rollback protection, or a hardware boundary.
No existing Flutter wallet storage is migrated by this module alone.
