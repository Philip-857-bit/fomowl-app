//! Offline preparation of TRON transaction signatures from approved raw data.
use sha2::{Digest, Sha256};

pub fn tron_transaction_digest(raw_data_hex: &str) -> Result<[u8; 32], String> {
    let text = raw_data_hex.strip_prefix("0x").unwrap_or(raw_data_hex);
    if text.is_empty() {
        return Err("TRON transaction raw data is empty".into());
    }
    let data = hex::decode(text).map_err(|_| "Invalid TRON transaction raw data hex")?;
    Ok(Sha256::digest(data).into())
}

pub fn sign_tron_transaction(private_key_hex: &str, raw_data_hex: &str) -> Result<String, String> {
    crate::signing::secp256k1::sign_digest_with_recovery_id(
        private_key_hex,
        tron_transaction_digest(raw_data_hex)?,
        false,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn transaction_digest_matches_sha256_known_vector_and_rejects_bad_data() {
        assert_eq!(
            hex::encode(tron_transaction_digest("616263").unwrap()),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        assert_eq!(
            tron_transaction_digest("0x616263"),
            tron_transaction_digest("616263")
        );
        for value in ["", "0x", "0", "zz"] {
            assert!(tron_transaction_digest(value).is_err());
        }
    }
}
