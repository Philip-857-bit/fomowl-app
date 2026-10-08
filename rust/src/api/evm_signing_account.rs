use flutter_rust_bridge::frb;
use owllet_core::session::{AccountHandle, SigningSession};

/// Rust-owned signing context. No API returns the private key to Dart.
#[frb(opaque)]
pub struct RustEvmSigningAccount {
    session: SigningSession,
    account: AccountHandle,
}

pub fn create_evm_signing_account(
    private_key_hex: String,
    expected_address: String,
) -> Result<RustEvmSigningAccount, String> {
    let mut session = SigningSession::new();
    let account = session
        .import_evm_key(private_key_hex)
        .map_err(|e| e.to_string())?;
    let info = session.account_info(&account).map_err(|e| e.to_string())?;
    if info.address.to_lowercase() != expected_address.trim().to_lowercase() {
        return Err("Active EVM address does not match private key".to_string());
    }
    Ok(RustEvmSigningAccount { session, account })
}

impl RustEvmSigningAccount {
    pub fn address(&self) -> Result<String, String> {
        self.session
            .account_info(&self.account)
            .map(|info| info.address)
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
        let signed = self
            .session
            .sign_evm_transaction(&self.account, &request)
            .map_err(|e| e.to_string())?;
        Ok(signed.raw_transaction_hex)
    }

    pub fn close(&mut self) {
        self.session.lock();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn verified_context_locks_and_refuses_further_access() {
        let key = "46".repeat(32);
        let address = owllet_core::derive_evm_address_from_private_key(&key).unwrap();
        let mut signer = create_evm_signing_account(key, address.clone()).unwrap();
        assert_eq!(signer.address().unwrap(), address);
        signer.close();
        assert!(signer.address().unwrap_err().contains("locked"));
        assert!(signer
            .sign_transaction(
                1,
                0,
                21000,
                Some("0x3535353535353535353535353535353535353535".to_string()),
                "0".to_string(),
                "".to_string(),
                Some("1".to_string()),
                None,
                None,
            )
            .unwrap_err()
            .contains("locked"));
    }

    #[test]
    fn context_creation_rejects_a_different_sender() {
        assert!(create_evm_signing_account(
            "46".repeat(32),
            "0x3535353535353535353535353535353535353535".to_string()
        )
        .is_err());
    }
}
