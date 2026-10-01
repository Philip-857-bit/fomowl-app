use zeroize::Zeroize;

#[allow(clippy::too_many_arguments)]
pub fn sign_legacy_evm_transaction(
    mut private_key_hex: String,
    chain_id: u64,
    nonce: u64,
    gas_price_wei: String,
    gas_limit: u64,
    to_address: String,
    value_wei: String,
    data_hex: String,
) -> Result<String, String> {
    let result = (|| {
        let gas_price_u128 = gas_price_wei
            .trim()
            .parse::<u128>()
            .map_err(|e| format!("Invalid gas price: {e}"))?;

        let request = owllet_core::LegacyEvmTransactionRequest {
            chain_id,
            nonce,
            gas_price_wei: gas_price_u128,
            gas_limit,
            to: to_address,
            value_wei,
            data_hex,
        };

        let signed = owllet_core::sign_legacy_evm_transaction(&private_key_hex, &request)?;
        Ok(signed.raw_transaction_hex)
    })();

    private_key_hex.zeroize();
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    const EIP155_PRIV_KEY: &str =
        "4646464646464646464646464646464646464646464646464646464646464646";
    const EIP155_RECIPIENT: &str = "0x3535353535353535353535353535353535353535";
    const EXPECTED_EIP155_RAW_TX: &str =
        "0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83";

    #[test]
    fn test_adapter_official_eip155_vector() {
        let raw_tx = sign_legacy_evm_transaction(
            EIP155_PRIV_KEY.to_string(),
            1,
            9,
            "20000000000".to_string(),
            21000,
            EIP155_RECIPIENT.to_string(),
            "1000000000000000000".to_string(),
            "".to_string(),
        )
        .expect("signing official EIP-155 vector via adapter");

        assert_eq!(
            raw_tx, EXPECTED_EIP155_RAW_TX,
            "Adapter must return byte-for-byte exact official EIP-155 raw transaction"
        );
    }

    #[test]
    fn test_adapter_invalid_gas_price() {
        let result = sign_legacy_evm_transaction(
            EIP155_PRIV_KEY.to_string(),
            1,
            9,
            "invalid_gas_price".to_string(),
            21000,
            EIP155_RECIPIENT.to_string(),
            "1000000000000000000".to_string(),
            "".to_string(),
        );

        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Invalid gas price"));
    }

    #[test]
    fn test_adapter_invalid_key() {
        let result = sign_legacy_evm_transaction(
            "not_a_valid_hex_key".to_string(),
            1,
            9,
            "20000000000".to_string(),
            21000,
            EIP155_RECIPIENT.to_string(),
            "1000000000000000000".to_string(),
            "".to_string(),
        );

        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Invalid private key"));
    }

    #[test]
    fn test_adapter_invalid_address() {
        let result = sign_legacy_evm_transaction(
            EIP155_PRIV_KEY.to_string(),
            1,
            9,
            "20000000000".to_string(),
            21000,
            "not_an_address".to_string(),
            "1000000000000000000".to_string(),
            "".to_string(),
        );

        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Invalid recipient address"));
    }
}
