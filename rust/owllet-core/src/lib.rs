//! `owllet-core` is a reusable, platform-neutral Rust wallet core.
//!
//! Note on future WASM target:
//! `owllet-core` is intended to be reusable by a future browser WASM adapter.
//! Browser entropy configuration for rand/getrandom will be handled by that
//! adapter rather than enabling browser-specific dependencies in the platform-neutral core.

pub mod mnemonic;

pub use mnemonic::*;
