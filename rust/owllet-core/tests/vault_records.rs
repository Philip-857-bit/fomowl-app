#![cfg(all(
    feature = "vault",
    any(feature = "evm", feature = "solana", feature = "tron")
))]

use owllet_core::{session::AccountFamily, vault::*};

fn assert_roundtrip(family: AccountFamily, key: &str, address: &str) {
    let record = seal_account_key(family, key, address, &[7; 32], &[9; 12]).unwrap();
    let (session, handle) = open_account_vault(family, &record, address, &[7; 32]).unwrap();
    let info = session.account_info(&handle).unwrap();
    assert_eq!(info.family, family);
    assert_eq!(
        &*export_account_key(family, &record, address, &[7; 32]).unwrap(),
        key
    );
    assert!(export_account_key(family, &record, address, &[8; 32]).is_err());
    let mut tampered: serde_json::Value = serde_json::from_str(&record).unwrap();
    let alternate = "0x0000000000000000000000000000000000000000";
    tampered["address"] = alternate.into();
    assert!(open_account_vault(family, &tampered.to_string(), alternate, &[7; 32]).is_err());
}

#[cfg(feature = "evm")]
#[test]
fn evm_record_keeps_existing_format_and_export_identity() {
    let key = "46".repeat(32);
    let address = owllet_core::derive_evm_address_from_private_key(&key).unwrap();
    assert_roundtrip(AccountFamily::Evm, &key, &address);
}
#[cfg(feature = "solana")]
#[test]
fn solana_record_preserves_case_and_rejects_other_addresses() {
    let key = vec![7; 32];
    let address = owllet_core::derive_solana_address_from_private_key(&key).unwrap();
    assert_roundtrip(AccountFamily::Solana, &hex::encode(key), &address);
    let record = seal_account_key(
        AccountFamily::Solana,
        &hex::encode([7; 32]),
        &address,
        &[7; 32],
        &[9; 12],
    )
    .unwrap();
    assert!(open_account_vault(
        AccountFamily::Solana,
        &record,
        &address.to_lowercase(),
        &[7; 32]
    )
    .is_err());
}
#[cfg(feature = "tron")]
#[test]
fn tron_record_keeps_base58_address_and_export_identity() {
    let key = "46".repeat(32);
    let address = owllet_core::derive_tron_address_from_private_key(&key).unwrap();
    assert_roundtrip(AccountFamily::Tron, &key, &address);
}
#[cfg(all(feature = "evm", feature = "tron"))]
#[test]
fn records_cannot_be_reinterpreted_as_a_different_family() {
    let key = "46".repeat(32);
    let address = owllet_core::derive_evm_address_from_private_key(&key).unwrap();
    let record = seal_account_key(AccountFamily::Evm, &key, &address, &[7; 32], &[9; 12]).unwrap();
    assert!(matches!(
        open_account_vault(AccountFamily::Tron, &record, &address, &[7; 32]),
        Err(VaultError::InvalidRecord)
    ));
}
