use base64::{engine::general_purpose, Engine as _};
use bip32::{DerivationPath, XPrv};
use hmac::{Hmac, Mac};
use secp256k1::{PublicKey, Secp256k1, SecretKey};
use sha2::{Digest, Sha256, Sha512};
use sha3::Keccak256;
use solana_keypair::Keypair;
use solana_signer::Signer;
use std::str::FromStr;
use zeroize::Zeroize;

use flutter_rust_bridge::frb;
use std::fmt;

type HmacSha512 = Hmac<Sha512>;

const HARDENED_OFFSET: u32 = 0x8000_0000;
const EVM_DERIVATION_PURPOSE: u32 = 44;
const EVM_COIN_TYPE: u32 = 60;
const SOLANA_COIN_TYPE: u32 = 501;
const TRON_COIN_TYPE: u32 = 195;

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

impl Drop for SolanaPrivateKeyImport {
    fn drop(&mut self) {
        self.private_key_bytes.zeroize();
    }
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
    let path = format!(
        "m/{}'/{}'/0'/0/{}",
        EVM_DERIVATION_PURPOSE, EVM_COIN_TYPE, derivation_index
    );
    derive_secp256k1_private_key(seed, &path)
}

pub fn derive_evm_address_from_seed(
    seed: Vec<u8>,
    derivation_index: u32,
) -> Result<String, String> {
    let private_key_hex = derive_evm_private_key_from_seed(seed, derivation_index)?;
    derive_evm_address_from_private_key(private_key_hex)
}

pub fn derive_evm_address_from_private_key(private_key_hex: String) -> Result<String, String> {
    let public_key = public_key_from_private_key(&private_key_hex)?;
    Ok(evm_address_from_public_key(&public_key))
}

pub fn derive_tron_private_key_from_seed(
    seed: Vec<u8>,
    derivation_index: u32,
) -> Result<String, String> {
    let path = format!(
        "m/{}'/{}'/0'/0/{}",
        EVM_DERIVATION_PURPOSE, TRON_COIN_TYPE, derivation_index
    );
    derive_secp256k1_private_key(seed, &path)
}

pub fn derive_tron_address_from_seed(
    seed: Vec<u8>,
    derivation_index: u32,
) -> Result<String, String> {
    let private_key_hex = derive_tron_private_key_from_seed(seed, derivation_index)?;
    derive_tron_address_from_private_key(private_key_hex)
}

pub fn derive_tron_address_from_private_key(private_key_hex: String) -> Result<String, String> {
    let public_key = public_key_from_private_key(&private_key_hex)?;
    Ok(tron_address_from_public_key(&public_key))
}

pub fn derive_solana_private_key_from_seed(
    seed: Vec<u8>,
    derivation_index: u32,
) -> Result<Vec<u8>, String> {
    validate_seed(&seed)?;

    let path = [
        hardened(EVM_DERIVATION_PURPOSE)?,
        hardened(SOLANA_COIN_TYPE)?,
        hardened(derivation_index)?,
        hardened(0)?,
    ];
    let mut key = slip10_ed25519_master_key(&seed)?;
    for child in path {
        key = slip10_ed25519_derive_child(&key, child)?;
    }

    let mut private_key_bytes = key.key.to_vec();
    key.zeroize();
    Ok(private_key_bytes)
}

pub fn derive_solana_address_from_seed(
    seed: Vec<u8>,
    derivation_index: u32,
) -> Result<String, String> {
    let private_key_bytes = derive_solana_private_key_from_seed(seed, derivation_index)?;
    derive_solana_address_from_private_key(private_key_bytes)
}

pub fn derive_solana_address_from_private_key(mut private_key_bytes: Vec<u8>) -> Result<String, String> {
    let keypair = solana_keypair_from_bytes(private_key_bytes.clone(), "Solana private key")?;
    private_key_bytes.zeroize();
    Ok(keypair.pubkey().to_string())
}

pub fn sign_solana_message(mut private_key_bytes: Vec<u8>, message: Vec<u8>) -> Result<String, String> {
    let keypair = solana_keypair_from_bytes(private_key_bytes.clone(), "Solana private key")?;
    private_key_bytes.zeroize();
    Ok(keypair.sign_message(&message).to_string())
}

