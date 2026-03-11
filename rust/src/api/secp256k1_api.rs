use secp256k1::{Message, Secp256k1, SecretKey};
use sha3::{Digest, Keccak256};
use std::str::FromStr;

pub fn sign_personal_message(private_key_hex: String, message: String) -> Result<String, String> {
    // Parse private key
    let secp = Secp256k1::new();
    let secret_key = SecretKey::from_str(&private_key_hex)
        .map_err(|e| format!("Invalid private key: {}", e))?;

    // Create Ethereum Signed Message prefix
    let prefix = format!("\x19Ethereum Signed Message:\n{}", message.len());
    let mut prefixed_message = prefix.into_bytes();
    prefixed_message.extend_from_slice(message.as_bytes());

    // Hash the message with Keccak256
    let hash = Keccak256::digest(&prefixed_message);

    // Create Message from exact 32-byte array
    let mut hash_arr = [0u8; 32];
    hash_arr.copy_from_slice(&hash);
    let msg = Message::from_digest(hash_arr);

    // Sign the message
    let (recovery_id, sig) = secp.sign_ecdsa_recoverable(msg, &secret_key).serialize_compact();
    let mut signature = sig.to_vec();
    signature.push(i32::from(recovery_id) as u8 + 27);

    // Return hex encoded signature with 0x prefix
    Ok(format!("0x{}", hex::encode(signature)))
}

// typed data (EIP-712) implementation will require the ethabi or ethers-rs crates 
// for full dynamic struct parsing. For speed, the Dart eth_sig_util is often acceptable,
// but we will provide an interface here for future modularity.
pub fn sign_typed_data(_private_key_hex: String, _json_data: String) -> Result<String, String> {
    // EIP-712 parsing in Rust requires significant boilerplate compared to Dart.
    // We will leave this stubbed out for the first migration step, relying on Dart for this
    // specific niche feature while the bottleneck (BIP39/Argon2) is fully migrated.
    Err("EIP-712 Typed Data signing not yet migrated to Rust. Use Dart's EthSigUtil for now.".to_string())
}
