use crate::accounts::parse_32_byte_hex;
use crate::signing::secp256k1::sign_digest_with_recovery_id;
use sha3::{Digest, Keccak256};

/// TRON personal-message length counts UTF-8 bytes, matching wallet providers.
pub fn tron_personal_message_digest(message: &str) -> [u8; 32] {
    let bytes = message.as_bytes();
    let prefix = format!("\x19TRON Signed Message:\n{}", bytes.len());
    let mut digest = Keccak256::new();
    digest.update(prefix.as_bytes());
    digest.update(bytes);
    digest.finalize().into()
}

pub fn sign_tron_personal_message(private_key_hex: &str, message: &str) -> Result<String, String> {
    sign_digest_with_recovery_id(
        private_key_hex,
        tron_personal_message_digest(message),
        false,
    )
}

pub fn sign_tron_raw_hash(private_key_hex: &str, raw_hash_hex: &str) -> Result<String, String> {
    let digest = parse_32_byte_hex(raw_hash_hex, "TRON raw transaction hash")?;
    sign_digest_with_recovery_id(private_key_hex, digest, false)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn canonical_personal_message_fixture_keeps_utf8_byte_length() {
        assert_eq!(
            hex::encode(tron_personal_message_digest("hello")),
            "a07d8e5b946cc0416662f5420751673680809e5f10313e20c7c5badb0ef4226d"
        );
        let message = "🦉";
        assert_eq!(
            tron_personal_message_digest(message),
            <[u8; 32]>::from(Keccak256::digest(
                b"\x19TRON Signed Message:\n4\xf0\x9f\xa6\x89"
            ))
        );
    }
    #[test]
    fn personal_signature_preserves_one_hex_prefix_and_raw_recovery_id() {
        let key = "46".repeat(32);
        let signature = sign_tron_personal_message(&key, "hello").unwrap();
        assert_eq!(signature.len(), 132);
        assert_eq!(
            signature,
            sign_tron_raw_hash(&key, &hex::encode(tron_personal_message_digest("hello"))).unwrap()
        );
    }
}
