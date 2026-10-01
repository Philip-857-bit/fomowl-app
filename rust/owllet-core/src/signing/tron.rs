use crate::accounts::parse_32_byte_hex;
use crate::signing::secp256k1::sign_digest_with_recovery_id;

pub fn sign_tron_raw_hash(private_key_hex: &str, raw_hash_hex: &str) -> Result<String, String> {
    let digest = parse_32_byte_hex(raw_hash_hex, "TRON raw transaction hash")?;
    sign_digest_with_recovery_id(private_key_hex, digest, false)
}
