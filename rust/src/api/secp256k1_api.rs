pub fn sign_personal_message(private_key_hex: String, message: String) -> Result<String, String> {
    let private_key_hex = zeroize::Zeroizing::new(private_key_hex);
    owllet_core::signing::sign_personal_message(&private_key_hex, &message)
}

pub fn sign_typed_data(private_key_hex: String, json_data: String) -> Result<String, String> {
    let private_key_hex = zeroize::Zeroizing::new(private_key_hex);
    owllet_core::signing::sign_typed_data(&private_key_hex, &json_data)
}

#[allow(dead_code)]
pub(crate) fn sign_digest_with_recovery_id(
    private_key_hex: String,
    digest: [u8; 32],
    ethereum_recovery_id: bool,
) -> Result<String, String> {
    let private_key_hex = zeroize::Zeroizing::new(private_key_hex);
    owllet_core::signing::sign_digest_with_recovery_id(
        &private_key_hex,
        digest,
        ethereum_recovery_id,
    )
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
