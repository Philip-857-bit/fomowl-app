use argon2::{
    password_hash::{PasswordHasher, SaltString},
    Argon2, Params,
};
use base64::{engine::general_purpose, Engine as _};

/// Derive passcode hash using Argon2id
pub fn derive_passcode_hash_argon2(
    passcode: String,
    salt_base64: String,
    iterations: u32,
    memory_power_of_2: u32,
) -> Result<String, String> {
    // Decode salt
    let salt_bytes = general_purpose::STANDARD
        .decode(&salt_base64)
        .map_err(|e| format!("Failed to decode salt: {}", e))?;

    // Create a SaltString safely
    let salt = SaltString::encode_b64(&salt_bytes)
        .map_err(|e| format!("Invalid salt length/format: {}", e))?;

    // Configure Argon2id
    let params = Params::new(
        memory_power_of_2,
        iterations,
        1,
        Some(Params::DEFAULT_OUTPUT_LEN),
    )
    .map_err(|e| format!("Invalid Argon2 parameters: {}", e))?;
    
    let argon2 = Argon2::new(
        argon2::Algorithm::Argon2id,
        argon2::Version::V0x13,
        params,
    );

    // Hash the passcode
    let password_hash = argon2
        .hash_password(passcode.as_bytes(), &salt)
        .map_err(|e| format!("Argon2 hashing failed: {}", e))?;

    // Extract the raw hash bytes
    let hash_bytes = password_hash
        .hash
        .ok_or_else(|| "Failed to extract hash bytes".to_string())?;

    // Return as Base64 encoded string to match the Dart implementation
    Ok(general_purpose::STANDARD.encode(hash_bytes.as_bytes()))
}
