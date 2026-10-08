use zeroize::Zeroize;

/// General transaction adapter. Fees must select exactly one engine policy;
/// fee discovery and user permission checks remain with the host.
#[allow(clippy::too_many_arguments)]
pub fn sign_evm_transaction(
    private_key_hex: String,
    chain_id: u64,
    nonce: u64,
    gas_limit: u64,
    to_address: Option<String>,
    value_wei: String,
    data_hex: String,
    gas_price_wei: Option<String>,
    max_fee_per_gas_wei: Option<String>,
    max_priority_fee_per_gas_wei: Option<String>,
) -> Result<String, String> {
    let private_key_hex = zeroize::Zeroizing::new(private_key_hex);
    let parse_fee = |value: &str| {
        value
            .trim()
            .parse::<u128>()
            .map_err(|e| format!("Invalid gas fee: {e}"))
    };
    let fee = match (
        gas_price_wei,
        max_fee_per_gas_wei,
        max_priority_fee_per_gas_wei,
    ) {
        (Some(gas), None, None) => owllet_core::EvmTransactionFee::Legacy {
            gas_price_wei: parse_fee(&gas)?,
        },
        (None, Some(max), Some(priority)) => owllet_core::EvmTransactionFee::Eip1559 {
            max_fee_per_gas_wei: parse_fee(&max)?,
            max_priority_fee_per_gas_wei: parse_fee(&priority)?,
        },
        _ => {
            return Err(
                "Select legacy gas price or both EIP-1559 fees, without mixing them".to_string(),
            )
        }
    };
    let request = owllet_core::EvmTransactionRequest {
        chain_id,
        nonce,
        gas_limit,
        to: to_address,
        value_wei,
        data_hex,
        fee,
    };
    let signed = owllet_core::sign_evm_transaction(&private_key_hex, &request)?;
    Ok(signed.raw_transaction_hex)
}

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
    fn general_adapter_preserves_official_legacy_fixture() {
        let raw = sign_evm_transaction(
            EIP155_PRIV_KEY.to_string(),
            1,
            9,
            21000,
            Some(EIP155_RECIPIENT.to_string()),
            "1000000000000000000".to_string(),
            "".to_string(),
            Some("20000000000".to_string()),
            None,
            None,
        )
        .expect("sign general adapter fixture");
        assert_eq!(raw, EXPECTED_EIP155_RAW_TX);
    }

    #[test]
    fn general_adapter_rejects_ambiguous_fee_policy() {
        let error = sign_evm_transaction(
            EIP155_PRIV_KEY.to_string(),
            1,
            0,
            21000,
            Some(EIP155_RECIPIENT.to_string()),
            "0".to_string(),
            "".to_string(),
            Some("1".to_string()),
            Some("2".to_string()),
            Some("1".to_string()),
        )
        .expect_err("mixed fee policies");
        assert!(error.contains("without mixing"));
    }

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
