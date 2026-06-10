//! Builds and signs Solana v0 transactions from Relay-style instruction
//! payloads (used by the cross-chain bridge when Solana is the origin).
//!
//! Relay quotes for SVM origins return `instructions` (string pubkeys,
//! hex-encoded data) plus `addressLookupTableAddresses` instead of a
//! prebuilt transaction. The Dart side resolves the lookup-table contents
//! and the latest blockhash through the backend, then calls
//! [`build_and_sign_solana_transaction`] to compile, sign, and serialize.

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
struct RelayInstruction {
    program_id: String,
    /// Hex-encoded instruction data (optionally 0x-prefixed).
    data: String,
    keys: Vec<RelayAccountMeta>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct RelayAccountMeta {
    pubkey: String,
    is_signer: bool,
    is_writable: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct RelayLookupTable {
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
    payer: String,
    recent_blockhash: String,
    instructions_json: String,
    lookup_tables_json: String,
    private_key_bytes: Vec<u8>,
) -> Result<String, String> {
    let payer_key = parse_pubkey(&payer, "payer address")?;
    let blockhash = Hash::from_str(recent_blockhash.trim())
        .map_err(|e| format!("Invalid recent blockhash: {e}"))?;

    let raw_instructions: Vec<RelayInstruction> = serde_json::from_str(&instructions_json)
        .map_err(|e| format!("Invalid instructions JSON: {e}"))?;
    if raw_instructions.is_empty() {
        return Err("No instructions to compile".to_string());
    }

    let raw_tables: Vec<RelayLookupTable> = serde_json::from_str(&lookup_tables_json)
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

    let keypair =
        crate::api::bip32::solana_keypair_from_bytes(private_key_bytes, "bridge signer")?;
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