pub fn normalize_solana_private_key(mut private_key_bytes: Vec<u8>) -> Result<SolanaPrivateKeyImport, String> {
    let keypair = parse_solana_private_key(&private_key_bytes)?;
    private_key_bytes.zeroize();
    Ok(SolanaPrivateKeyImport {
        private_key_bytes: keypair.secret_bytes().to_vec(),
        address: keypair.pubkey().to_string(),
    })
}

pub fn sign_tron_raw_hash(private_key_hex: String, raw_hash_hex: String) -> Result<String, String> {
    let digest = parse_32_byte_hex(&raw_hash_hex, "TRON raw transaction hash")?;
    crate::api::secp256k1_api::sign_digest_with_recovery_id(private_key_hex, digest, false)
}

fn derive_secp256k1_private_key(seed: Vec<u8>, path_str: &str) -> Result<String, String> {
    validate_seed(&seed)?;

    let path =
        DerivationPath::from_str(path_str).map_err(|e| format!("Invalid derivation path: {e}"))?;

    let mut extended_prv = XPrv::new(seed.as_slice())
        .map_err(|e| format!("Failed to create master key from seed: {e:?}"))?;

    for child_num in path.into_iter() {
        let child = extended_prv
            .derive_child(child_num)
            .map_err(|e| format!("Failed to derive child key: {e:?}"))?;
        // Volatile-wipe the parent key bytes before overwriting the binding.
        // write_volatile prevents the compiler from eliding the wipe.
        unsafe {
            let p = &extended_prv as *const XPrv as *mut u8;
            for i in 0..std::mem::size_of::<XPrv>() {
                std::ptr::write_volatile(p.add(i), 0u8);
            }
        }
        extended_prv = child;
    }

    let key_hex = hex::encode(extended_prv.private_key().to_bytes());
    // Volatile-wipe the final key before it is dropped.
    unsafe {
        let p = &extended_prv as *const XPrv as *mut u8;
        for i in 0..std::mem::size_of::<XPrv>() {
            std::ptr::write_volatile(p.add(i), 0u8);
        }
    }
    Ok(key_hex)
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

    let compact = trimmed.split_whitespace().collect::<String>();
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

fn solana_keypair_from_private_key_hex(private_key_hex: &str) -> Result<Keypair, String> {
    let mut secret = parse_32_byte_hex(private_key_hex, "Solana private key")?;
    let keypair = Keypair::new_from_array(secret);
    secret.zeroize();
    Ok(keypair)
}

fn solana_keypair_from_bytes(mut bytes: Vec<u8>, source: &str) -> Result<Keypair, String> {
    let result = match bytes.len() {
        32 => {
            let mut secret = [0u8; 32];
            secret.copy_from_slice(&bytes);
            let keypair = Keypair::new_from_array(secret);
            secret.zeroize();
            Ok(keypair)
        }
        64 => Keypair::try_from(bytes.as_slice())
            .map_err(|e| format!("Invalid Solana {source} keypair bytes: {e}")),
        len => Err(format!(
            "Invalid Solana {source} key length: expected 32-byte seed or 64-byte keypair, got {len} bytes"
        )),
    };
    bytes.zeroize();
    result
}

fn validate_seed(seed: &[u8]) -> Result<(), String> {
    if seed.len() < 16 || seed.len() > 64 {
        return Err(format!(
            "Invalid BIP-32 seed length: expected 16..=64 bytes, got {}",
            seed.len()
        ));
    }
    Ok(())
}

fn hardened(index: u32) -> Result<u32, String> {
    index
        .checked_add(HARDENED_OFFSET)
        .ok_or_else(|| format!("Invalid hardened child index: {index}"))
}

#[derive(Clone)]
struct Ed25519Slip10Key {
    key: [u8; 32],
    chain_code: [u8; 32],
}

impl Zeroize for Ed25519Slip10Key {
    fn zeroize(&mut self) {
        self.key.zeroize();
        self.chain_code.zeroize();
    }
}

impl Drop for Ed25519Slip10Key {
    fn drop(&mut self) {
        self.zeroize();
    }
}

fn slip10_ed25519_master_key(seed: &[u8]) -> Result<Ed25519Slip10Key, String> {
    let mut mac = HmacSha512::new_from_slice(b"ed25519 seed")
        .map_err(|e| format!("Failed to initialize SLIP-0010 HMAC: {e}"))?;
    mac.update(seed);
    slip10_key_from_hmac(mac.finalize().into_bytes().as_slice())
}

fn slip10_ed25519_derive_child(
    parent: &Ed25519Slip10Key,
    child_index: u32,
) -> Result<Ed25519Slip10Key, String> {
    if child_index < HARDENED_OFFSET {
        return Err("SLIP-0010 Ed25519 derivation only supports hardened children".to_string());
    }

    let mut data = [0u8; 37];
    data[1..33].copy_from_slice(&parent.key);
    data[33..37].copy_from_slice(&child_index.to_be_bytes());

    let mut mac = HmacSha512::new_from_slice(&parent.chain_code)
        .map_err(|e| format!("Failed to initialize child HMAC: {e}"))?;
    mac.update(&data);
    data.zeroize();
    slip10_key_from_hmac(mac.finalize().into_bytes().as_slice())
}

fn slip10_key_from_hmac(output: &[u8]) -> Result<Ed25519Slip10Key, String> {
    if output.len() != 64 {
        return Err(format!(
            "Invalid SLIP-0010 HMAC output length: expected 64 bytes, got {}",
            output.len()
        ));
    }
    let mut key = [0u8; 32];
    let mut chain_code = [0u8; 32];
    key.copy_from_slice(&output[..32]);
    chain_code.copy_from_slice(&output[32..]);
    Ok(Ed25519Slip10Key { key, chain_code })
}

fn parse_32_byte_hex(value: &str, label: &str) -> Result<[u8; 32], String> {
    let normalized = value.trim().strip_prefix("0x").unwrap_or(value.trim());
    let bytes = hex::decode(normalized).map_err(|e| format!("Invalid {label} hex: {e}"))?;
    if bytes.len() != 32 {
        return Err(format!(
            "Invalid {label} length: expected 32 bytes, got {}",
            bytes.len()
        ));
    }
    let mut out = [0u8; 32];
    out.copy_from_slice(&bytes);
    Ok(out)
}

fn public_key_from_private_key(private_key_hex: &str) -> Result<PublicKey, String> {
    let secp = Secp256k1::new();
    let secret_bytes = parse_32_byte_hex(private_key_hex, "private key")?;
    let secret_key = SecretKey::from_byte_array(secret_bytes)
        .map_err(|e| format!("Invalid private key: {e}"))?;
    Ok(PublicKey::from_secret_key(&secp, &secret_key))
}

fn evm_address_from_public_key(public_key: &PublicKey) -> String {
    let uncompressed = public_key.serialize_uncompressed();
    let hash = Keccak256::digest(&uncompressed[1..]);
    to_eip55_address(&hash[12..])
}

fn tron_address_from_public_key(public_key: &PublicKey) -> String {
    let uncompressed = public_key.serialize_uncompressed();
    let hash = Keccak256::digest(&uncompressed[1..]);
    let mut payload = Vec::with_capacity(25);
    payload.push(0x41);
    payload.extend_from_slice(&hash[12..]);

    let checksum = Sha256::digest(Sha256::digest(&payload));
    payload.extend_from_slice(&checksum[..4]);
    bs58::encode(payload).into_string()
}

fn to_eip55_address(address: &[u8]) -> String {
    let lower = hex::encode(address);
    let hash = hex::encode(Keccak256::digest(lower.as_bytes()));
    let mut result = String::with_capacity(42);
    result.push_str("0x");

    for (idx, ch) in lower.chars().enumerate() {
        let hash_nibble = u8::from_str_radix(&hash[idx..idx + 1], 16).unwrap_or(0);
        if ch.is_ascii_hexdigit() && hash_nibble >= 8 {
            result.push(ch.to_ascii_uppercase());
        } else {
            result.push(ch);
        }
    }

    result
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
        let secret = hex::decode(&private_key).expect("private key hex");
        let secret: [u8; 32] = secret.as_slice().try_into().expect("32-byte private key");
        let keypair = Keypair::new_from_array(secret);

        let imported =
            normalize_solana_private_key(keypair.to_base58_string()).expect("imported key");

        assert_eq!(imported.private_key_hex, private_key);
        assert_eq!(
            imported.address,
            derive_solana_address_from_seed(fixture_seed(), 0).expect("solana address")
        );
    }

    #[test]
    fn rejects_mismatched_solana_keypair_public_half() {
        let private_key =
            derive_solana_private_key_from_seed(fixture_seed(), 0).expect("solana private key");
        let secret = hex::decode(private_key).expect("private key hex");
        let secret: [u8; 32] = secret.as_slice().try_into().expect("32-byte private key");
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
