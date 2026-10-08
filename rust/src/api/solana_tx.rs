//! Flutter adapter for the shared Solana transaction engine.
//! Owned secret inputs are wiped on success and every error path.

pub fn build_and_sign_solana_transaction(
    payer: String,
    recent_blockhash: String,
    instructions_json: String,
    lookup_tables_json: String,
    private_key_bytes: Vec<u8>,
) -> Result<String, String> {
    let key = zeroize::Zeroizing::new(private_key_bytes);
    owllet_core::transactions::solana::build_and_sign_solana_transaction(
        &payer,
        &recent_blockhash,
        &instructions_json,
        &lookup_tables_json,
        &key,
    )
}

pub fn sign_serialized_solana_transaction(
    serialized_tx_base64: String,
    expected_signer: String,
    private_key_bytes: Vec<u8>,
) -> Result<String, String> {
    let key = zeroize::Zeroizing::new(private_key_bytes);
    owllet_core::transactions::solana::sign_serialized_solana_transaction(
        &serialized_tx_base64,
        &expected_signer,
        &key,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use base64::engine::general_purpose::STANDARD as BASE64;
    use base64::Engine;
    use solana_hash::Hash;
    use solana_keypair::Keypair;
    use solana_message::{MessageHeader, VersionedMessage};
    use solana_pubkey::Pubkey;
    use solana_signature::Signature;
    use solana_signer::Signer;
    use solana_transaction::versioned::VersionedTransaction;

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
            encoded,
            payer.pubkey().to_string(),
            payer.to_bytes().to_vec(),
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
            encoded,
            payer.pubkey().to_string(),
            payer.to_bytes().to_vec(),
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
            encoded,
            other.pubkey().to_string(),
            payer.to_bytes().to_vec(),
        )
        .unwrap_err();
        assert!(err.contains("does not match") || err.contains("does not require"));
    }
}
