use base64::{engine::general_purpose, Engine as _};
use flutter_rust_bridge::frb;
use solana_keypair::Keypair;
use solana_signer::Signer;
use std::fmt;
use zeroize::Zeroizing;

#[frb(dart_code = "
  @override
  String toString() {
    return 'SolanaPrivateKeyImport(privateKeyBytes: ***REDACTED***, address: $address)';
  }
")]
pub struct SolanaPrivateKeyImport {
    pub private_key_bytes: Vec<u8>,
    pub address: String,
}

impl fmt::Debug for SolanaPrivateKeyImport {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("SolanaPrivateKeyImport")
            .field("private_key_bytes", &"***REDACTED***")
            .field("address", &self.address)
            .finish()
    }
}

pub fn derive_wallet_from_seed(seed: Vec<u8>, derivation_index: u32) -> Result<String, String> {
    derive_evm_private_key_from_seed(seed, derivation_index)
}

pub fn derive_evm_private_key_from_seed(
    seed: Vec<u8>,
    derivation_index: u32,
) -> Result<String, String> {
    let seed = Zeroizing::new(seed);
    owllet_core::accounts::derive_evm_private_key_from_seed(&seed, derivation_index)
}

pub fn derive_evm_address_from_seed(
    seed: Vec<u8>,
    derivation_index: u32,
) -> Result<String, String> {
    let seed = Zeroizing::new(seed);
    owllet_core::accounts::derive_evm_address_from_seed(&seed, derivation_index)
}

pub fn derive_evm_address_from_private_key(private_key_hex: String) -> Result<String, String> {
    let private_key_hex = Zeroizing::new(private_key_hex);
    owllet_core::accounts::derive_evm_address_from_private_key(&private_key_hex)
}

pub fn derive_evm_public_key_from_private_key(private_key_hex: String) -> Result<String, String> {
    let private_key_hex = Zeroizing::new(private_key_hex);
    owllet_core::accounts::derive_evm_public_key_from_private_key(&private_key_hex)
}

pub fn derive_tron_private_key_from_seed(
    seed: Vec<u8>,
    derivation_index: u32,
) -> Result<String, String> {
    let seed = Zeroizing::new(seed);
    owllet_core::accounts::derive_tron_private_key_from_seed(&seed, derivation_index)
}

pub fn derive_tron_address_from_seed(
    seed: Vec<u8>,
    derivation_index: u32,
) -> Result<String, String> {
    let seed = Zeroizing::new(seed);
    owllet_core::accounts::derive_tron_address_from_seed(&seed, derivation_index)
}

pub fn derive_tron_address_from_private_key(private_key_hex: String) -> Result<String, String> {
    let private_key_hex = Zeroizing::new(private_key_hex);
    owllet_core::accounts::derive_tron_address_from_private_key(&private_key_hex)
}

pub fn derive_solana_private_key_from_seed(
    seed: Vec<u8>,
    derivation_index: u32,
) -> Result<Vec<u8>, String> {
    let seed = Zeroizing::new(seed);
    owllet_core::accounts::derive_solana_private_key_from_seed(&seed, derivation_index)
}

pub fn derive_solana_address_from_seed(
    seed: Vec<u8>,
    derivation_index: u32,
) -> Result<String, String> {
    let seed = Zeroizing::new(seed);
    owllet_core::accounts::derive_solana_address_from_seed(&seed, derivation_index)
}

pub fn derive_solana_address_from_private_key(
    private_key_bytes: Vec<u8>,
) -> Result<String, String> {
    let private_key_bytes = Zeroizing::new(private_key_bytes);
    owllet_core::accounts::derive_solana_address_from_private_key(&private_key_bytes)
}

pub fn sign_solana_message(private_key_bytes: Vec<u8>, message: Vec<u8>) -> Result<String, String> {
    let private_key_bytes = Zeroizing::new(private_key_bytes);
    owllet_core::signing::sign_solana_message(&private_key_bytes, &message)
}

