//! Opaque, purpose-scoped HD custody. Authentication and confirmation belong to the host.
use super::bitcoin_account::BitcoinAccountDto;
use super::bitcoin_transaction::{BitcoinTransactionPlanDto, SignedBitcoinTransactionDto};
use flutter_rust_bridge::frb;
use owllet_core::bitcoin_session::{BitcoinAccountHandle, BitcoinSigningSession};
use std::fmt;

#[frb(opaque)]
pub struct RustBitcoinSigningAccount {
    session: BitcoinSigningSession,
    handle: BitcoinAccountHandle,
}
impl fmt::Debug for RustBitcoinSigningAccount {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("RustBitcoinSigningAccount(opaque)")
    }
}
impl Drop for RustBitcoinSigningAccount {
    fn drop(&mut self) {
        self.session.lock();
    }
}
impl RustBitcoinSigningAccount {
    pub(crate) fn from_custody(
        session: BitcoinSigningSession,
        handle: BitcoinAccountHandle,
    ) -> Self {
        Self { session, handle }
    }
    pub fn account_info(&self) -> Result<BitcoinAccountDto, String> {
        BitcoinAccountDto::from_core(self.session.account_info(&self.handle)?.hd_account)
    }
    pub fn sign_transaction(
        &self,
        plan: BitcoinTransactionPlanDto,
    ) -> Result<SignedBitcoinTransactionDto, String> {
        self.session
            .sign_transaction(&self.handle, &plan.core())
            .map(SignedBitcoinTransactionDto::from_core)
    }
    pub fn sign_psbt(&self, psbt_base64: String) -> Result<String, String> {
        self.session.sign_psbt(&self.handle, &psbt_base64)
    }
    /// Terminal: closing a signer cannot be undone or reused after authentication changes.
    pub fn close(&mut self) {
        self.session.lock();
    }
}

/// Reopens protected ciphertext into Rust-owned custody; no secret export.
pub fn open_bitcoin_signing_account(
    account: BitcoinAccountDto,
    encrypted_vault: String,
    wrapping_key: Vec<u8>,
) -> Result<RustBitcoinSigningAccount, String> {
    let key = zeroize::Zeroizing::new(wrapping_key);
    let key: &[u8; 32] = key
        .as_slice()
        .try_into()
        .map_err(|_| "Bitcoin vault wrapping key must contain exactly 32 bytes")?;
    let (session, handle) = owllet_core::bitcoin_vault::open_bitcoin_account_vault(
        &account.core(),
        &encrypted_vault,
        key,
    )?;
    Ok(RustBitcoinSigningAccount::from_custody(session, handle))
}

#[cfg(test)]
mod tests {
    use super::super::bitcoin_account::{
        derive_bitcoin_account_address, derive_bitcoin_account_metadata,
        derive_bitcoin_owned_script, BitcoinKeychainDto, BitcoinNetworkDto, BitcoinPurposeDto,
    };
    use super::super::bitcoin_transaction::{
        create_bitcoin_transfer_psbt, plan_bitcoin_transfer, verify_bitcoin_transfer,
        BitcoinRecipientDto, BitcoinUtxoDto,
    };
    use super::*;
    #[test]
    fn hd_signers_keep_purpose_scope_and_close_is_terminal() {
        let seed = zeroize::Zeroizing::new(owllet_core::mnemonic_to_seed("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about").unwrap());
        for purpose in [BitcoinPurposeDto::Bip84, BitcoinPurposeDto::Bip86] {
            let account = derive_bitcoin_account_metadata(
                seed.to_vec(),
                BitcoinNetworkDto::Mainnet,
                0,
                purpose,
            )
            .unwrap();
            let secret = zeroize::Zeroizing::new(
                owllet_core::derive_bitcoin_account_xprv_from_seed(
                    &seed,
                    account.network.core(),
                    0,
                    purpose.core(),
                )
                .unwrap(),
            );
            let record = owllet_core::bitcoin_vault::seal_bitcoin_account_vault(
                &account.core(),
                &secret,
                &[42; 32],
                &[purpose.core().number() as u8; 12],
            )
            .unwrap();
            let mut signer =
                open_bitcoin_signing_account(account.clone(), record.clone(), vec![42; 32])
                    .unwrap();
            assert_eq!(signer.account_info().unwrap(), account);
            assert!(!format!("{signer:?}").contains(secret.as_str()));
            let utxo = BitcoinUtxoDto {
                txid: "11".repeat(32),
                vout: 0,
                value_sat: 100_000,
                script_pubkey_hex: derive_bitcoin_owned_script(
                    account.clone(),
                    account.network,
                    BitcoinKeychainDto::External,
                    0,
                )
                .unwrap(),
                keychain: BitcoinKeychainDto::External,
                address_index: 0,
            };
            let recipient = BitcoinRecipientDto {
                address: derive_bitcoin_account_address(
                    account.clone(),
                    account.network,
                    BitcoinKeychainDto::External,
                    1,
                )
                .unwrap(),
                amount_sat: 50_000,
            };
            let plan = plan_bitcoin_transfer(
                account.network,
                account.clone(),
                vec![utxo],
                vec![recipient],
                2,
                0,
                true,
            )
            .unwrap();
            let signed = signer.sign_transaction(plan.clone()).unwrap();
            assert_eq!(
                verify_bitcoin_transfer(plan.clone(), signed.raw_transaction_hex.clone()).unwrap(),
                signed
            );
            let psbt = create_bitcoin_transfer_psbt(plan.clone()).unwrap();
            assert!(
                owllet_core::transactions::bitcoin_psbt::finalize_bitcoin_psbt(
                    &signer.sign_psbt(psbt.clone()).unwrap()
                )
                .unwrap()
                .complete
            );
            assert!(
                open_bitcoin_signing_account(account.clone(), record.clone(), vec![43; 32])
                    .is_err()
            );
            let mut wrong_purpose = account.clone();
            wrong_purpose.purpose = if purpose == BitcoinPurposeDto::Bip84 {
                BitcoinPurposeDto::Bip86
            } else {
                BitcoinPurposeDto::Bip84
            };
            assert!(
                open_bitcoin_signing_account(wrong_purpose, record.clone(), vec![42; 32]).is_err()
            );
            signer.close();
            assert!(signer.account_info().is_err());
            assert!(signer.sign_transaction(plan).is_err());
            assert!(signer.sign_psbt(psbt).is_err());
            signer.close();
        }
    }
}
