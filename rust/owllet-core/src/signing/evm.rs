use crate::signing::secp256k1::sign_digest;
use ethers_core::types::transaction::eip712::{Eip712, TypedData};
use sha3::{Digest, Keccak256};

pub fn decode_personal_sign_payload(message: &str) -> Vec<u8> {
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

pub fn sign_personal_message(private_key_hex: &str, message: &str) -> Result<String, String> {
    let message_bytes = decode_personal_sign_payload(message);
    let prefix = format!("\x19Ethereum Signed Message:\n{}", message_bytes.len());
    let mut prefixed_message = prefix.into_bytes();
    prefixed_message.extend_from_slice(&message_bytes);

    let hash = Keccak256::digest(&prefixed_message);

    let mut hash_arr = [0u8; 32];
    hash_arr.copy_from_slice(&hash);
    sign_digest(private_key_hex, hash_arr)
}

pub fn sign_typed_data(private_key_hex: &str, json_data: &str) -> Result<String, String> {
    let typed_data: TypedData =
        serde_json::from_str(json_data).map_err(|e| format!("Invalid typed data JSON: {e}"))?;
    let digest = typed_data
        .encode_eip712()
        .map_err(|e| format!("Failed to encode typed data: {e}"))?;
    sign_digest(private_key_hex, digest)
}
