use alloy::consensus::{SignableTransaction, TxEnvelope, TxLegacy};
use alloy::eips::eip2718::Encodable2718;
use alloy::network::TxSignerSync;
use alloy::primitives::{Address, Bytes, TxKind, U256};
use alloy::signers::local::PrivateKeySigner;
use std::str::FromStr;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LegacyEvmTransactionRequest {
    pub chain_id: u64,
    pub nonce: u64,
    pub gas_price_wei: u128,
    pub gas_limit: u64,
    pub to: String,
    pub value_wei: String,
    pub data_hex: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SignedEvmTransaction {
    pub raw_transaction_hex: String,
    pub transaction_hash: String,
}

pub fn sign_legacy_evm_transaction(
    private_key_hex: &str,
    request: &LegacyEvmTransactionRequest,
) -> Result<SignedEvmTransaction, String> {
    if request.chain_id == 0 {
        return Err("Chain ID must be non-zero for EIP-155 replay protection".to_string());
    }

    let normalized_key = private_key_hex
        .trim()
        .strip_prefix("0x")
        .unwrap_or(private_key_hex.trim());
    let signer = PrivateKeySigner::from_str(normalized_key)
        .map_err(|e| format!("Invalid private key: {e}"))?;

    let to_address = Address::from_str(request.to.trim())
        .map_err(|e| format!("Invalid recipient address: {e}"))?;

    let value = U256::from_str(&request.value_wei)
        .map_err(|e| format!("Invalid transaction value: {e}"))?;

    let data_trimmed = request.data_hex.trim();
    let data_clean = data_trimmed
        .strip_prefix("0x")
        .or_else(|| data_trimmed.strip_prefix("0X"))
        .unwrap_or(data_trimmed);
    let input = if data_clean.is_empty() {
        Bytes::default()
    } else {
        let bytes = hex::decode(data_clean).map_err(|e| format!("Invalid calldata hex: {e}"))?;
        Bytes::from(bytes)
    };

    let mut tx = TxLegacy {
        chain_id: Some(request.chain_id),
        nonce: request.nonce,
        gas_price: request.gas_price_wei,
        gas_limit: request.gas_limit,
        to: TxKind::Call(to_address),
        value,
        input,
    };

    let signature = signer
        .sign_transaction_sync(&mut tx)
        .map_err(|e| format!("Failed to sign legacy transaction: {e}"))?;

    let signed = tx.into_signed(signature);
    let envelope: TxEnvelope = signed.into();
    let raw_bytes = envelope.encoded_2718();
    let tx_hash = envelope.tx_hash();

    Ok(SignedEvmTransaction {
        raw_transaction_hex: format!("0x{}", hex::encode(raw_bytes)),
        transaction_hash: format!("{tx_hash:#x}"),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::eips::eip2718::Decodable2718;

    const EIP155_PRIV_KEY: &str =
        "4646464646464646464646464646464646464646464646464646464646464646";
    const EIP155_RECIPIENT: &str = "0x3535353535353535353535353535353535353535";
    const EXPECTED_EIP155_RAW_TX: &str =
        "0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83";
    const EXPECTED_EIP155_SIGNING_HASH: &str =
        "0xdaf5a779ae972f972197303d7b574746c7ef83eadac0f2791ad23db92e4c8e53";

    fn eip155_request() -> LegacyEvmTransactionRequest {
        LegacyEvmTransactionRequest {
            chain_id: 1,
            nonce: 9,
            gas_price_wei: 20000000000,
            gas_limit: 21000,
            to: EIP155_RECIPIENT.to_string(),
            value_wei: "1000000000000000000".to_string(),
            data_hex: "".to_string(),
        }
    }

    #[test]
    fn test_official_eip155_vector() {
        let req = eip155_request();

        // Verify unsigned signing hash via SignableTransaction
        let to_address = Address::from_str(EIP155_RECIPIENT).unwrap();
        let tx = TxLegacy {
            chain_id: Some(req.chain_id),
            nonce: req.nonce,
            gas_price: req.gas_price_wei,
            gas_limit: req.gas_limit,
            to: TxKind::Call(to_address),
            value: U256::from_str(&req.value_wei).unwrap(),
            input: Bytes::default(),
        };
        let signing_hash = tx.signature_hash();
        assert_eq!(
            format!("{signing_hash:#x}"),
            EXPECTED_EIP155_SIGNING_HASH,
            "Alloy TxLegacy signing hash must match official EIP-155 specification"
        );

        // Sign transaction and verify byte-for-byte exact raw hex match
        let signed = sign_legacy_evm_transaction(EIP155_PRIV_KEY, &req)
            .expect("sign official EIP-155 vector");
        assert_eq!(
            signed.raw_transaction_hex, EXPECTED_EIP155_RAW_TX,
            "Alloy raw signed transaction must match official EIP-155 fixture byte-for-byte"
        );
        assert!(signed.transaction_hash.starts_with("0x"));
        assert_eq!(signed.transaction_hash.len(), 66);
    }

    #[test]
    fn test_chain_id_replay_protection() {
        let mut req_eth = eip155_request();
        req_eth.chain_id = 1;

        let mut req_bsc = eip155_request();
        req_bsc.chain_id = 56;

        let signed_eth = sign_legacy_evm_transaction(EIP155_PRIV_KEY, &req_eth).unwrap();
        let signed_bsc = sign_legacy_evm_transaction(EIP155_PRIV_KEY, &req_bsc).unwrap();

        assert_ne!(
            signed_eth.raw_transaction_hex, signed_bsc.raw_transaction_hex,
            "Transactions with different chain IDs must produce different raw bytes"
        );
        assert_ne!(
            signed_eth.transaction_hash, signed_bsc.transaction_hash,
            "Transactions with different chain IDs must produce different transaction hashes"
        );
    }

    #[test]
    fn test_non_empty_calldata() {
        let mut req = eip155_request();
        req.to = "0xdAC17F958D2ee523a2206206994597C13D831ec7".to_string();
        req.value_wei = "0".to_string();
        // ERC-20 transfer(address,uint256) signature + arguments
        req.data_hex = "a9059cbb00000000000000000000000035353535353535353535353535353535353535350000000000000000000000000000000000000000000000000de0b6b3a7640000".to_string();

        let signed = sign_legacy_evm_transaction(EIP155_PRIV_KEY, &req)
            .expect("sign transaction with calldata");
        assert!(signed.raw_transaction_hex.starts_with("0x"));

        // Test with 0x prefix on calldata
        req.data_hex = format!("0x{}", req.data_hex);
        let signed_with_prefix = sign_legacy_evm_transaction(EIP155_PRIV_KEY, &req)
            .expect("sign transaction with 0x-prefixed calldata");
        assert_eq!(
            signed.raw_transaction_hex,
            signed_with_prefix.raw_transaction_hex
        );

        let raw_bytes = hex::decode(signed.raw_transaction_hex.trim_start_matches("0x"))
            .expect("raw transaction bytes");
        let mut remaining = raw_bytes.as_slice();
        let envelope = TxEnvelope::decode_2718(&mut remaining).expect("decode transaction");
        assert!(remaining.is_empty(), "no trailing transaction bytes");
        let TxEnvelope::Legacy(transaction) = envelope else {
            panic!("expected legacy transaction");
        };
        let transaction = transaction.tx();
        assert_eq!(transaction.chain_id, Some(req.chain_id));
        assert_eq!(transaction.nonce, req.nonce);
        assert_eq!(transaction.gas_price, req.gas_price_wei);
        assert_eq!(transaction.gas_limit, req.gas_limit);
        assert_eq!(
            transaction.to,
            TxKind::Call(Address::from_str(&req.to).expect("token contract address"))
        );
        assert_eq!(transaction.value, U256::ZERO);
        assert_eq!(
            transaction.input.as_ref(),
            hex::decode(req.data_hex.trim_start_matches("0x")).expect("calldata bytes")
        );
    }

    #[test]
    fn test_recover_signer_from_envelope() {
        let req = eip155_request();
        let signed = sign_legacy_evm_transaction(EIP155_PRIV_KEY, &req).unwrap();

        let raw_bytes =
            hex::decode(signed.raw_transaction_hex.strip_prefix("0x").unwrap()).unwrap();
        let envelope = TxEnvelope::decode_2718(&mut raw_bytes.as_slice()).expect("decode 2718");
        if let TxEnvelope::Legacy(ref signed_tx) = envelope {
            let hash = signed_tx.tx().signature_hash();
            let recovered_signer = signed_tx
                .signature()
                .recover_address_from_prehash(&hash)
                .expect("recover signer");
            let signer = PrivateKeySigner::from_str(EIP155_PRIV_KEY).unwrap();
            assert_eq!(recovered_signer, signer.address());
        } else {
            panic!("expected Legacy envelope");
        }
    }

    #[test]
    fn test_negative_invalid_inputs() {
        let req = eip155_request();

        // Invalid private key
        assert!(sign_legacy_evm_transaction("invalid_key", &req).is_err());
        assert!(sign_legacy_evm_transaction("0x1234", &req).is_err());

        // Invalid recipient address
        let mut bad_req = req.clone();
        bad_req.to = "not_an_address".to_string();
        assert!(sign_legacy_evm_transaction(EIP155_PRIV_KEY, &bad_req).is_err());

        // Invalid value
        let mut bad_val_req = req.clone();
        bad_val_req.value_wei = "invalid_number".to_string();
        assert!(sign_legacy_evm_transaction(EIP155_PRIV_KEY, &bad_val_req).is_err());

        // Invalid calldata hex
        let mut bad_data_req = req.clone();
        bad_data_req.data_hex = "not_hex".to_string();
        assert!(sign_legacy_evm_transaction(EIP155_PRIV_KEY, &bad_data_req).is_err());

        // Zero chain ID
        let mut zero_chain_req = req.clone();
        zero_chain_req.chain_id = 0;
        assert!(sign_legacy_evm_transaction(EIP155_PRIV_KEY, &zero_chain_req).is_err());
    }
}
