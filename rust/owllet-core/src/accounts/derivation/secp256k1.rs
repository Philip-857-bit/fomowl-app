use super::{parse_32_byte_hex, validate_seed};
use ::secp256k1::{PublicKey, Secp256k1, SecretKey};
use bip32::{DerivationPath, XPrv};
use std::str::FromStr;
use zeroize::Zeroizing;

pub fn derive_secp256k1_private_key(seed: &[u8], path_str: &str) -> Result<String, String> {
    validate_seed(seed)?;

    let path =
        DerivationPath::from_str(path_str).map_err(|e| format!("Invalid derivation path: {e}"))?;

    let mut extended_prv =
        XPrv::new(seed).map_err(|e| format!("Failed to create master key from seed: {e:?}"))?;

    for child_num in path.into_iter() {
        let child = extended_prv
            .derive_child(child_num)
            .map_err(|e| format!("Failed to derive child key: {e:?}"))?;
        // XPrv's k256 SigningKey wipes its secret scalar on Drop. Let the
        // dependency manage its own layout instead of overwriting a live XPrv.
        extended_prv = child;
    }

    // The returned hex key is intentionally owned by the caller. Wipe the
    // serialization buffer on every exit, without assuming XPrv is all bytes.
    let key_bytes = Zeroizing::new(extended_prv.private_key().to_bytes());
    Ok(hex::encode(&key_bytes[..]))
}

pub fn public_key_from_private_key(private_key_hex: &str) -> Result<PublicKey, String> {
    let secp = Secp256k1::new();
    let secret_bytes = parse_32_byte_hex(private_key_hex, "private key")?;
    let secret_key = SecretKey::from_byte_array(secret_bytes)
        .map_err(|e| format!("Invalid private key: {e}"))?;
    Ok(PublicKey::from_secret_key(&secp, &secret_key))
}
