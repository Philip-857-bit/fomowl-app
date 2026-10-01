//! Flutter-facing FFI facade delegating to the reusable `owllet-core` crate.

pub fn generate_mnemonic() -> String {
    owllet_core::mnemonic::generate_mnemonic()
}

pub fn validate_mnemonic(phrase: String) -> bool {
    owllet_core::mnemonic::validate_mnemonic(&phrase)
}

pub fn mnemonic_to_seed(phrase: String) -> Result<Vec<u8>, String> {
    owllet_core::mnemonic::mnemonic_to_seed(&phrase)
}
