use bip39::{Language, Mnemonic};
use rand::Rng;

pub fn generate_mnemonic() -> String {
    // Generate a new 12-word mnemonic phrase (128 bits of entropy).
    // rand::rng() in rand 0.10 returns a ThreadRng that is TryCryptoRng — a
    // reseeding CSPRNG seeded from the OS (SysRng/getrandom). That is the
    // correct source for mnemonic entropy; do not swap it for a user-space
    // generator.
    let mut entropy = [0u8; 16];
    rand::rng().fill_bytes(&mut entropy);
    let mnemonic = Mnemonic::from_entropy_in(Language::English, &entropy)
        .expect("16-byte (128-bit) entropy is always a valid BIP-39 entropy size");
    mnemonic.to_string()
}

pub fn validate_mnemonic(phrase: String) -> bool {
    Mnemonic::parse_in(Language::English, &phrase).is_ok()
}

pub fn mnemonic_to_seed(phrase: String) -> Result<Vec<u8>, String> {
    let mnemonic = Mnemonic::parse_in(Language::English, &phrase)
        .map_err(|e| format!("Invalid mnemonic: {}", e))?;

    // Convert to seed (empty passphrase per Dart implementation)
    let seed = mnemonic.to_seed("");
    Ok(seed.to_vec())
}
