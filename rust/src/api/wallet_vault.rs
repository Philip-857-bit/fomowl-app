//! Platform adapter for all-family vault custody. Hosts own authentication and
//! protected storage; raw export is deliberately separate from signing methods.
use flutter_rust_bridge::frb;
use owllet_core::session::{AccountFamily, AccountHandle, SigningSession};
use zeroize::Zeroizing;

fn family(value: &str) -> Result<AccountFamily, String> {
    match value {
        "evm" => Ok(AccountFamily::Evm),
        "solana" => Ok(AccountFamily::Solana),
        "tron" => Ok(AccountFamily::Tron),
        _ => Err("Unsupported vault chain family".into()),
    }
}

pub fn seal_wallet_vault(
    chain_family: String,
    private_key_hex: String,
    expected_address: String,
    wrapping_key: Vec<u8>,
) -> Result<String, String> {
    let secret = Zeroizing::new(private_key_hex);
    let key = Zeroizing::new(wrapping_key);
    let key: &[u8; 32] = key
        .as_slice()
        .try_into()
        .map_err(|_| "Vault wrapping key must contain exactly 32 bytes")?;
    owllet_core::vault::seal_account_key(
        family(&chain_family)?,
        &secret,
        &expected_address,
        key,
        &rand::random::<[u8; 12]>(),
    )
    .map_err(|e| e.to_string())
}

#[frb(opaque)]
pub struct RustWalletSigningAccount {
    session: SigningSession,
    account: AccountHandle,
}

pub fn open_wallet_vault(
    chain_family: String,
    encrypted_vault: String,
    expected_address: String,
    wrapping_key: Vec<u8>,
) -> Result<RustWalletSigningAccount, String> {
    let key = Zeroizing::new(wrapping_key);
    let key: &[u8; 32] = key
        .as_slice()
        .try_into()
        .map_err(|_| "Vault wrapping key must contain exactly 32 bytes")?;
    let (session, account) = owllet_core::vault::open_account_vault(
        family(&chain_family)?,
        &encrypted_vault,
        &expected_address,
        key,
    )
    .map_err(|e| e.to_string())?;
    Ok(RustWalletSigningAccount { session, account })
}

/// Explicit backup/export only; the host authenticates the user before calling.
pub fn export_wallet_vault_key(
    chain_family: String,
    encrypted_vault: String,
    expected_address: String,
    wrapping_key: Vec<u8>,
) -> Result<String, String> {
    let key = Zeroizing::new(wrapping_key);
    let key: &[u8; 32] = key
        .as_slice()
        .try_into()
        .map_err(|_| "Vault wrapping key must contain exactly 32 bytes")?;
    let secret = owllet_core::vault::export_account_key(
        family(&chain_family)?,
        &encrypted_vault,
        &expected_address,
        key,
    )
    .map_err(|e| e.to_string())?;
    Ok(secret.to_string())
}

impl RustWalletSigningAccount {
    pub fn address(&self) -> Result<String, String> {
        self.session
            .account_info(&self.account)
            .map(|i| i.address)
            .map_err(|e| e.to_string())
    }
    pub fn close(&mut self) {
        self.session.lock();
    }
    pub fn sign_personal_message(&self, message: String) -> Result<String, String> {
        self.session
            .sign_personal_message(&self.account, &message)
            .map_err(|e| e.to_string())
    }
    pub fn sign_typed_data(&self, json_data: String) -> Result<String, String> {
        let info = self
            .session
            .account_info(&self.account)
            .map_err(|e| e.to_string())?;
        match info.family {
            AccountFamily::Evm => self.session.sign_typed_data(&self.account, &json_data),
            AccountFamily::Tron => self.session.sign_tron_typed_data(&self.account, &json_data),
            AccountFamily::Solana => return Err("Solana accounts cannot sign EIP-712 data".into()),
        }
        .map_err(|e| e.to_string())
    }
    #[allow(clippy::too_many_arguments)]
    pub fn sign_transaction(
        &self,
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
        let request = crate::api::evm_tx::request_from_fields(
            chain_id,
            nonce,
            gas_limit,
            to_address,
            value_wei,
            data_hex,
            gas_price_wei,
            max_fee_per_gas_wei,
            max_priority_fee_per_gas_wei,
        )?;
        self.session
            .sign_evm_transaction(&self.account, &request)
            .map(|s| s.raw_transaction_hex)
            .map_err(|e| e.to_string())
    }
    pub fn sign_solana_message(&self, message: Vec<u8>) -> Result<String, String> {
        self.session
            .sign_solana_message(&self.account, &message)
            .map_err(|e| e.to_string())
    }
    pub fn sign_serialized_solana_transaction(
        &self,
        transaction_base64: String,
    ) -> Result<String, String> {
        self.session
            .sign_serialized_solana_transaction(&self.account, &transaction_base64)
            .map_err(|e| e.to_string())
    }
    pub fn build_and_sign_solana_transaction(
        &self,
        recent_blockhash: String,
        instructions_json: String,
        lookup_tables_json: String,
    ) -> Result<String, String> {
        self.session
            .build_and_sign_solana_transaction(
                &self.account,
                &recent_blockhash,
                &instructions_json,
                &lookup_tables_json,
            )
            .map_err(|e| e.to_string())
    }
    pub fn sign_tron_raw_hash(&self, raw_hash_hex: String) -> Result<String, String> {
        self.session
            .sign_tron_raw_hash(&self.account, &raw_hash_hex)
            .map_err(|e| e.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn all_family_adapters_keep_identity_signatures_and_explicit_exports() {
        for name in ["evm", "solana", "tron"] {
            let secret = "07".repeat(32);
            let address = match name {
                "evm" => owllet_core::derive_evm_address_from_private_key(&secret).unwrap(),
                "solana" => owllet_core::derive_solana_address_from_private_key(&[7; 32]).unwrap(),
                _ => owllet_core::derive_tron_address_from_private_key(&secret).unwrap(),
            };
            let record =
                seal_wallet_vault(name.into(), secret.clone(), address.clone(), vec![7; 32])
                    .unwrap();
            let mut signer =
                open_wallet_vault(name.into(), record.clone(), address.clone(), vec![7; 32])
                    .unwrap();
            assert_eq!(signer.address().unwrap(), address);
            assert_eq!(
                export_wallet_vault_key(name.into(), record, address, vec![7; 32]).unwrap(),
                secret
            );
            match name {
                "evm" => assert_eq!(
                    signer.sign_personal_message("hello".into()).unwrap(),
                    owllet_core::sign_personal_message(&secret, "hello").unwrap()
                ),
                "solana" => assert_eq!(
                    signer.sign_solana_message(b"hello".to_vec()).unwrap(),
                    owllet_core::sign_solana_message(&[7; 32], b"hello").unwrap()
                ),
                _ => assert_eq!(
                    signer.sign_tron_raw_hash("ab".repeat(32)).unwrap(),
                    owllet_core::sign_tron_raw_hash(&secret, &"ab".repeat(32)).unwrap()
                ),
            }
            signer.close();
            assert!(signer.address().is_err());
        }
    }
}
