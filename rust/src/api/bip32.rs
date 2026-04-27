use bip32::{DerivationPath, XPrv};
use ed25519_dalek::{Signer, SigningKey};
use hmac::{Hmac, Mac};
use secp256k1::{PublicKey, Secp256k1, SecretKey};
use sha2::{Digest, Sha256, Sha512};
use sha3::Keccak256;
use std::str::FromStr;
use zeroize::Zeroize;

type HmacSha512 = Hmac<Sha512>;

const HARDENED_OFFSET: u32 = 0x8000_0000;
const EVM_DERIVATION_PURPOSE: u32 = 44;
const EVM_COIN_TYPE: u32 = 60;
const SOLANA_COIN_TYPE: u32 = 501;
const TRON_COIN_TYPE: u32 = 195;

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
) -> Result<String, String> {
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

    let private_key_hex = hex::encode(key.key);
    key.zeroize();
    Ok(private_key_hex)
}

pub fn derive_solana_address_from_seed(
    seed: Vec<u8>,
    derivation_index: u32,
) -> Result<String, String> {
    let private_key_hex = derive_solana_private_key_from_seed(seed, derivation_index)?;
    derive_solana_address_from_private_key(private_key_hex)
}

pub fn derive_solana_address_from_private_key(private_key_hex: String) -> Result<String, String> {
    let secret = parse_32_byte_hex(&private_key_hex, "Solana private key")?;
    let signing_key = SigningKey::from_bytes(&secret);
    Ok(bs58::encode(signing_key.verifying_key().to_bytes()).into_string())
}

pub fn sign_solana_message(private_key_hex: String, message: Vec<u8>) -> Result<String, String> {
    let secret = parse_32_byte_hex(&private_key_hex, "Solana private key")?;
    let signing_key = SigningKey::from_bytes(&secret);
    let signature = signing_key.sign(&message);
    Ok(bs58::encode(signature.to_bytes()).into_string())
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
        extended_prv = extended_prv
            .derive_child(child_num)
            .map_err(|e| format!("Failed to derive child key: {e:?}"))?;
    }

    Ok(hex::encode(extended_prv.private_key().to_bytes()))
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
        derive_tron_address_from_seed, derive_tron_private_key_from_seed, sign_solana_message,
        sign_tron_raw_hash,
    };
    use bip39::{Language, Mnemonic};
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};
    use secp256k1::{ecdsa::RecoverableSignature, Message, Secp256k1};

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
