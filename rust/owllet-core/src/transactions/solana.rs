//! Builds and signs Solana transactions from normalized instruction payloads.
//!
//! Hosts resolve the latest blockhash and lookup-table contents, then supply
//! normalized public-key/account metadata and hex instruction data. This module
//! compiles, signs, and serializes offline without a provider or platform SDK.

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;
use serde::Deserialize;
use solana_hash::Hash;
use solana_instruction::{AccountMeta, Instruction};
use solana_message::{v0, AddressLookupTableAccount, VersionedMessage};
use solana_pubkey::Pubkey;
use solana_signer::Signer;
use solana_transaction::versioned::VersionedTransaction;
use std::str::FromStr;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SolanaInstructionPayload {
    program_id: String,
    /// Hex-encoded instruction data (optionally 0x-prefixed).
    data: String,
    keys: Vec<SolanaAccountPayload>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SolanaAccountPayload {
    pubkey: String,
    is_signer: bool,
    is_writable: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SolanaLookupTablePayload {
    key: String,
    addresses: Vec<String>,
}

fn parse_pubkey(value: &str, label: &str) -> Result<Pubkey, String> {
    Pubkey::from_str(value.trim()).map_err(|e| format!("Invalid {label} '{value}': {e}"))
}

/// Compile Relay instruction JSON into a signed Solana v0 transaction.
///
/// * `payer` — base58 fee payer (the user's wallet).
/// * `recent_blockhash` — base58 blockhash fetched just before signing.
/// * `instructions_json` — JSON array: `[{programId, data, keys: [{pubkey,
///   isSigner, isWritable}]}]`.
/// * `lookup_tables_json` — JSON array of resolved tables: `[{key,
///   addresses: [base58...]}]` (pass `[]` when the quote uses none).
/// * `private_key_bytes` — 32-byte seed or 64-byte keypair.
///
/// Returns the base64-encoded signed transaction ready to broadcast.
pub fn build_and_sign_solana_transaction(
    payer: &str,
    recent_blockhash: &str,
    instructions_json: &str,
    lookup_tables_json: &str,
    private_key_bytes: &[u8],
) -> Result<String, String> {
    let payer_key = parse_pubkey(payer, "payer address")?;
    let blockhash = Hash::from_str(recent_blockhash.trim())
        .map_err(|e| format!("Invalid recent blockhash: {e}"))?;

    let raw_instructions: Vec<SolanaInstructionPayload> =
        serde_json::from_str(instructions_json)
            .map_err(|e| format!("Invalid instructions JSON: {e}"))?;
    if raw_instructions.is_empty() {
        return Err("No instructions to compile".to_string());
    }

    let raw_tables: Vec<SolanaLookupTablePayload> = serde_json::from_str(lookup_tables_json)
        .map_err(|e| format!("Invalid lookup tables JSON: {e}"))?;

    let mut instructions = Vec::with_capacity(raw_instructions.len());
    for raw in &raw_instructions {
        let program_id = parse_pubkey(&raw.program_id, "programId")?;
        let data_hex = raw.data.trim().trim_start_matches("0x");
        let data =
            hex::decode(data_hex).map_err(|e| format!("Invalid instruction data hex: {e}"))?;
        let mut accounts = Vec::with_capacity(raw.keys.len());
        for key in &raw.keys {
            let pubkey = parse_pubkey(&key.pubkey, "account pubkey")?;
            accounts.push(AccountMeta {
                pubkey,
                is_signer: key.is_signer,
                is_writable: key.is_writable,
            });
        }
        instructions.push(Instruction {
            program_id,
            accounts,
            data,
        });
    }

    let mut lookup_tables = Vec::with_capacity(raw_tables.len());
    for table in &raw_tables {
        let key = parse_pubkey(&table.key, "lookup table key")?;
        let mut addresses = Vec::with_capacity(table.addresses.len());
        for address in &table.addresses {
            addresses.push(parse_pubkey(address, "lookup table address")?);
        }
        lookup_tables.push(AddressLookupTableAccount { key, addresses });
    }

    let message = v0::Message::try_compile(&payer_key, &instructions, &lookup_tables, blockhash)
        .map_err(|e| format!("Failed to compile Solana message: {e}"))?;
    let versioned = VersionedMessage::V0(message);

    let keypair = crate::accounts::solana_keypair_from_bytes(private_key_bytes, "bridge signer")?;
    if keypair.pubkey() != payer_key {
        return Err("Signer does not match the payer address".to_string());
    }

    let message_bytes = versioned.serialize();
    let signature = keypair.sign_message(&message_bytes);

    let transaction = VersionedTransaction {
        signatures: vec![signature],
        message: versioned,
    };
    let serialized = bincode::serialize(&transaction)
        .map_err(|e| format!("Failed to serialize transaction: {e}"))?;
    Ok(BASE64.encode(serialized))
}

/// Sign a Jupiter (or other) unsigned Solana transaction.
///
/// `serialized_tx_base64` is a full wire-format VersionedTransaction (legacy
/// or v0). If deserialize fails and the first byte has the v0 prefix bit,
/// the payload is treated as a message-only VersionedMessage.
///
/// The matching required-signer slot is overwritten; extra signatures stay.
pub fn sign_serialized_solana_transaction(
    serialized_tx_base64: &str,
    expected_signer: &str,
    private_key_bytes: &[u8],
) -> Result<String, String> {
    let bytes = BASE64
        .decode(serialized_tx_base64.trim())
        .map_err(|e| format!("Invalid base64 transaction: {e}"))?;
    if bytes.is_empty() {
        return Err("Transaction bytes are empty".to_string());
    }

    let mut tx = match bincode::deserialize::<VersionedTransaction>(&bytes) {
        Ok(tx) => tx,
        Err(primary) => {
            if bytes[0] & 0x80 == 0 {
                return Err(format!(
                    "Failed to deserialize Solana transaction: {primary}"
                ));
            }
            let message: VersionedMessage = bincode::deserialize(&bytes).map_err(|e| {
                format!("Failed to deserialize Solana transaction ({primary}) or v0 message ({e})")
            })?;
            let required = message.header().num_required_signatures as usize;
            VersionedTransaction {
                signatures: vec![solana_signature::Signature::default(); required.max(1)],
                message,
            }
        }
    };

    let expected = Pubkey::from_str(expected_signer.trim())
        .map_err(|e| format!("Invalid expected signer: {e}"))?;
    let keypair =
        crate::accounts::solana_keypair_from_bytes(private_key_bytes, "transaction signer")?;
    if keypair.pubkey() != expected {
        return Err("Signer does not match the expected address".to_string());
    }

    let keys = tx.message.static_account_keys();
    let required = tx.message.header().num_required_signatures as usize;
    if required == 0 || keys.len() < required {
        return Err("Solana transaction has invalid required-signer metadata".to_string());
    }
    let signer_index = keys[..required]
        .iter()
        .position(|key| *key == expected)
        .ok_or_else(|| {
            "The transaction does not require the expected Solana account".to_string()
        })?;

    if tx.signatures.len() < required {
        tx.signatures
            .resize(required, solana_signature::Signature::default());
    }

    let message_bytes = tx.message.serialize();
    let signature = keypair.sign_message(&message_bytes);
    tx.signatures[signer_index] = signature;

    let serialized = bincode::serialize(&tx)
        .map_err(|e| format!("Failed to serialize signed transaction: {e}"))?;
    Ok(BASE64.encode(serialized))
}

#[cfg(test)]
mod tests {
    use super::*;
    use solana_keypair::Keypair;
    use solana_message::{MessageHeader, VersionedMessage};
    use solana_signature::Signature;

    #[test]
    fn builds_normalized_v0_instruction_payload_and_verifies_signature() {
        let seed = [7u8; 32];
        let payer = Keypair::new_from_array(seed);
        let receiver = Pubkey::new_from_array([8u8; 32]);
        let instructions = serde_json::json!([{
            "programId": "11111111111111111111111111111111",
            "data": "020000000100000000000000",
            "keys": [
                {"pubkey": payer.pubkey().to_string(), "isSigner": true, "isWritable": true},
                {"pubkey": receiver.to_string(), "isSigner": false, "isWritable": true}
            ]
        }])
        .to_string();
        let signed = build_and_sign_solana_transaction(
            &payer.pubkey().to_string(),
            &Hash::new_from_array([4u8; 32]).to_string(),
            &instructions,
            "[]",
            &seed,
        )
        .expect("build v0 transaction");
        let decoded: VersionedTransaction =
            bincode::deserialize(&BASE64.decode(signed).expect("base64 transaction"))
                .expect("decode transaction");
        let VersionedMessage::V0(message) = &decoded.message else {
            panic!("expected v0")
        };
        assert_eq!(message.header.num_required_signatures, 1);
        assert_eq!(
            message.instructions[0].data,
            hex::decode("020000000100000000000000").unwrap()
        );
        assert_eq!(decoded.signatures.len(), 1);
        assert!(decoded.signatures[0].verify(payer.pubkey().as_ref(), &decoded.message.serialize()));
    }

    fn unsigned_legacy(payer: &Pubkey, extra: Option<&Pubkey>) -> VersionedTransaction {
        let mut keys = vec![*payer];
        let required = if let Some(extra) = extra {
            keys.push(*extra);
            2
        } else {
            1
        };
        let message = VersionedMessage::Legacy(solana_message::Message {
            header: MessageHeader {
                num_required_signatures: required,
                num_readonly_signed_accounts: 0,
                num_readonly_unsigned_accounts: 0,
            },
            account_keys: keys,
            recent_blockhash: Hash::new_from_array([7u8; 32]),
            instructions: vec![],
        });
        VersionedTransaction {
            signatures: vec![Signature::default(); required as usize],
            message,
        }
    }

    #[test]
    fn signs_legacy_one_sig_round_trip() {
        let payer = Keypair::new();
        let unsigned = unsigned_legacy(&payer.pubkey(), None);
        let encoded = BASE64.encode(bincode::serialize(&unsigned).unwrap());
        let signed = sign_serialized_solana_transaction(
            &encoded,
            &payer.pubkey().to_string(),
            &payer.to_bytes(),
        )
        .expect("sign");
        let decoded: VersionedTransaction =
            bincode::deserialize(&BASE64.decode(signed).unwrap()).unwrap();
        assert_eq!(decoded.signatures.len(), 1);
        assert_ne!(decoded.signatures[0], Signature::default());
        assert!(decoded.signatures[0].verify(payer.pubkey().as_ref(), &decoded.message.serialize()));
    }

    #[test]
    fn preserves_extra_signature_slot() {
        let payer = Keypair::new();
        let extra = Keypair::new();
        let extra_sig = extra.sign_message(b"prefill");
        let mut unsigned = unsigned_legacy(&payer.pubkey(), Some(&extra.pubkey()));
        unsigned.signatures[1] = extra_sig;
        let encoded = BASE64.encode(bincode::serialize(&unsigned).unwrap());
        let signed = sign_serialized_solana_transaction(
            &encoded,
            &payer.pubkey().to_string(),
            &payer.to_bytes(),
        )
        .expect("sign");
        let decoded: VersionedTransaction =
            bincode::deserialize(&BASE64.decode(signed).unwrap()).unwrap();
        assert_eq!(decoded.signatures[1], extra_sig);
        assert!(decoded.signatures[0].verify(payer.pubkey().as_ref(), &decoded.message.serialize()));
    }

    #[test]
    fn rejects_wrong_expected_signer() {
        let payer = Keypair::new();
        let other = Keypair::new();
        let unsigned = unsigned_legacy(&payer.pubkey(), None);
        let encoded = BASE64.encode(bincode::serialize(&unsigned).unwrap());
        let err = sign_serialized_solana_transaction(
            &encoded,
            &other.pubkey().to_string(),
            &payer.to_bytes(),
        )
        .unwrap_err();
        assert!(err.contains("does not match") || err.contains("does not require"));
    }
}
