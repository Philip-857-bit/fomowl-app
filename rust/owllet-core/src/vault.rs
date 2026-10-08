//! Authenticated account records independent of host storage and authentication.
//! Hosts protect wrapping keys and supply unique nonces. Explicit export is a
//! separate recovery operation; ordinary open returns opaque signing custody.
use crate::session::{AccountFamily, AccountHandle, SigningSession};
use aes_gcm::{
    aead::{Aead, Payload},
    Aes256Gcm, KeyInit, Nonce,
};
use serde::{Deserialize, Serialize};
use zeroize::Zeroizing;

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Envelope {
    version: u32,
    algorithm: String,
    family: String,
    address: String,
    nonce_hex: String,
    ciphertext_hex: String,
}
#[derive(Debug, PartialEq, Eq)]
pub enum VaultError {
    InvalidRecord,
    InvalidKey,
    AddressMismatch,
    AuthenticationFailed,
}
impl std::fmt::Display for VaultError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::InvalidRecord => "Invalid or unsupported vault record",
            Self::InvalidKey => "Invalid account private key",
            Self::AddressMismatch => "Vault account address mismatch",
            Self::AuthenticationFailed => "Vault authentication failed",
        })
    }
}
impl std::error::Error for VaultError {}
fn family_name(family: AccountFamily) -> &'static str {
    match family {
        #[cfg(feature = "evm")]
        AccountFamily::Evm => "evm",
        #[cfg(feature = "solana")]
        AccountFamily::Solana => "solana",
        #[cfg(feature = "tron")]
        AccountFamily::Tron => "tron",
    }
}
fn canonical_address(family: AccountFamily, address: &str) -> Result<String, VaultError> {
    if address.is_empty() || address.len() > 100 || !address.is_ascii() {
        return Err(VaultError::InvalidRecord);
    }
    #[cfg(feature = "evm")]
    if family == AccountFamily::Evm {
        let body = address
            .strip_prefix("0x")
            .ok_or(VaultError::InvalidRecord)?;
        if body.len() != 40 || !body.bytes().all(|c| c.is_ascii_hexdigit()) {
            return Err(VaultError::InvalidRecord);
        }
        return Ok(address.to_ascii_lowercase());
    }
    let _ = family;
    Ok(address.to_owned())
}
fn import_key(
    family: AccountFamily,
    private_key: &str,
) -> Result<(SigningSession, AccountHandle), VaultError> {
    let mut session = SigningSession::new();
    let handle = match family {
        #[cfg(feature = "evm")]
        AccountFamily::Evm => session.import_evm_key(private_key.to_owned()),
        #[cfg(feature = "tron")]
        AccountFamily::Tron => session.import_tron_key(private_key.to_owned()),
        #[cfg(feature = "solana")]
        AccountFamily::Solana => {
            let bytes =
                Zeroizing::new(hex::decode(private_key).map_err(|_| VaultError::InvalidKey)?);
            session.import_solana_key(bytes.to_vec())
        }
    }
    .map_err(|_| VaultError::InvalidKey)?;
    Ok((session, handle))
}
fn verify_key(
    family: AccountFamily,
    private_key: &str,
    expected: &str,
) -> Result<(SigningSession, AccountHandle), VaultError> {
    let (session, handle) = import_key(family, private_key)?;
    let actual = session
        .account_info(&handle)
        .map_err(|_| VaultError::InvalidKey)?
        .address;
    if canonical_address(family, &actual)? != canonical_address(family, expected)? {
        return Err(VaultError::AddressMismatch);
    }
    Ok((session, handle))
}
fn aad(family: AccountFamily, address: &str) -> String {
    format!(
        "owllet-wallet:v1:AES-256-GCM:{}:{address}",
        family_name(family)
    )
}
/// Caller MUST never reuse a nonce under the same wrapping key, including retries.
pub fn seal_account_key(
    family: AccountFamily,
    private_key: &str,
    expected_address: &str,
    wrapping_key: &[u8; 32],
    nonce: &[u8; 12],
) -> Result<String, VaultError> {
    let address = canonical_address(family, expected_address)?;
    verify_key(family, private_key, &address)?;
    let cipher = Aes256Gcm::new(wrapping_key.into());
    let authenticated = aad(family, &address);
    let ciphertext = cipher
        .encrypt(
            &Nonce::from(*nonce),
            Payload {
                msg: private_key.as_bytes(),
                aad: authenticated.as_bytes(),
            },
        )
        .map_err(|_| VaultError::AuthenticationFailed)?;
    serde_json::to_string(&Envelope {
        version: 1,
        algorithm: "AES-256-GCM".into(),
        family: family_name(family).into(),
        address,
        nonce_hex: hex::encode(nonce),
        ciphertext_hex: hex::encode(ciphertext),
    })
    .map_err(|_| VaultError::InvalidRecord)
}
fn decrypt_key(
    family: AccountFamily,
    record: &str,
    expected: &str,
    wrapping_key: &[u8; 32],
) -> Result<Zeroizing<String>, VaultError> {
    if record.len() > 4096 {
        return Err(VaultError::InvalidRecord);
    }
    let envelope: Envelope = serde_json::from_str(record).map_err(|_| VaultError::InvalidRecord)?;
    if envelope.version != 1
        || envelope.algorithm != "AES-256-GCM"
        || envelope.family != family_name(family)
    {
        return Err(VaultError::InvalidRecord);
    }
    let address = canonical_address(family, expected)?;
    if envelope.address != address {
        return Err(VaultError::AddressMismatch);
    }
    let nonce: [u8; 12] = hex::decode(envelope.nonce_hex)
        .map_err(|_| VaultError::InvalidRecord)?
        .try_into()
        .map_err(|_| VaultError::InvalidRecord)?;
    let ciphertext = hex::decode(envelope.ciphertext_hex).map_err(|_| VaultError::InvalidRecord)?;
    let cipher = Aes256Gcm::new(wrapping_key.into());
    let authenticated = aad(family, &address);
    let plaintext = Zeroizing::new(
        cipher
            .decrypt(
                &Nonce::from(nonce),
                Payload {
                    msg: &ciphertext,
                    aad: authenticated.as_bytes(),
                },
            )
            .map_err(|_| VaultError::AuthenticationFailed)?,
    );
    Ok(Zeroizing::new(
        std::str::from_utf8(&plaintext)
            .map_err(|_| VaultError::InvalidKey)?
            .to_owned(),
    ))
}
/// Ordinary account access returns custody rather than plaintext.
pub fn open_account_vault(
    family: AccountFamily,
    record: &str,
    expected: &str,
    wrapping_key: &[u8; 32],
) -> Result<(SigningSession, AccountHandle), VaultError> {
    let key = decrypt_key(family, record, expected, wrapping_key)?;
    verify_key(family, &key, expected)
}
/// Explicit recovery/export boundary. Hosts MUST authenticate the user before
/// calling and protect returned key material. Never use this for routine signing.
pub fn export_account_key(
    family: AccountFamily,
    record: &str,
    expected: &str,
    wrapping_key: &[u8; 32],
) -> Result<Zeroizing<String>, VaultError> {
    let key = decrypt_key(family, record, expected, wrapping_key)?;
    verify_key(family, &key, expected)?;
    Ok(key)
}
#[cfg(feature = "evm")]
pub fn seal_evm_key(
    key: &str,
    address: &str,
    wrapping_key: &[u8; 32],
    nonce: &[u8; 12],
) -> Result<String, VaultError> {
    seal_account_key(AccountFamily::Evm, key, address, wrapping_key, nonce)
}
#[cfg(feature = "evm")]
pub fn open_evm_vault(
    record: &str,
    address: &str,
    wrapping_key: &[u8; 32],
) -> Result<(SigningSession, AccountHandle), VaultError> {
    open_account_vault(AccountFamily::Evm, record, address, wrapping_key)
}
#[cfg(all(test, feature = "evm"))]
mod tests {
    use super::*;
    const KEY: &str = "0000000000000000000000000000000000000000000000000000000000000001";
    fn fixture() -> (String, String) {
        let address = crate::derive_evm_address_from_private_key(KEY).unwrap();
        (
            seal_evm_key(KEY, &address, &[7; 32], &[9; 12]).unwrap(),
            address,
        )
    }
    #[test]
    fn roundtrip_retains_signing_identity_and_lock_lifecycle() {
        let (record, address) = fixture();
        assert!(!record.contains(KEY));
        let (mut session, handle) = open_evm_vault(&record, &address, &[7; 32]).unwrap();
        assert_eq!(
            session
                .account_info(&handle)
                .unwrap()
                .address
                .to_ascii_lowercase(),
            address.to_ascii_lowercase()
        );
        let actual = session.sign_personal_message(&handle, "hello").unwrap();
        assert_eq!(actual, crate::sign_personal_message(KEY, "hello").unwrap());
        session.lock();
        assert!(session.sign_personal_message(&handle, "hello").is_err());
    }
    #[test]
    fn rejects_wrong_key_address_and_tampered_envelope() {
        let (record, address) = fixture();
        assert!(matches!(
            open_evm_vault(&record, &address, &[8; 32]),
            Err(VaultError::AuthenticationFailed)
        ));
        assert!(open_evm_vault(
            &record,
            "0x0000000000000000000000000000000000000000",
            &[7; 32]
        )
        .is_err());
        for field in ["nonce_hex", "ciphertext_hex"] {
            let mut value: serde_json::Value = serde_json::from_str(&record).unwrap();
            let text = value[field].as_str().unwrap();
            value[field] = format!(
                "{}{}",
                if text.starts_with('0') { "1" } else { "0" },
                &text[1..]
            )
            .into();
            assert!(matches!(
                open_evm_vault(&value.to_string(), &address, &[7; 32]),
                Err(VaultError::AuthenticationFailed)
            ));
        }
        for (field, value) in [
            ("version", serde_json::json!(2)),
            ("algorithm", serde_json::json!("other")),
            ("family", serde_json::json!("tron")),
            ("extra", serde_json::json!(true)),
        ] {
            let mut envelope: serde_json::Value = serde_json::from_str(&record).unwrap();
            envelope[field] = value;
            assert!(matches!(
                open_evm_vault(&envelope.to_string(), &address, &[7; 32]),
                Err(VaultError::InvalidRecord)
            ));
        }
    }
    #[test]
    fn rejects_invalid_import_and_malformed_records() {
        let (_, address) = fixture();
        assert!(matches!(
            seal_evm_key("invalid", &address, &[7; 32], &[9; 12]),
            Err(VaultError::InvalidKey)
        ));
        assert!(seal_evm_key(
            KEY,
            "0x0000000000000000000000000000000000000000",
            &[7; 32],
            &[9; 12]
        )
        .is_err());
        for record in ["{}".to_string(), "x".repeat(4097)] {
            assert!(matches!(
                open_evm_vault(&record, &address, &[7; 32]),
                Err(VaultError::InvalidRecord)
            ));
        }
    }
}
