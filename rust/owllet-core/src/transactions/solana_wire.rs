//! Exact single-signer message-to-transaction wire encoding, shared by hosts.
use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use solana_message::VersionedMessage;
use solana_pubkey::Pubkey;
use solana_signature::Signature;
use solana_signer::Signer;
use solana_transaction::versioned::VersionedTransaction;
use std::str::FromStr;

fn decode_transaction(bytes: &[u8]) -> Result<VersionedTransaction, String> {
    let tx: VersionedTransaction =
        bincode::deserialize(bytes).map_err(|_| "Malformed Solana transaction")?;
    let required = tx.message.header().num_required_signatures as usize;
    if required == 0
        || tx.signatures.len() != required
        || tx.message.static_account_keys().len() < required
    {
        return Err("Invalid Solana transaction signer metadata".into());
    }
    if bincode::serialize(&tx).map_err(|_| "Could not serialize Solana transaction")? != bytes {
        return Err("Solana transaction has trailing or noncanonical bytes".into());
    }
    Ok(tx)
}

pub fn solana_transaction_message_bytes(transaction: &[u8]) -> Result<Vec<u8>, String> {
    Ok(decode_transaction(transaction)?.message.serialize())
}

/// Attaches a signature produced by a trusted signer/hardware adapter to its
/// required slot. Other signatures and message bytes are preserved. This wire
/// operation does not authenticate an externally supplied signature itself.
pub fn attach_solana_transaction_signature(
    transaction: &[u8],
    signer_address: &str,
    signature: &[u8],
) -> Result<Vec<u8>, String> {
    let signature = Signature::try_from(signature).map_err(|_| "Malformed Solana signature")?;
    let signer =
        Pubkey::from_str(signer_address).map_err(|_| "Invalid connected Solana account")?;
    let mut tx = decode_transaction(transaction)?;
    let required = tx.message.header().num_required_signatures as usize;
    let index = tx.message.static_account_keys()[..required]
        .iter()
        .position(|key| *key == signer)
        .ok_or("The transaction does not require the connected Solana account")?;
    tx.signatures[index] = signature;
    bincode::serialize(&tx).map_err(|_| "Could not serialize signed Solana transaction".into())
}

/// Signs an already approved serialized legacy/v0 message. Rejects missing or
/// extra signers, a different fee payer, and trailing/noncanonical message bytes.
pub fn sign_solana_transaction_message(
    expected_signer: &str,
    message_bytes: &[u8],
    private_key_bytes: &[u8],
) -> Result<String, String> {
    let keypair =
        crate::accounts::solana_keypair_from_bytes(private_key_bytes, "Solana private key")?;
    if keypair.pubkey().to_string() != expected_signer {
        return Err("Solana message signer does not match account".into());
    }
    let message: VersionedMessage =
        bincode::deserialize(message_bytes).map_err(|_| "Invalid serialized Solana message")?;
    if message.header().num_required_signatures != 1
        || message.static_account_keys().first() != Some(&keypair.pubkey())
    {
        return Err("Solana message must require only the expected account signer".into());
    }
    if message.serialize() != message_bytes {
        return Err("Solana message has trailing or noncanonical bytes".into());
    }
    let transaction = VersionedTransaction {
        signatures: vec![keypair.sign_message(message_bytes)],
        message,
    };
    let bytes = bincode::serialize(&transaction)
        .map_err(|_| "Could not serialize signed Solana transaction")?;
    Ok(BASE64.encode(bytes))
}

#[cfg(test)]
mod tests {
    use super::*;
    use solana_message::{legacy::Message, MessageHeader};
    use solana_pubkey::Pubkey;
    #[test]
    fn external_signature_uses_the_matching_slot_and_preserves_other_signatures() {
        let first = Pubkey::new_from_array([7; 32]);
        let second = Pubkey::new_from_array([8; 32]);
        let tx = VersionedTransaction {
            signatures: vec![Signature::from([3; 64]), Signature::default()],
            message: VersionedMessage::Legacy(Message {
                header: MessageHeader {
                    num_required_signatures: 2,
                    num_readonly_signed_accounts: 0,
                    num_readonly_unsigned_accounts: 0,
                },
                account_keys: vec![first, second],
                recent_blockhash: Default::default(),
                instructions: vec![],
            }),
        };
        let bytes = bincode::serialize(&tx).unwrap();
        let signed =
            attach_solana_transaction_signature(&bytes, &second.to_string(), &[4; 64]).unwrap();
        let decoded: VersionedTransaction = bincode::deserialize(&signed).unwrap();
        assert_eq!(decoded.signatures[0], tx.signatures[0]);
        assert_eq!(decoded.signatures[1], Signature::from([4; 64]));
        assert_eq!(
            solana_transaction_message_bytes(&signed).unwrap(),
            tx.message.serialize()
        );
        assert!(attach_solana_transaction_signature(
            &bytes,
            &Pubkey::default().to_string(),
            &[4; 64]
        )
        .is_err());
        assert!(
            attach_solana_transaction_signature(&bytes, &second.to_string(), &[4; 63]).is_err()
        );
        let mut trailing = bytes;
        trailing.push(0);
        assert!(solana_transaction_message_bytes(&trailing).is_err());
    }
    #[test]
    fn exact_wire_roundtrip_checks_signer_and_preserves_message() {
        let keypair = crate::accounts::solana_keypair_from_bytes(&[7; 32], "test").unwrap();
        let signer = keypair.pubkey().to_string();
        let mut message = VersionedMessage::Legacy(Message {
            header: MessageHeader {
                num_required_signatures: 1,
                num_readonly_signed_accounts: 0,
                num_readonly_unsigned_accounts: 0,
            },
            account_keys: vec![keypair.pubkey()],
            recent_blockhash: Default::default(),
            instructions: vec![],
        });
        let serialized = message.serialize();
        let wire = BASE64
            .decode(sign_solana_transaction_message(&signer, &serialized, &[7; 32]).unwrap())
            .unwrap();
        assert_eq!(wire[0], 1);
        assert_eq!(&wire[65..], serialized);
        let decoded: VersionedTransaction = bincode::deserialize(&wire).unwrap();
        assert!(decoded.signatures[0].verify(keypair.pubkey().as_ref(), &serialized));
        assert!(sign_solana_transaction_message(
            &Pubkey::default().to_string(),
            &serialized,
            &[7; 32]
        )
        .is_err());
        let mut trailing = serialized.clone();
        trailing.push(0);
        assert!(sign_solana_transaction_message(&signer, &trailing, &[7; 32]).is_err());
        if let VersionedMessage::Legacy(ref mut msg) = message {
            msg.header.num_required_signatures = 2;
        }
        assert!(sign_solana_transaction_message(&signer, &message.serialize(), &[7; 32]).is_err());
        assert!(sign_solana_transaction_message(&signer, &[1, 2, 3], &[7; 32]).is_err());
    }
}