pub fn normalize_solana_private_key(private_key: String) -> Result<SolanaPrivateKeyImport, String> {
    let private_key = Zeroizing::new(private_key);
    let keypair = parse_solana_private_key(&private_key)?;
    Ok(SolanaPrivateKeyImport {
        private_key_bytes: keypair.secret_bytes().to_vec(),
        address: keypair.pubkey().to_string(),
    })
}

pub fn sign_tron_raw_hash(private_key_hex: String, raw_hash_hex: String) -> Result<String, String> {
    let private_key_hex = Zeroizing::new(private_key_hex);
    owllet_core::signing::sign_tron_raw_hash(&private_key_hex, &raw_hash_hex)
}

fn parse_solana_private_key(private_key: &str) -> Result<Keypair, String> {
    let trimmed = private_key.trim();
    if trimmed.is_empty() {
        return Err("Solana private key is empty".to_string());
    }

    if trimmed.starts_with('[') {
        let bytes: Vec<u8> = serde_json::from_str(trimmed)
            .map_err(|e| format!("Invalid Solana JSON byte array: {e}"))?;
        return solana_keypair_from_bytes(bytes, "JSON array");
    }

    let compact = Zeroizing::new(trimmed.split_whitespace().collect::<String>());
    if let Some(hex_value) = compact
        .strip_prefix("0x")
        .or_else(|| compact.strip_prefix("0X"))
    {
        return solana_keypair_from_bytes(parse_solana_key_hex(hex_value)?, "hex");
    }

    if !compact.is_empty() && compact.chars().all(|c| c.is_ascii_hexdigit()) {
        return solana_keypair_from_bytes(parse_solana_key_hex(&compact)?, "hex");
    }

    if let Ok(keypair) = Keypair::try_from_base58_string(&compact) {
        return Ok(keypair);
    }

    match bs58::decode(&compact).into_vec() {
        Ok(bytes) => solana_keypair_from_bytes(bytes, "base58"),
        Err(base58_error) => {
            let bytes = general_purpose::STANDARD
                .decode(&compact)
                .map_err(|base64_error| {
                    format!(
                        "Invalid Solana private key format: base58 decode failed ({base58_error}); base64 decode failed ({base64_error})"
                    )
                })?;
            solana_keypair_from_bytes(bytes, "base64")
        }
    }
}

fn parse_solana_key_hex(value: &str) -> Result<Vec<u8>, String> {
    if value.len() != 64 && value.len() != 128 {
        return Err(format!(
            "Invalid Solana hex key length: expected 64 or 128 hex characters, got {}",
            value.len()
        ));
    }
    hex::decode(value).map_err(|e| format!("Invalid Solana hex key: {e}"))
}

pub(crate) fn solana_keypair_from_bytes(bytes: Vec<u8>, source: &str) -> Result<Keypair, String> {
    let bytes = Zeroizing::new(bytes);
    owllet_core::accounts::solana_keypair_from_bytes(&bytes, source)
}

