use crate::accounts::derivation::{derive_secp256k1_private_key, public_key_from_private_key};
use secp256k1::PublicKey;
use sha2::{Digest, Sha256};
use sha3::Keccak256;

pub const TRON_DERIVATION_PURPOSE: u32 = 44;
pub const TRON_COIN_TYPE: u32 = 195;

pub fn derive_tron_private_key_from_seed(
    seed: &[u8],
    derivation_index: u32,
) -> Result<String, String> {
    let path = format!(
        "m/{}'/{}'/0'/0/{}",
        TRON_DERIVATION_PURPOSE, TRON_COIN_TYPE, derivation_index
    );
    derive_secp256k1_private_key(seed, &path)
}

pub fn derive_tron_address_from_seed(seed: &[u8], derivation_index: u32) -> Result<String, String> {
    let private_key_hex = derive_tron_private_key_from_seed(seed, derivation_index)?;
    derive_tron_address_from_private_key(&private_key_hex)
}

pub fn derive_tron_address_from_private_key(private_key_hex: &str) -> Result<String, String> {
    let public_key = public_key_from_private_key(private_key_hex)?;
    Ok(tron_address_from_public_key(&public_key))
}

pub fn tron_address_from_public_key(public_key: &PublicKey) -> String {
    let uncompressed = public_key.serialize_uncompressed();
    let hash = Keccak256::digest(&uncompressed[1..]);
    let mut payload = Vec::with_capacity(25);
    payload.push(0x41);
    payload.extend_from_slice(&hash[12..]);

    let checksum = Sha256::digest(Sha256::digest(&payload));
    payload.extend_from_slice(&checksum[..4]);
    bs58::encode(payload).into_string()
}
