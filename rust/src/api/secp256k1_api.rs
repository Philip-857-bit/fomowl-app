use ethers_core::types::transaction::eip712::{Eip712, TypedData};
use secp256k1::{Message, Secp256k1, SecretKey};
use sha3::{Digest, Keccak256};
use std::str::FromStr;

fn sign_digest(private_key_hex: &str, digest: [u8; 32]) -> Result<String, String> {
    sign_digest_inner(private_key_hex, digest, true)
}

pub(crate) fn sign_digest_with_recovery_id(
    private_key_hex: String,
    digest: [u8; 32],
    ethereum_recovery_id: bool,
) -> Result<String, String> {
    sign_digest_inner(&private_key_hex, digest, ethereum_recovery_id)
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

pub fn sign_personal_message(private_key_hex: String, message: String) -> Result<String, String> {
    let message_bytes = decode_personal_sign_payload(&message);
    let prefix = format!("\x19Ethereum Signed Message:\n{}", message_bytes.len());
    let mut prefixed_message = prefix.into_bytes();
    prefixed_message.extend_from_slice(&message_bytes);

    let hash = Keccak256::digest(&prefixed_message);

    let mut hash_arr = [0u8; 32];
    hash_arr.copy_from_slice(&hash);
    sign_digest(&private_key_hex, hash_arr)
}

fn decode_personal_sign_payload(message: &str) -> Vec<u8> {
    let Some(hex_payload) = message
        .strip_prefix("0x")
        .or_else(|| message.strip_prefix("0X"))
    else {
        return message.as_bytes().to_vec();
    };

    if hex_payload.len() % 2 != 0 {
        return message.as_bytes().to_vec();
    }

    hex::decode(hex_payload).unwrap_or_else(|_| message.as_bytes().to_vec())
}

pub fn sign_typed_data(private_key_hex: String, json_data: String) -> Result<String, String> {
    let typed_data: TypedData =
        serde_json::from_str(&json_data).map_err(|e| format!("Invalid typed data JSON: {}", e))?;
    let digest = typed_data
        .encode_eip712()
        .map_err(|e| format!("Failed to encode typed data: {}", e))?;
    sign_digest(&private_key_hex, digest)
}

#[cfg(test)]
mod tests {
    use super::{sign_personal_message, sign_typed_data};
    use ethers_core::types::{transaction::eip712::TypedData, Signature};

    #[test]
    fn personal_sign_decodes_eip_1193_hex_data_before_signing() {
        let private_key = "4c0883a69102937d6231471b5dbb6204fe5129617082794a7a4da5f6d7d28e17";

        let utf8_signature = sign_personal_message(private_key.to_string(), "hello".to_string())
            .expect("UTF-8 personal signature");
        let hex_signature =
            sign_personal_message(private_key.to_string(), "0x68656c6c6f".to_string())
                .expect("hex personal signature");

        assert_eq!(hex_signature, utf8_signature);
        assert!(hex_signature.starts_with("0x"));
        assert_eq!(hex_signature.len(), 132);
    }

    #[test]
    fn signs_typed_data_and_recovers_expected_address() {
        let private_key = "4c0883a69102937d6231471b5dbb6204fe5129617082794a7a4da5f6d7d28e17";
        let typed_data_json = r#"{
          "types": {
            "EIP712Domain": [
              {"name": "name", "type": "string"},
              {"name": "version", "type": "string"},
              {"name": "chainId", "type": "uint256"},
              {"name": "verifyingContract", "type": "address"}
            ],
            "Mail": [
              {"name": "contents", "type": "string"}
            ]
          },
          "primaryType": "Mail",
          "domain": {
            "name": "Owllet Test",
            "version": "1",
            "chainId": 56,
            "verifyingContract": "0x0000000000000000000000000000000000000001"
          },
          "message": {
            "contents": "Discover typed data signature"
          }
        }"#;

        let signature = sign_typed_data(private_key.to_string(), typed_data_json.to_string())
            .expect("typed data signature");
        assert!(signature.starts_with("0x"));
        assert_eq!(signature.len(), 132);

        let parsed_signature: Signature = signature.parse().expect("signature parse");
        let typed_data: TypedData =
            serde_json::from_str(typed_data_json).expect("typed data parse");
        let recovered = parsed_signature
            .recover_typed_data(&typed_data)
            .expect("recover typed data");

        assert_eq!(
            format!("{:#x}", recovered),
            "0xb7334f8beed03edeae7c3e9730b49166c2f76329"
        );
    }
}
