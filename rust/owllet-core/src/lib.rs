//! `owllet-core` is a reusable, platform-neutral Rust wallet core.
//!
//! Mobile, desktop, browser, and embedded-wallet hosts share this crate through
//! separate platform adapters. RPC, storage, UI, and provider credentials belong
//! outside the core. Chain features are opt-in when default features are disabled.
//!
//! Browser/device adapters can supply secure entropy to
//! [`generate_mnemonic_from_entropy`] without enabling the native RNG feature.
//! This crate currently requires `std`; WASM and `no_std` support are not certified.

#![forbid(unsafe_code)]

#[cfg(all(
    feature = "vault",
    any(feature = "evm", feature = "solana", feature = "tron")
))]
pub mod vault;

pub mod accounts;
pub mod mnemonic;
pub mod signing;
pub mod transactions;

#[cfg(all(
    feature = "signing-session",
    any(feature = "evm", feature = "solana", feature = "tron")
))]
pub mod session;

pub use accounts::*;
pub use mnemonic::*;
#[cfg(feature = "solana")]
pub use signing::sign_solana_message;
#[cfg(feature = "tron")]
pub use signing::sign_tron_raw_hash;
#[cfg(feature = "evm")]
pub use signing::{decode_personal_sign_payload, sign_personal_message, sign_typed_data};
#[cfg(feature = "secp256k1")]
pub use signing::{sign_digest, sign_digest_with_recovery_id};
#[cfg(feature = "evm")]
pub use transactions::{
    sign_evm_transaction, sign_legacy_evm_transaction, EvmTransactionFee, EvmTransactionRequest,
    LegacyEvmTransactionRequest, SignedEvmTransaction,
};
