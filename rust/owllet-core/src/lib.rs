//! `owllet-core` is a reusable, platform-neutral Rust wallet core.
//!
//! Note on future WASM target:
//! `owllet-core` is intended to be reusable by a future browser WASM adapter.
//! Browser entropy configuration for rand/getrandom will be handled by that
//! adapter rather than enabling browser-specific dependencies in the platform-neutral core.

pub mod accounts;
pub mod mnemonic;
pub mod signing;

pub use accounts::*;
pub use mnemonic::*;
pub use signing::{
    decode_personal_sign_payload, sign_digest, sign_digest_with_recovery_id, sign_personal_message,
    sign_solana_message, sign_tron_raw_hash, sign_typed_data,
};
