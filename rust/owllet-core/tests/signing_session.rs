#![cfg(all(
    feature = "signing-session",
    any(feature = "evm", feature = "solana", feature = "tron")
))]

use owllet_core::session::{AccountFamily, SessionError, SigningSession};

#[cfg(feature = "evm")]
const EVM_KEY: &str = "4646464646464646464646464646464646464646464646464646464646464646";

#[cfg(feature = "evm")]
#[test]
fn opaque_evm_handle_signs_the_official_fixture_without_key_exports() {
    let mut session = SigningSession::new();
    let handle = session.import_evm_key(EVM_KEY.to_string()).expect("import");
    assert_eq!(
        session.account_info(&handle).unwrap().family,
        AccountFamily::Evm
    );
    assert!(!format!("{handle:?}").contains(EVM_KEY));
    let request = owllet_core::EvmTransactionRequest {
        chain_id: 1,
        nonce: 9,
        gas_limit: 21000,
        to: Some("0x3535353535353535353535353535353535353535".to_string()),
        value_wei: "1000000000000000000".to_string(),
        data_hex: "".to_string(),
        fee: owllet_core::EvmTransactionFee::Legacy {
            gas_price_wei: 20000000000,
        },
    };
    let signed = session
        .sign_evm_transaction(&handle, &request)
        .expect("sign");
    assert_eq!(signed.raw_transaction_hex,
        "0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83");
    session.lock();
    assert!(session.is_locked());
    assert_eq!(session.account_count(), 0);
    assert_eq!(
        session.sign_evm_transaction(&handle, &request),
        Err(SessionError::Locked)
    );
    assert!(matches!(
        session.import_evm_key(EVM_KEY.to_string()),
        Err(SessionError::Locked)
    ));
}

#[cfg(feature = "evm")]
#[test]
fn session_scope_and_removed_accounts_cannot_be_reused() {
    let mut session = SigningSession::new();
    let handle = session.import_evm_key(EVM_KEY.to_string()).unwrap();
    let same = session.import_evm_key(EVM_KEY.to_string()).unwrap();
    assert_eq!(session.account_count(), 1);
    assert_eq!(session.account_info(&handle), session.account_info(&same));
    let other_session = SigningSession::new();
    assert_eq!(
        other_session.account_info(&handle),
        Err(SessionError::ForeignHandle)
    );
    session.remove_account(&handle).unwrap();
    assert_eq!(
        session.account_info(&same),
        Err(SessionError::AccountRemoved)
    );
    let replacement = session.import_evm_key(EVM_KEY.to_string()).unwrap();
    assert!(session.account_info(&replacement).is_ok());
    assert_eq!(
        session.account_info(&handle),
        Err(SessionError::AccountRemoved)
    );
    drop(session);
    assert_eq!(
        other_session.account_info(&replacement),
        Err(SessionError::ExpiredHandle)
    );
}

#[cfg(feature = "evm")]
#[test]
fn invalid_import_does_not_change_the_session() {
    let mut session = SigningSession::new();
    assert!(matches!(
        session.import_evm_key("invalid".to_string()),
        Err(SessionError::InvalidKey(_))
    ));
    assert_eq!(session.account_count(), 0);
}

#[cfg(feature = "solana")]
#[test]
fn opaque_solana_handles_sign_each_required_slot_without_exposing_keys() {
    use base64::{engine::general_purpose::STANDARD, Engine};
    use solana_hash::Hash;
    use solana_keypair::Keypair;
    use solana_message::{MessageHeader, VersionedMessage};
    use solana_signature::Signature;
    use solana_signer::Signer;
    use solana_transaction::versioned::VersionedTransaction;

    let mut session = SigningSession::new();
    let payer = Keypair::new_from_array([7u8; 32]);
    let other = Keypair::new_from_array([8u8; 32]);
    let payer_handle = session.import_solana_key(vec![7u8; 32]).unwrap();
    let other_handle = session.import_solana_key(vec![8u8; 32]).unwrap();
    assert_eq!(
        session.account_info(&payer_handle).unwrap().family,
        AccountFamily::Solana
    );
    let transaction = VersionedTransaction {
        signatures: vec![Signature::default(); 2],
        message: VersionedMessage::Legacy(solana_message::Message {
            header: MessageHeader {
                num_required_signatures: 2,
                num_readonly_signed_accounts: 0,
                num_readonly_unsigned_accounts: 0,
            },
            account_keys: vec![payer.pubkey(), other.pubkey()],
            recent_blockhash: Hash::new_from_array([4u8; 32]),
            instructions: vec![],
        }),
    };
    let unsigned = STANDARD.encode(bincode::serialize(&transaction).unwrap());
    let first = session
        .sign_serialized_solana_transaction(&payer_handle, &unsigned)
        .unwrap();
    let second = session
        .sign_serialized_solana_transaction(&other_handle, &first)
        .unwrap();
    let signed: VersionedTransaction =
        bincode::deserialize(&STANDARD.decode(second).unwrap()).unwrap();
    assert!(signed.signatures[0].verify(payer.pubkey().as_ref(), &signed.message.serialize()));
    assert!(signed.signatures[1].verify(other.pubkey().as_ref(), &signed.message.serialize()));
    session.lock();
    assert_eq!(
        session.sign_solana_message(&payer_handle, b"hello"),
        Err(SessionError::Locked)
    );
}

#[cfg(feature = "tron")]
#[test]
fn opaque_tron_handle_produces_a_recoverable_signature() {
    use secp256k1::{ecdsa::RecoverableSignature, ecdsa::RecoveryId, Message, Secp256k1};
    let mut session = SigningSession::new();
    let handle = session.import_tron_key("46".repeat(32)).unwrap();
    let info = session.account_info(&handle).unwrap();
    assert_eq!(info.family, AccountFamily::Tron);
    let digest = [1u8; 32];
    let signature = session
        .sign_tron_raw_hash(&handle, &hex::encode(digest))
        .unwrap();
    let bytes = hex::decode(signature.trim_start_matches("0x")).unwrap();
    let recoverable = RecoverableSignature::from_compact(
        &bytes[..64],
        RecoveryId::try_from(i32::from(bytes[64])).unwrap(),
    )
    .unwrap();
    let recovered = Secp256k1::new()
        .recover_ecdsa(Message::from_digest(digest), &recoverable)
        .unwrap();
    assert_eq!(
        owllet_core::tron_address_from_public_key(&recovered),
        info.address
    );
    session.remove_account(&handle).unwrap();
    assert_eq!(
        session.sign_tron_raw_hash(&handle, &hex::encode(digest)),
        Err(SessionError::AccountRemoved)
    );
}

#[cfg(all(feature = "evm", feature = "solana"))]
#[test]
fn chain_families_cannot_use_each_others_handles() {
    let mut session = SigningSession::new();
    let handle = session.import_evm_key(EVM_KEY.to_string()).unwrap();
    assert_eq!(
        session.sign_solana_message(&handle, b"hello"),
        Err(SessionError::WrongFamily)
    );
}
