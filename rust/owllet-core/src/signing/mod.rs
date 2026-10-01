pub mod evm;
pub mod secp256k1;
pub mod solana;
pub mod tron;

pub use evm::*;
pub use secp256k1::*;
pub use solana::*;
pub use tron::*;

#[cfg(test)]
mod tests {
    use super::*;
    use ::secp256k1::{
        ecdsa::{RecoverableSignature, RecoveryId},
        Message, Secp256k1,
    };
    use ed25519_dalek::{Signature as DalekSignature, Verifier, VerifyingKey};
    use ethers_core::types::{transaction::eip712::TypedData, Signature as EthersSignature};
    use sha2::{Digest, Sha256};
    use sha3::Keccak256;

    const KNOWN_EVM_PRIV_KEY: &str =
        "1ab42cc412b618bdea3a599e3c9bae199ebf030895b039e9db1e30dafb12b727";
    const KNOWN_EVM_ADDRESS: &str = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94";

    const KNOWN_SOLANA_SEED_HEX: &str =
        "37df573b3ac4ad5b522e064e25b63ea16bcbe79d449e81a0268d1047948bb445";
    const KNOWN_SOLANA_ADDRESS: &str = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk";

    const KNOWN_TRON_PRIV_KEY: &str =
        "b5a4cea271ff424d7c31dc12a3e43e401df7a40d7412a15750f3f0b6b5449a28";
    const KNOWN_TRON_ADDRESS: &str = "TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH";

    #[test]
    fn test_evm_personal_sign_utf8_and_hex_payload() {
        let message = "hello world";
        let hex_message = "0x68656c6c6f20776f726c64";

        let sig_utf8 = sign_personal_message(KNOWN_EVM_PRIV_KEY, message)
            .expect("sign UTF-8 personal message");
        let sig_hex = sign_personal_message(KNOWN_EVM_PRIV_KEY, hex_message)
            .expect("sign hex personal message");

        assert_eq!(sig_utf8, sig_hex);
        assert!(sig_utf8.starts_with("0x"));
        assert_eq!(sig_utf8.len(), 132);

        let parsed: EthersSignature = sig_utf8.parse().expect("parse signature");
        let recovered = parsed.recover(message).expect("recover signer");
        assert_eq!(
            format!("{:#x}", recovered).to_lowercase(),
            KNOWN_EVM_ADDRESS.to_lowercase()
        );
    }

    #[test]
    fn test_evm_typed_data_signing() {
        let typed_data_json = r#"{
          "types": {
            "EIP712Domain": [
              {"name": "name", "type": "string"},
              {"name": "version", "type": "string"},
              {"name": "chainId", "type": "uint256"},
              {"name": "verifyingContract", "type": "address"}
            ],
            "Message": [
              {"name": "content", "type": "string"}
            ]
          },
          "primaryType": "Message",
          "domain": {
            "name": "Owllet Core",
            "version": "1",
            "chainId": 1,
            "verifyingContract": "0x0000000000000000000000000000000000000001"
          },
          "message": {
            "content": "Hello Owllet"
          }
        }"#;

        let signature_hex =
            sign_typed_data(KNOWN_EVM_PRIV_KEY, typed_data_json).expect("sign EIP-712 typed data");
        assert!(signature_hex.starts_with("0x"));
        assert_eq!(signature_hex.len(), 132);

        let parsed: EthersSignature = signature_hex.parse().expect("parse signature");
        let typed_data: TypedData =
            serde_json::from_str(typed_data_json).expect("parse typed data JSON");
        let recovered = parsed
            .recover_typed_data(&typed_data)
            .expect("recover typed data signer");
        assert_eq!(
            format!("{:#x}", recovered).to_lowercase(),
            KNOWN_EVM_ADDRESS.to_lowercase()
        );
    }

    #[test]
    fn test_solana_message_signing_and_determinism() {
        let seed = hex::decode(KNOWN_SOLANA_SEED_HEX).expect("valid hex");
        let message = b"Owllet core Solana signature test payload";

        let signature_b58 = sign_solana_message(&seed, message).expect("sign Solana message");

        // Verify with ed25519-dalek
        let pubkey_bytes = bs58::decode(KNOWN_SOLANA_ADDRESS)
            .into_vec()
            .expect("decode base58 pubkey");
        let pubkey_array: [u8; 32] = pubkey_bytes.as_slice().try_into().unwrap();
        let verifying_key = VerifyingKey::from_bytes(&pubkey_array).expect("valid verifying key");

        let sig_bytes = bs58::decode(&signature_b58)
            .into_vec()
            .expect("decode base58 signature");
        let dalek_sig = DalekSignature::from_slice(&sig_bytes).expect("valid signature bytes");

        assert!(verifying_key.verify(message, &dalek_sig).is_ok());

        // Determinism check
        let signature_b58_2 = sign_solana_message(&seed, message).expect("second signature");
        assert_eq!(signature_b58, signature_b58_2);
    }

    #[test]
    fn test_tron_raw_hash_signing() {
        let raw_hash_bytes = Sha256::digest(b"Owllet TRON payload");
        let raw_hash_hex = hex::encode(raw_hash_bytes);

        let signature_hex =
            sign_tron_raw_hash(KNOWN_TRON_PRIV_KEY, &raw_hash_hex).expect("sign TRON raw hash");
        let sig_clean = signature_hex
            .strip_prefix("0x")
            .expect("0x signature prefix");
        assert_eq!(sig_clean.len(), 130);

        let compact_bytes = hex::decode(&sig_clean[..128]).expect("compact signature");
        let v_byte = u8::from_str_radix(&sig_clean[128..130], 16).expect("recovery id");
        assert!(v_byte <= 1, "TRON recovery id must be 0 or 1");

        let recovery_id = RecoveryId::from_u8_masked(v_byte);
        let recoverable_sig = RecoverableSignature::from_compact(&compact_bytes, recovery_id)
            .expect("recoverable sig");

        let msg = Message::from_digest(raw_hash_bytes.into());
        let recovered_pubkey = Secp256k1::new()
            .recover_ecdsa(msg, &recoverable_sig)
            .expect("recover secp256k1 public key");

        let uncompressed = recovered_pubkey.serialize_uncompressed();
        let hash = Keccak256::digest(&uncompressed[1..]);
        let mut payload = Vec::with_capacity(25);
        payload.push(0x41);
        payload.extend_from_slice(&hash[12..]);
        let checksum = Sha256::digest(Sha256::digest(&payload));
        payload.extend_from_slice(&checksum[..4]);
        let recovered_tron_address = bs58::encode(payload).into_string();

        assert_eq!(recovered_tron_address, KNOWN_TRON_ADDRESS);
    }

    #[test]
    fn test_negative_invalid_inputs() {
        // Invalid EVM private key
        assert!(sign_personal_message("invalid_key", "hello").is_err());
        assert!(sign_typed_data("invalid_key", "{}").is_err());

        // Invalid typed data JSON
        assert!(sign_typed_data(KNOWN_EVM_PRIV_KEY, "not_valid_json").is_err());

        // Invalid Solana private key length
        let invalid_seed = vec![0u8; 16];
        assert!(sign_solana_message(&invalid_seed, b"msg").is_err());

        // Invalid TRON raw hash length
        assert!(sign_tron_raw_hash(KNOWN_TRON_PRIV_KEY, "01020304").is_err());
        assert!(sign_tron_raw_hash("invalid_key", "00".repeat(32).as_str()).is_err());
    }
}
