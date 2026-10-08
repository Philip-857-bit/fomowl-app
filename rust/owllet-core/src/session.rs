//! Process-local key custody for authenticated host sessions.
//!
//! Handles contain weak references, never keys. Locking, removing an account,
//! or dropping a session releases its owned key buffers even if handles remain.
//! Hosts own authentication, permissions, storage, and lifecycle locking. This
//! module is not an encrypted vault, hardware boundary, or authorization token.

use std::fmt;
use std::sync::{Arc, Weak};
use zeroize::Zeroizing;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AccountFamily {
    #[cfg(feature = "evm")]
    Evm,
    #[cfg(feature = "solana")]
    Solana,
    #[cfg(feature = "tron")]
    Tron,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AccountInfo {
    pub family: AccountFamily,
    pub address: String,
}

enum KeyMaterial {
    #[cfg(feature = "evm")]
    Evm(Zeroizing<String>),
    #[cfg(feature = "solana")]
    Solana(Zeroizing<Vec<u8>>),
    #[cfg(feature = "tron")]
    Tron(Zeroizing<String>),
}

struct Account {
    info: AccountInfo,
    key: KeyMaterial,
}

/// Opaque, non-serializable reference to an account in exactly one live session.
#[derive(Clone)]
pub struct AccountHandle {
    scope: Weak<()>,
    account: Weak<Account>,
}

impl fmt::Debug for AccountHandle {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("AccountHandle(REDACTED)")
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum SessionError {
    Locked,
    ExpiredHandle,
    ForeignHandle,
    AccountRemoved,
    WrongFamily,
    InvalidKey(String),
    Signing(String),
}

impl fmt::Display for SessionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Locked => f.write_str("Signing session is locked"),
            Self::ExpiredHandle => f.write_str("Account handle has expired"),
            Self::ForeignHandle => f.write_str("Account belongs to another signing session"),
            Self::AccountRemoved => f.write_str("Account was removed from the signing session"),
            Self::WrongFamily => f.write_str("Account cannot sign for this chain family"),
            Self::InvalidKey(error) => write!(f, "Invalid account key: {error}"),
            Self::Signing(error) => write!(f, "Signing failed: {error}"),
        }
    }
}

impl std::error::Error for SessionError {}

/// Transient Rust-owned keys. A fresh session is created after host unlock;
/// locked sessions cannot be reopened, and no API returns private key material.
pub struct SigningSession {
    scope: Arc<()>,
    accounts: Vec<Arc<Account>>,
    locked: bool,
}

impl Default for SigningSession {
    fn default() -> Self {
        Self::new()
    }
}

impl SigningSession {
    pub fn new() -> Self {
        Self {
            scope: Arc::new(()),
            accounts: Vec::new(),
            locked: false,
        }
    }

    pub fn lock(&mut self) {
        self.accounts.clear();
        self.scope = Arc::new(());
        self.locked = true;
    }

    pub fn is_locked(&self) -> bool {
        self.locked
    }

    pub fn account_count(&self) -> usize {
        self.accounts.len()
    }

    fn require_open(&self) -> Result<(), SessionError> {
        if self.locked {
            Err(SessionError::Locked)
        } else {
            Ok(())
        }
    }

    fn insert(&mut self, info: AccountInfo, key: KeyMaterial) -> AccountHandle {
        // Importing the same account is idempotent; the extra key is dropped.
        let account = self
            .accounts
            .iter()
            .find(|account| account.info == info)
            .cloned()
            .unwrap_or_else(|| {
                let account = Arc::new(Account { info, key });
                self.accounts.push(account.clone());
                account
            });
        AccountHandle {
            scope: Arc::downgrade(&self.scope),
            account: Arc::downgrade(&account),
        }
    }

    fn resolve(&self, handle: &AccountHandle) -> Result<&Account, SessionError> {
        self.require_open()?;
        let scope = handle.scope.upgrade().ok_or(SessionError::ExpiredHandle)?;
        if !Arc::ptr_eq(&scope, &self.scope) {
            return Err(SessionError::ForeignHandle);
        }
        self.accounts
            .iter()
            .find(|account| Weak::ptr_eq(&Arc::downgrade(account), &handle.account))
            .map(Arc::as_ref)
            .ok_or(SessionError::AccountRemoved)
    }

