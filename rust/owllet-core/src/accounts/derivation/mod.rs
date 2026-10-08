//! Shared derivation primitives; chain paths belong to the chain modules.

#[cfg(feature = "secp256k1")]
mod secp256k1;
#[cfg(feature = "solana")]
mod slip10;

#[cfg(feature = "secp256k1")]
pub use secp256k1::{derive_secp256k1_private_key, public_key_from_private_key};
#[cfg(feature = "solana")]
pub use slip10::{
    slip10_ed25519_derive_child, slip10_ed25519_master_key, slip10_key_from_hmac, Ed25519Slip10Key,
};

pub const HARDENED_OFFSET: u32 = 0x8000_0000;

pub fn validate_seed(seed: &[u8]) -> Result<(), String> {
    if seed.len() < 16 || seed.len() > 64 {
        return Err(format!(
            "Invalid BIP-32 seed length: expected 16..=64 bytes, got {}",
            seed.len()
        ));
    }
    Ok(())
}

pub fn hardened(index: u32) -> Result<u32, String> {
    index
        .checked_add(HARDENED_OFFSET)
        .ok_or_else(|| format!("Invalid hardened child index: {index}"))
}

pub fn parse_32_byte_hex(value: &str, label: &str) -> Result<[u8; 32], String> {
    let normalized = value.trim().strip_prefix("0x").unwrap_or(value.trim());
    let bytes = hex::decode(normalized).map_err(|e| format!("Invalid {label} hex: {e}"))?;
    if bytes.len() != 32 {
        return Err(format!(
            "Invalid {label} length: expected 32 bytes, got {}",
            bytes.len()
        ));
    }
    let mut out = [0u8; 32];
    out.copy_from_slice(&bytes);
    Ok(out)
}
