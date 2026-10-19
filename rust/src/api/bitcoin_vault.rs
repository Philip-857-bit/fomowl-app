//! HD Bitcoin vault boundary. No normal seed-to-vault path returns XPRV to Dart.
use super::bitcoin_account::{BitcoinAccountDto, BitcoinNetworkDto, BitcoinPurposeDto};
use zeroize::Zeroizing;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SealedBitcoinAccountDto {
    pub account: BitcoinAccountDto,
    pub encrypted_vault: String,
}
/// The wrapping key is protected by host secure storage; the nonce is generated in Rust.
pub fn seal_bitcoin_seed_account(
    seed: Vec<u8>,
    network: BitcoinNetworkDto,
    account_index: u32,
    purpose: BitcoinPurposeDto,
    wrapping_key: Vec<u8>,
) -> Result<SealedBitcoinAccountDto, String> {
    let seed = Zeroizing::new(seed);
    let key = Zeroizing::new(wrapping_key);
    let key: &[u8; 32] = key
        .as_slice()
        .try_into()
        .map_err(|_| "Bitcoin vault wrapping key must contain exactly 32 bytes")?;
    let account =
        owllet_core::derive_bitcoin_account(&seed, network.core(), account_index, purpose.core())?;
    let xprv = Zeroizing::new(owllet_core::derive_bitcoin_account_xprv_from_seed(
        &seed,
        network.core(),
        account_index,
        purpose.core(),
    )?);
    let encrypted_vault = owllet_core::bitcoin_vault::seal_bitcoin_account_vault(
        &account,
        &xprv,
        key,
        &rand::random::<[u8; 12]>(),
    )?;
    Ok(SealedBitcoinAccountDto {
        account: BitcoinAccountDto::from_core(account)?,
        encrypted_vault,
    })
}
/// Explicit recovery export only. Hosts authenticate separately; returned secret must never be logged.
pub fn export_bitcoin_vault_xprv(
    account: BitcoinAccountDto,
    encrypted_vault: String,
    wrapping_key: Vec<u8>,
) -> Result<String, String> {
    let key = Zeroizing::new(wrapping_key);
    let key: &[u8; 32] = key
        .as_slice()
        .try_into()
        .map_err(|_| "Bitcoin vault wrapping key must contain exactly 32 bytes")?;
    let secret = owllet_core::bitcoin_vault::export_bitcoin_account_xprv(
        &account.core(),
        &encrypted_vault,
        key,
    )?;
    Ok(secret.to_string())
}

#[cfg(test)]
mod tests {
    use super::super::bitcoin_signing_account::open_bitcoin_signing_account;
    use super::*;
    #[test]
    fn seed_is_sealed_without_normal_secret_export_and_corruption_is_authoritative() {
        let seed = Zeroizing::new(owllet_core::mnemonic_to_seed("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about").unwrap());
        for purpose in [BitcoinPurposeDto::Bip84, BitcoinPurposeDto::Bip86] {
            let sealed = seal_bitcoin_seed_account(
                seed.to_vec(),
                BitcoinNetworkDto::Mainnet,
                0,
                purpose,
                vec![42; 32],
            )
            .unwrap();
            let other = seal_bitcoin_seed_account(
                seed.to_vec(),
                BitcoinNetworkDto::Mainnet,
                0,
                purpose,
                vec![42; 32],
            )
            .unwrap();
            assert_eq!(sealed.account, other.account);
            assert_ne!(sealed.encrypted_vault, other.encrypted_vault);
            let mut signer = open_bitcoin_signing_account(
                sealed.account.clone(),
                sealed.encrypted_vault.clone(),
                vec![42; 32],
            )
            .unwrap();
            assert_eq!(signer.account_info().unwrap(), sealed.account);
            signer.close();
            let expected = Zeroizing::new(
                owllet_core::derive_bitcoin_account_xprv_from_seed(
                    &seed,
                    BitcoinNetworkDto::Mainnet.core(),
                    0,
                    purpose.core(),
                )
                .unwrap(),
            );
            assert!(!sealed.encrypted_vault.contains(expected.as_str()));
            let exported = Zeroizing::new(
                export_bitcoin_vault_xprv(
                    sealed.account.clone(),
                    sealed.encrypted_vault.clone(),
                    vec![42; 32],
                )
                .unwrap(),
            );
            assert_eq!(exported.as_str(), expected.as_str());
            assert!(open_bitcoin_signing_account(
                sealed.account.clone(),
                "corrupted".into(),
                vec![42; 32]
            )
            .is_err());
            let mut wrong = sealed.account;
            wrong.account_index += 1;
            assert!(
                open_bitcoin_signing_account(wrong, sealed.encrypted_vault, vec![42; 32]).is_err()
            );
        }
        assert!(seal_bitcoin_seed_account(
            seed.to_vec(),
            BitcoinNetworkDto::Mainnet,
            0,
            BitcoinPurposeDto::Bip84,
            vec![42; 31]
        )
        .is_err());
    }
}