    pub fn account_info(&self, handle: &AccountHandle) -> Result<AccountInfo, SessionError> {
        Ok(self.resolve(handle)?.info.clone())
    }

    pub fn remove_account(&mut self, handle: &AccountHandle) -> Result<(), SessionError> {
        self.resolve(handle)?;
        self.accounts
            .retain(|account| !Weak::ptr_eq(&Arc::downgrade(account), &handle.account));
        Ok(())
    }

    #[cfg(feature = "evm")]
    pub fn import_evm_key(
        &mut self,
        private_key_hex: String,
    ) -> Result<AccountHandle, SessionError> {
        let key = Zeroizing::new(private_key_hex);
        self.require_open()?;
        let address = crate::accounts::evm::derive_evm_address_from_private_key(&key)
            .map_err(SessionError::InvalidKey)?;
        Ok(self.insert(
            AccountInfo {
                family: AccountFamily::Evm,
                address,
            },
            KeyMaterial::Evm(key),
        ))
    }

    #[cfg(feature = "solana")]
    pub fn import_solana_key(
        &mut self,
        private_key_bytes: Vec<u8>,
    ) -> Result<AccountHandle, SessionError> {
        let key = Zeroizing::new(private_key_bytes);
        self.require_open()?;
        let address = crate::accounts::solana::derive_solana_address_from_private_key(&key)
            .map_err(SessionError::InvalidKey)?;
        Ok(self.insert(
            AccountInfo {
                family: AccountFamily::Solana,
                address,
            },
            KeyMaterial::Solana(key),
        ))
    }

    #[cfg(feature = "tron")]
    pub fn import_tron_key(
        &mut self,
        private_key_hex: String,
    ) -> Result<AccountHandle, SessionError> {
        let key = Zeroizing::new(private_key_hex);
        self.require_open()?;
        let address = crate::accounts::tron::derive_tron_address_from_private_key(&key)
            .map_err(SessionError::InvalidKey)?;
        Ok(self.insert(
            AccountInfo {
                family: AccountFamily::Tron,
                address,
            },
            KeyMaterial::Tron(key),
        ))
    }

