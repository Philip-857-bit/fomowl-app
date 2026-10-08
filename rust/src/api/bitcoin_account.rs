//! Public HD Bitcoin bindings. Cryptography and consensus formats belong to the SDK.
use owllet_core::{BitcoinAccount, BitcoinAccountPurpose, BitcoinKeychain, BitcoinNetwork};
use zeroize::Zeroizing;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BitcoinNetworkDto {
    Mainnet,
    Testnet4,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BitcoinPurposeDto {
    Bip84,
    Bip86,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BitcoinKeychainDto {
    External,
    Internal,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BitcoinAccountDto {
    pub network: BitcoinNetworkDto,
    pub purpose: BitcoinPurposeDto,
    pub account_index: u32,
    pub master_fingerprint: String,
    pub account_xpub: String,
}
impl BitcoinNetworkDto {
    pub(crate) fn core(self) -> BitcoinNetwork {
        match self {
            Self::Mainnet => BitcoinNetwork::Mainnet,
            Self::Testnet4 => BitcoinNetwork::Testnet4,
        }
    }
}
impl BitcoinPurposeDto {
    pub(crate) fn core(self) -> BitcoinAccountPurpose {
        match self {
            Self::Bip84 => BitcoinAccountPurpose::Bip84,
            Self::Bip86 => BitcoinAccountPurpose::Bip86,
        }
    }
}
impl BitcoinKeychainDto {
    pub(crate) fn core(self) -> BitcoinKeychain {
        match self {
            Self::External => BitcoinKeychain::External,
            Self::Internal => BitcoinKeychain::Internal,
        }
    }
}
impl BitcoinAccountDto {
    pub(crate) fn core(&self) -> BitcoinAccount {
        BitcoinAccount {
            network: self.network.core(),
            purpose: self.purpose.core(),
            account: self.account_index,
            master_fingerprint: self.master_fingerprint.clone(),
            account_xpub: self.account_xpub.clone(),
        }
    }
    pub(crate) fn from_core(value: BitcoinAccount) -> Result<Self, String> {
        let network = match value.network {
            BitcoinNetwork::Mainnet => BitcoinNetworkDto::Mainnet,
            BitcoinNetwork::Testnet4 => BitcoinNetworkDto::Testnet4,
            _ => return Err("Unsupported Bitcoin product network".into()),
        };
        let purpose = match value.purpose {
            BitcoinAccountPurpose::Bip84 => BitcoinPurposeDto::Bip84,
            BitcoinAccountPurpose::Bip86 => BitcoinPurposeDto::Bip86,
        };
        Ok(Self {
            network,
            purpose,
            account_index: value.account,
            master_fingerprint: value.master_fingerprint,
            account_xpub: value.account_xpub,
        })
    }
}
/// Public metadata only. The owned incoming seed is wiped when derivation returns.
pub fn derive_bitcoin_account_metadata(
    seed: Vec<u8>,
    network: BitcoinNetworkDto,
    account_index: u32,
    purpose: BitcoinPurposeDto,
) -> Result<BitcoinAccountDto, String> {
    let seed = Zeroizing::new(seed);
    BitcoinAccountDto::from_core(owllet_core::derive_bitcoin_account(
        &seed,
        network.core(),
        account_index,
        purpose.core(),
    )?)
}
pub fn derive_bitcoin_account_address(
    account: BitcoinAccountDto,
    network: BitcoinNetworkDto,
    keychain: BitcoinKeychainDto,
    address_index: u32,
) -> Result<String, String> {
    owllet_core::derive_bitcoin_address_from_account(
        &account.core(),
        network.core(),
        keychain.core(),
        address_index,
    )
}
pub fn derive_bitcoin_owned_script(
    account: BitcoinAccountDto,
    network: BitcoinNetworkDto,
    keychain: BitcoinKeychainDto,
    address_index: u32,
) -> Result<String, String> {
    owllet_core::derive_bitcoin_script_pubkey_from_account(
        &account.core(),
        network.core(),
        keychain.core(),
        address_index,
    )
}
#[cfg(test)]
mod tests {
    use super::*;
    const MNEMONIC: &str = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    #[test]
    fn official_vectors_and_explicit_networks_survive_the_adapter() {
        let seed = Zeroizing::new(owllet_core::mnemonic_to_seed(MNEMONIC).unwrap());
        for (purpose, expected) in [
            (
                BitcoinPurposeDto::Bip84,
                "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu",
            ),
            (
                BitcoinPurposeDto::Bip86,
                "bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr",
            ),
        ] {
            let account = derive_bitcoin_account_metadata(
                seed.to_vec(),
                BitcoinNetworkDto::Mainnet,
                0,
                purpose,
            )
            .unwrap();
            let receive = derive_bitcoin_account_address(
                account.clone(),
                account.network,
                BitcoinKeychainDto::External,
                0,
            )
            .unwrap();
            assert_eq!(receive, expected);
            assert_ne!(
                receive,
                derive_bitcoin_account_address(
                    account.clone(),
                    account.network,
                    BitcoinKeychainDto::Internal,
                    0
                )
                .unwrap()
            );
            let script = derive_bitcoin_owned_script(
                account.clone(),
                account.network,
                BitcoinKeychainDto::External,
                0,
            )
            .unwrap();
            assert!(script.starts_with(if purpose == BitcoinPurposeDto::Bip84 {
                "0014"
            } else {
                "5120"
            }));
            assert!(derive_bitcoin_account_address(
                account.clone(),
                BitcoinNetworkDto::Testnet4,
                BitcoinKeychainDto::External,
                0
            )
            .is_err());
            assert!(derive_bitcoin_account_address(
                account,
                BitcoinNetworkDto::Mainnet,
                BitcoinKeychainDto::External,
                1 << 31
            )
            .is_err());
            let testnet = derive_bitcoin_account_metadata(
                seed.to_vec(),
                BitcoinNetworkDto::Testnet4,
                0,
                purpose,
            )
            .unwrap();
            let address = derive_bitcoin_account_address(
                testnet,
                BitcoinNetworkDto::Testnet4,
                BitcoinKeychainDto::External,
                0,
            )
            .unwrap();
            assert!(address.starts_with(if purpose == BitcoinPurposeDto::Bip84 {
                "tb1q"
            } else {
                "tb1p"
            }));
        }
    }
    #[test]
    fn malformed_seed_and_account_indices_return_redacted_errors() {
        assert!(derive_bitcoin_account_metadata(
            vec![0; 15],
            BitcoinNetworkDto::Mainnet,
            0,
            BitcoinPurposeDto::Bip84
        )
        .is_err());
        assert!(derive_bitcoin_account_metadata(
            vec![0; 65],
            BitcoinNetworkDto::Mainnet,
            0,
            BitcoinPurposeDto::Bip84
        )
        .is_err());
        assert!(derive_bitcoin_account_metadata(
            vec![0; 32],
            BitcoinNetworkDto::Mainnet,
            1 << 31,
            BitcoinPurposeDto::Bip84
        )
        .is_err());
    }
}
