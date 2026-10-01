use crate::accounts::derivation::{
    hardened, slip10_ed25519_derive_child, slip10_ed25519_master_key, validate_seed,
};
use solana_keypair::Keypair;
use solana_signer::Signer;
use zeroize::Zeroize;

pub const SOLANA_DERIVATION_PURPOSE: u32 = 44;
pub const SOLANA_COIN_TYPE: u32 = 501;

pub fn derive_solana_private_key_from_seed(
    seed: &[u8],
    derivation_index: u32,
) -> Result<Vec<u8>, String> {
    validate_seed(seed)?;

    let path = [
        hardened(SOLANA_DERIVATION_PURPOSE)?,
        hardened(SOLANA_COIN_TYPE)?,
        hardened(derivation_index)?,
        hardened(0)?,
    ];
    let mut key = slip10_ed25519_master_key(seed)?;
    for child in path {
        key = slip10_ed25519_derive_child(&key, child)?;
    }

    let private_key_bytes = key.key.to_vec();
    key.zeroize();
    Ok(private_key_bytes)
}

pub fn derive_solana_address_from_seed(
    seed: &[u8],
    derivation_index: u32,
) -> Result<String, String> {
    let private_key_bytes = derive_solana_private_key_from_seed(seed, derivation_index)?;
    derive_solana_address_from_private_key(&private_key_bytes)
}

pub fn derive_solana_address_from_private_key(private_key_bytes: &[u8]) -> Result<String, String> {
    let keypair = solana_keypair_from_bytes(private_key_bytes, "Solana private key")?;
    Ok(keypair.pubkey().to_string())
}

pub fn solana_keypair_from_bytes(bytes: &[u8], source: &str) -> Result<Keypair, String> {
    match bytes.len() {
        32 => {
            let mut secret = [0u8; 32];
            secret.copy_from_slice(bytes);
            let keypair = Keypair::new_from_array(secret);
            secret.zeroize();
            Ok(keypair)
        }
        64 => Keypair::try_from(bytes)
            .map_err(|e| format!("Invalid Solana {source} keypair bytes: {e}")),
        len => Err(format!(
            "Invalid Solana {source} key length: expected 32-byte seed or 64-byte keypair, got {len} bytes"
        )),
    }
}
