use crate::accounts::derivation::{derive_secp256k1_private_key, public_key_from_private_key};
use secp256k1::PublicKey;
use sha3::{Digest, Keccak256};

pub const EVM_DERIVATION_PURPOSE: u32 = 44;
pub const EVM_COIN_TYPE: u32 = 60;

pub fn derive_evm_private_key_from_seed(
    seed: &[u8],
    derivation_index: u32,
) -> Result<String, String> {
    let path = format!(
        "m/{}'/{}'/0'/0/{}",
        EVM_DERIVATION_PURPOSE, EVM_COIN_TYPE, derivation_index
    );
    derive_secp256k1_private_key(seed, &path)
}

pub fn derive_evm_address_from_seed(seed: &[u8], derivation_index: u32) -> Result<String, String> {
    let private_key_hex = derive_evm_private_key_from_seed(seed, derivation_index)?;
    derive_evm_address_from_private_key(&private_key_hex)
}

pub fn derive_evm_address_from_private_key(private_key_hex: &str) -> Result<String, String> {
    let public_key = public_key_from_private_key(private_key_hex)?;
    Ok(evm_address_from_public_key(&public_key))
}

/// Ethereum's uncompressed X/Y public key, without the SEC1 0x04 prefix.
/// Matches the existing 64-byte account metadata format used by the app.
pub fn derive_evm_public_key_from_private_key(private_key_hex: &str) -> Result<String, String> {
    let public_key = public_key_from_private_key(private_key_hex)?;
    Ok(hex::encode(&public_key.serialize_uncompressed()[1..]))
}

pub fn evm_address_from_public_key(public_key: &PublicKey) -> String {
    let uncompressed = public_key.serialize_uncompressed();
    let hash = Keccak256::digest(&uncompressed[1..]);
    to_eip55_address(&hash[12..])
}

pub fn to_eip55_address(address: &[u8]) -> String {
    let lower = hex::encode(address);
    let hash = hex::encode(Keccak256::digest(lower.as_bytes()));
    let mut result = String::with_capacity(42);
    result.push_str("0x");

    for (idx, ch) in lower.chars().enumerate() {
        let hash_nibble = u8::from_str_radix(&hash[idx..idx + 1], 16).unwrap_or(0);
        if ch.is_ascii_hexdigit() && hash_nibble >= 8 {
            result.push(ch.to_ascii_uppercase());
        } else {
            result.push(ch);
        }
    }

    result
}