    #[cfg(feature = "evm")]
    fn evm_key<'a>(&'a self, handle: &AccountHandle) -> Result<&'a str, SessionError> {
        match &self.resolve(handle)?.key {
            KeyMaterial::Evm(key) => Ok(key),
            #[allow(unreachable_patterns)]
            _ => Err(SessionError::WrongFamily),
        }
    }

    #[cfg(feature = "evm")]
    pub fn sign_evm_transaction(
        &self,
        handle: &AccountHandle,
        request: &crate::EvmTransactionRequest,
    ) -> Result<crate::SignedEvmTransaction, SessionError> {
        crate::sign_evm_transaction(self.evm_key(handle)?, request).map_err(SessionError::Signing)
    }

    #[cfg(feature = "evm")]
    pub fn sign_personal_message(
        &self,
        handle: &AccountHandle,
        message: &str,
    ) -> Result<String, SessionError> {
        crate::sign_personal_message(self.evm_key(handle)?, message).map_err(SessionError::Signing)
    }

    #[cfg(feature = "evm")]
    pub fn sign_typed_data(
        &self,
        handle: &AccountHandle,
        json: &str,
    ) -> Result<String, SessionError> {
        crate::sign_typed_data(self.evm_key(handle)?, json).map_err(SessionError::Signing)
    }

    /// Some TRON providers authorize permits using the EIP-712 secp256k1
    /// digest format. The key remains scoped to the TRON account.
    #[cfg(all(feature = "evm", feature = "tron"))]
    pub fn sign_tron_typed_data(
        &self,
        handle: &AccountHandle,
        json: &str,
    ) -> Result<String, SessionError> {
        match &self.resolve(handle)?.key {
            KeyMaterial::Tron(key) => {
                crate::sign_typed_data(key, json).map_err(SessionError::Signing)
            }
            _ => Err(SessionError::WrongFamily),
        }
    }

    #[cfg(feature = "solana")]
    pub fn sign_solana_message(
        &self,
        handle: &AccountHandle,
        message: &[u8],
    ) -> Result<String, SessionError> {
        match &self.resolve(handle)?.key {
            KeyMaterial::Solana(key) => {
                crate::sign_solana_message(key, message).map_err(SessionError::Signing)
            }
            #[allow(unreachable_patterns)]
            _ => Err(SessionError::WrongFamily),
        }
    }

    #[cfg(feature = "solana")]
    pub fn build_and_sign_solana_transaction(
        &self,
        handle: &AccountHandle,
        recent_blockhash: &str,
        instructions_json: &str,
        lookup_tables_json: &str,
    ) -> Result<String, SessionError> {
        let account = self.resolve(handle)?;
        match &account.key {
            KeyMaterial::Solana(key) => {
                crate::transactions::solana::build_and_sign_solana_transaction(
                    &account.info.address,
                    recent_blockhash,
                    instructions_json,
                    lookup_tables_json,
                    key,
                )
                .map_err(SessionError::Signing)
            }
            #[allow(unreachable_patterns)]
            _ => Err(SessionError::WrongFamily),
        }
    }

    #[cfg(feature = "solana")]
    pub fn sign_serialized_solana_transaction(
        &self,
        handle: &AccountHandle,
        transaction: &str,
    ) -> Result<String, SessionError> {
        let account = self.resolve(handle)?;
        match &account.key {
            KeyMaterial::Solana(key) => {
                crate::transactions::solana::sign_serialized_solana_transaction(
                    transaction,
                    &account.info.address,
                    key,
                )
                .map_err(SessionError::Signing)
            }
            #[allow(unreachable_patterns)]
            _ => Err(SessionError::WrongFamily),
        }
    }

    #[cfg(feature = "tron")]
    pub fn sign_tron_raw_hash(
        &self,
        handle: &AccountHandle,
        hash: &str,
    ) -> Result<String, SessionError> {
        match &self.resolve(handle)?.key {
            KeyMaterial::Tron(key) => {
                crate::sign_tron_raw_hash(key, hash).map_err(SessionError::Signing)
            }
            #[allow(unreachable_patterns)]
            _ => Err(SessionError::WrongFamily),
        }
    }
    #[cfg(feature = "solana")]
    pub fn sign_solana_transaction_message(
        &self,
        handle: &AccountHandle,
        message: &[u8],
    ) -> Result<String, SessionError> {
        let account = self.resolve(handle)?;
        match &account.key {
            KeyMaterial::Solana(key) => {
                crate::transactions::solana_wire::sign_solana_transaction_message(
                    &account.info.address,
                    message,
                    key,
                )
                .map_err(SessionError::Signing)
            }
            #[allow(unreachable_patterns)]
            _ => Err(SessionError::WrongFamily),
        }
    }
    #[cfg(feature = "tron")]
    pub fn sign_tron_transaction(
        &self,
        handle: &AccountHandle,
        raw_data_hex: &str,
    ) -> Result<String, SessionError> {
        match &self.resolve(handle)?.key {
            KeyMaterial::Tron(key) => {
                crate::transactions::tron::sign_tron_transaction(key, raw_data_hex)
                    .map_err(SessionError::Signing)
            }
            #[allow(unreachable_patterns)]
            _ => Err(SessionError::WrongFamily),
        }
    }
    #[cfg(feature = "tron")]
    pub fn sign_tron_personal_message(
        &self,
        handle: &AccountHandle,
        message: &str,
    ) -> Result<String, SessionError> {
        match &self.resolve(handle)?.key {
            KeyMaterial::Tron(key) => {
                crate::signing::tron::sign_tron_personal_message(key, message)
                    .map_err(SessionError::Signing)
            }
            #[allow(unreachable_patterns)]
            _ => Err(SessionError::WrongFamily),
        }
    }
}
