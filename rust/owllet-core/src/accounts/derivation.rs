use bip32::{DerivationPath, XPrv};
use hmac::{Hmac, Mac};
use secp256k1::{PublicKey, Secp256k1, SecretKey};
use sha2::Sha512;
use std::str::FromStr;
use zeroize::Zeroize;

type HmacSha512 = Hmac<Sha512>;

pub const HARDENED_OFFSET: u32 = 0x8000_0000;

pub fn validate_seed(seed: &[u8]) -> Result<(), String> {
    if seed.len() < 16 || seed.len() > 64 {
        return Err(format!(
            "Invalid BIP-32 seed length: expected 16..=64 bytes, got {}",
            seed.len()
        ));
    }
    Ok(())
}

pub fn hardened(index: u32) -> Result<u32, String> {
    index
        .checked_add(HARDENED_OFFSET)
        .ok_or_else(|| format!("Invalid hardened child index: {index}"))
}

pub fn derive_secp256k1_private_key(seed: &[u8], path_str: &str) -> Result<String, String> {
    validate_seed(seed)?;

    let path =
        DerivationPath::from_str(path_str).map_err(|e| format!("Invalid derivation path: {e}"))?;

    let mut extended_prv =
        XPrv::new(seed).map_err(|e| format!("Failed to create master key from seed: {e:?}"))?;

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

#[derive(Clone)]
pub struct Ed25519Slip10Key {
    pub key: [u8; 32],
    pub chain_code: [u8; 32],
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

pub fn slip10_ed25519_master_key(seed: &[u8]) -> Result<Ed25519Slip10Key, String> {
    let mut mac = HmacSha512::new_from_slice(b"ed25519 seed")
        .map_err(|e| format!("Failed to initialize SLIP-0010 HMAC: {e}"))?;
    mac.update(seed);
    slip10_key_from_hmac(&mac.finalize().into_bytes())
}

pub fn slip10_ed25519_derive_child(
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
    slip10_key_from_hmac(&mac.finalize().into_bytes())
}

pub fn slip10_key_from_hmac(output: &[u8]) -> Result<Ed25519Slip10Key, String> {
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

pub fn parse_32_byte_hex(value: &str, label: &str) -> Result<[u8; 32], String> {
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

pub fn public_key_from_private_key(private_key_hex: &str) -> Result<PublicKey, String> {
    let secp = Secp256k1::new();
    let secret_bytes = parse_32_byte_hex(private_key_hex, "private key")?;
    let secret_key = SecretKey::from_byte_array(secret_bytes)
        .map_err(|e| format!("Invalid private key: {e}"))?;
    Ok(PublicKey::from_secret_key(&secp, &secret_key))
}
