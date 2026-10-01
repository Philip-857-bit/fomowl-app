use secp256k1::{Message, Secp256k1, SecretKey};
use std::str::FromStr;

pub fn sign_digest(private_key_hex: &str, digest: [u8; 32]) -> Result<String, String> {
    sign_digest_inner(private_key_hex, digest, true)
}

pub fn sign_digest_with_recovery_id(
    private_key_hex: &str,
    digest: [u8; 32],
    ethereum_recovery_id: bool,
) -> Result<String, String> {
    sign_digest_inner(private_key_hex, digest, ethereum_recovery_id)
}

fn sign_digest_inner(
    private_key_hex: &str,
    digest: [u8; 32],
    ethereum_recovery_id: bool,
) -> Result<String, String> {
    let secp = Secp256k1::new();
    let normalized_private_key = private_key_hex
        .trim()
        .strip_prefix("0x")
        .unwrap_or(private_key_hex.trim());
    let secret_key = SecretKey::from_str(normalized_private_key)
        .map_err(|e| format!("Invalid private key: {e}"))?;
    let msg = Message::from_digest(digest);
    let (recovery_id, sig) = secp
        .sign_ecdsa_recoverable(msg, &secret_key)
        .serialize_compact();
    let mut signature = sig.to_vec();
    let recovery_id = i32::from(recovery_id) as u8;
    signature.push(if ethereum_recovery_id {
        recovery_id + 27
    } else {
        recovery_id
    });
    Ok(format!("0x{}", hex::encode(signature)))
}