#[cfg(test)]
mod tests {
    use super::{
        derive_evm_address_from_seed, derive_evm_private_key_from_seed,
        derive_solana_address_from_seed, derive_solana_private_key_from_seed,
        derive_tron_address_from_seed, derive_tron_private_key_from_seed,
        normalize_solana_private_key, sign_solana_message, sign_tron_raw_hash,
    };
    use bip39::{Language, Mnemonic};
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};
    use secp256k1::{ecdsa::RecoverableSignature, Message, Secp256k1};
    use solana_keypair::Keypair;

    fn fixture_seed() -> Vec<u8> {
        Mnemonic::parse_in(
            Language::English,
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
        )
        .expect("fixture mnemonic")
        .to_seed("")
        .to_vec()
    }

    #[test]
    fn derives_known_family_addresses_from_seed() {
        let seed = fixture_seed();

        assert_eq!(
            derive_evm_private_key_from_seed(seed.clone(), 0).expect("evm private key"),
            "1ab42cc412b618bdea3a599e3c9bae199ebf030895b039e9db1e30dafb12b727"
        );
        assert_eq!(
            derive_evm_address_from_seed(seed.clone(), 0).expect("evm address"),
            "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
        );

        assert_eq!(
            derive_solana_address_from_seed(seed.clone(), 0).expect("solana address"),
            "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
        );
        assert_eq!(
            derive_tron_address_from_seed(seed, 0).expect("tron address"),
            "TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH"
        );
    }

    #[test]
    fn solana_message_signature_verifies() {
        let seed = fixture_seed();
        let private_key = derive_solana_private_key_from_seed(seed, 0).expect("solana private key");
        let message = b"Owllet Solana signing fixture".to_vec();
        let signature =
            sign_solana_message(private_key.clone(), message.clone()).expect("solana signature");

        let public_key_bytes = bs58::decode(
            derive_solana_address_from_seed(fixture_seed(), 0).expect("solana address"),
        )
        .into_vec()
        .expect("base58 public key");
        let verifying_key = VerifyingKey::from_bytes(
            public_key_bytes
                .as_slice()
                .try_into()
                .expect("32-byte public key"),
        )
        .expect("verifying key");
        let signature_bytes = bs58::decode(signature)
            .into_vec()
            .expect("base58 signature");
        let parsed_signature = Signature::from_slice(&signature_bytes).expect("signature parse");

        verifying_key
            .verify(&message, &parsed_signature)
            .expect("signature verification");
    }

    #[test]
    fn normalizes_phantom_style_solana_base58_keypair() {
        let private_key =
            derive_solana_private_key_from_seed(fixture_seed(), 0).expect("solana private key");
        let secret: [u8; 32] = private_key
            .as_slice()
            .try_into()
            .expect("32-byte private key");
        let keypair = Keypair::new_from_array(secret);

        let imported =
            normalize_solana_private_key(keypair.to_base58_string()).expect("imported key");

        assert_eq!(imported.private_key_bytes, private_key);
        assert_eq!(
            imported.address,
            derive_solana_address_from_seed(fixture_seed(), 0).expect("solana address")
        );
    }

    #[test]
    fn rejects_mismatched_solana_keypair_public_half() {
        let private_key =
            derive_solana_private_key_from_seed(fixture_seed(), 0).expect("solana private key");
        let secret: [u8; 32] = private_key
            .as_slice()
            .try_into()
            .expect("32-byte private key");
        let keypair = Keypair::new_from_array(secret);
        let mut bytes = keypair.to_bytes();
        bytes[63] ^= 1;
        let encoded = bs58::encode(bytes).into_string();

        let error = normalize_solana_private_key(encoded).expect_err("invalid keypair");

        assert!(error.contains("Invalid Solana base58 keypair bytes"));
    }

    #[test]
    fn tron_raw_hash_signature_is_recoverable() {
        let seed = fixture_seed();
        let private_key = derive_tron_private_key_from_seed(seed, 0).expect("tron private key");
        let raw_hash = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";
        let signature = sign_tron_raw_hash(private_key, raw_hash.to_string()).expect("signature");
        let signature = signature.strip_prefix("0x").expect("0x signature");

        assert_eq!(signature.len(), 130);

        let recovery_id = secp256k1::ecdsa::RecoveryId::from_u8_masked(
            u8::from_str_radix(&signature[128..130], 16).expect("recovery id"),
        );
        let compact = hex::decode(&signature[..128]).expect("compact signature");
        let recoverable =
            RecoverableSignature::from_compact(&compact, recovery_id).expect("recoverable sig");
        let digest = hex::decode(raw_hash).expect("hash");
        let message = Message::from_digest(digest.as_slice().try_into().expect("32-byte hash"));
        Secp256k1::new()
            .recover_ecdsa(message, &recoverable)
            .expect("recover public key");
    }
}
