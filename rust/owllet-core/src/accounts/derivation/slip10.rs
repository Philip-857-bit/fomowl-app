use super::HARDENED_OFFSET;
use hmac::{Hmac, Mac};
use sha2::Sha512;
use zeroize::Zeroize;

type HmacSha512 = Hmac<Sha512>;

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
