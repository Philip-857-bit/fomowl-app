#![cfg(feature = "evm")]

use alloy::consensus::{SignableTransaction, TxEnvelope};
use alloy::eips::eip2718::Decodable2718;
use alloy::primitives::{TxKind, U256};
use alloy::signers::local::PrivateKeySigner;
use owllet_core::{sign_evm_transaction, EvmTransactionFee, EvmTransactionRequest};
use std::str::FromStr;

const KEY: &str = "8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63";

fn fixture() -> EvmTransactionRequest {
    EvmTransactionRequest {
        chain_id: 4,
        nonce: 819,
        gas_limit: 35552,
        to: Some("0x000000000000000000000000000000000000aaaa".to_string()),
        value_wei: "43203529".to_string(),
        data_hex: "".to_string(),
        fee: EvmTransactionFee::Eip1559 {
            max_fee_per_gas_wei: 121212,
            max_priority_fee_per_gas_wei: 75853,
        },
    }
}

#[test]
fn eip1559_matches_independent_web3dart_fixture_and_recovers_sender() {
    // web3dart 2.7.3 test/core/sign_transaction_test.dart fixture (unwrapped
    // EIP-2718 bytes). The expected signature was not generated with Alloy.
    const EXPECTED: &str = "0x02f86e048203338301284d8301d97c828ae094000000000000000000000000000000000000aaaa8402933bc980c080a00f924cb68412c8f1cfd74d9b581c71eeaf94fff6abdde3e5b02ca6b2931dcf47a07dd1c50027c3e31f8b565e25ce68a5072110f61fce5eee81b195dd51273c2f83";
    let signed = sign_evm_transaction(KEY, &fixture()).expect("sign fixture");
    assert_eq!(signed.raw_transaction_hex, EXPECTED);
    let bytes = hex::decode(EXPECTED.trim_start_matches("0x")).expect("raw bytes");
    let mut remaining = bytes.as_slice();
    let envelope = TxEnvelope::decode_2718(&mut remaining).expect("decode envelope");
    assert!(remaining.is_empty());
    let TxEnvelope::Eip1559(tx) = envelope else {
        panic!("expected type 2")
    };
    let recovered = tx
        .signature()
        .recover_address_from_prehash(&tx.tx().signature_hash())
        .expect("recover signer");
    assert_eq!(
        recovered,
        PrivateKeySigner::from_str(KEY).expect("signer").address()
    );
    assert_eq!(tx.tx().max_fee_per_gas, 121212);
    assert_eq!(tx.tx().max_priority_fee_per_gas, 75853);
    assert_eq!(tx.tx().value, U256::from(43203529));
}

#[test]
fn contract_creation_preserves_data_and_empty_destination_for_both_fee_types() {
    for fee in [
        EvmTransactionFee::Legacy {
            gas_price_wei: 1000,
        },
        fixture().fee,
    ] {
        let mut request = fixture();
        request.to = None;
        request.data_hex = "0x60006000".to_string();
        request.fee = fee;
        let signed = sign_evm_transaction(KEY, &request).expect("sign creation");
        let bytes =
            hex::decode(signed.raw_transaction_hex.trim_start_matches("0x")).expect("raw bytes");
        let envelope = TxEnvelope::decode_2718(&mut bytes.as_slice()).expect("decode envelope");
        match envelope {
            TxEnvelope::Legacy(tx) => {
                assert_eq!(tx.tx().to, TxKind::Create);
                assert_eq!(tx.tx().input.as_ref(), &[0x60, 0, 0x60, 0]);
            }
            TxEnvelope::Eip1559(tx) => {
                assert_eq!(tx.tx().to, TxKind::Create);
                assert_eq!(tx.tx().input.as_ref(), &[0x60, 0, 0x60, 0]);
            }
            _ => panic!("unexpected transaction type"),
        }
    }
}

#[test]
fn rejects_invalid_fee_policy_and_invalid_call_destination() {
    let mut request = fixture();
    request.fee = EvmTransactionFee::Eip1559 {
        max_fee_per_gas_wei: 1,
        max_priority_fee_per_gas_wei: 2,
    };
    assert!(sign_evm_transaction(KEY, &request)
        .unwrap_err()
        .contains("Priority fee"));
    request = fixture();
    request.to = Some("".to_string());
    assert!(sign_evm_transaction(KEY, &request)
        .unwrap_err()
        .contains("recipient"));
    request = fixture();
    request.chain_id = 0;
    assert!(sign_evm_transaction(KEY, &request).is_err());
    request = fixture();
    request.gas_limit = 0;
    assert!(sign_evm_transaction(KEY, &request).is_err());
}
