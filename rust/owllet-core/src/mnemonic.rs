use bip39::{Language, Mnemonic};
use rand::Rng;

/// Generates a new 12-word BIP-39 English mnemonic phrase (128 bits of entropy).
///
/// Uses `rand::rng()` (a cryptographically secure PRNG seeded from OS entropy)
/// to produce 16 bytes of entropy.
pub fn generate_mnemonic() -> String {
    let mut entropy = [0u8; 16];
    rand::rng().fill_bytes(&mut entropy);
    let mnemonic = Mnemonic::from_entropy_in(Language::English, &entropy)
        .expect("16-byte (128-bit) entropy is always a valid BIP-39 entropy size");
    mnemonic.to_string()
}

/// Validates a BIP-39 mnemonic phrase against the English wordlist and checksum.
pub fn validate_mnemonic(phrase: &str) -> bool {
    Mnemonic::parse_in(Language::English, phrase).is_ok()
}

/// Derives a 64-byte BIP-39 binary seed from an English mnemonic phrase with an empty passphrase.
///
/// Returns an error with the exact legacy message `Invalid mnemonic: <error>` if parsing fails.
pub fn mnemonic_to_seed(phrase: &str) -> Result<Vec<u8>, String> {
    let mnemonic = Mnemonic::parse_in(Language::English, phrase)
        .map_err(|e| format!("Invalid mnemonic: {}", e))?;

    let seed = mnemonic.to_seed("");
    Ok(seed.to_vec())
}

#[cfg(test)]
mod tests {
    use super::*;

    const KNOWN_MNEMONIC: &str =
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
    const EXPECTED_SEED_HEX: &str =
        "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4";

    #[test]
    fn test_generate_mnemonic_structure() {
        let mnemonic = generate_mnemonic();
        let words: Vec<&str> = mnemonic.split_whitespace().collect();
        assert_eq!(
            words.len(),
            12,
            "Generated mnemonic must contain exactly 12 words"
        );
        assert!(
            validate_mnemonic(&mnemonic),
            "Generated mnemonic must be valid"
        );
    }

    #[test]
    fn test_validate_mnemonic() {
        assert!(validate_mnemonic(KNOWN_MNEMONIC));
        assert!(!validate_mnemonic(""));
        assert!(!validate_mnemonic("not a mnemonic phrase"));
        assert!(!validate_mnemonic(
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"
        ));
    }

    #[test]
    fn test_known_mnemonic_to_seed() {
        let seed = mnemonic_to_seed(KNOWN_MNEMONIC).expect("valid mnemonic to seed");
        let hex_seed: String = seed.iter().map(|b| format!("{b:02x}")).collect();
        assert_eq!(hex_seed, EXPECTED_SEED_HEX);
    }

    #[test]
    fn test_mnemonic_to_seed_error_format() {
        let err = mnemonic_to_seed("invalid phrase").unwrap_err();
        assert!(
            err.starts_with("Invalid mnemonic: "),
            "Error string must preserve prefix, got: {err}"
        );
    }
}
