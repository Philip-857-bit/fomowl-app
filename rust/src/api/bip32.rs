use bip32::{DerivationPath, XPrv};
use std::str::FromStr;

pub fn derive_wallet_from_seed(seed: Vec<u8>, derivation_index: u32) -> Result<String, String> {
    // BIP-32 requires the master seed to be 16..=64 bytes (BIP-39's PBKDF2
    // output is 64 bytes). Reject anything outside that range before we hand
    // the buffer to bip32, so malformed input from Dart surfaces as a clean
    // error rather than relying on the underlying crate's internal check.
    if seed.len() < 16 || seed.len() > 64 {
        return Err(format!(
            "Invalid BIP-32 seed length: expected 16..=64 bytes, got {}",
            seed.len()
        ));
    }

    // Ethereum Derivation Path
    let path_str = format!("m/44'/60'/0'/0/{}", derivation_index);
    let path = DerivationPath::from_str(&path_str)
        .map_err(|e| format!("Invalid derivation path: {}", e))?;

    // Create Master Key from Seed
    let mut extended_prv = XPrv::new(seed.as_slice())
        .map_err(|e| format!("Failed to create master key from seed: {:?}", e))?;

    // Derive Child Key structure 
    for child_num in path.into_iter() {
        extended_prv = extended_prv.derive_child(child_num)
             .map_err(|e| format!("Failed to derive child key: {:?}", e))?;
    }

    // Return hex encoded private key bytes (32 bytes)
    Ok(hex::encode(extended_prv.private_key().to_bytes()))
}
