use solana_signer::Signer;

pub fn sign_solana_message(private_key_bytes: &[u8], message: &[u8]) -> Result<String, String> {
    let keypair =
        crate::accounts::solana_keypair_from_bytes(private_key_bytes, "Solana private key")?;
    Ok(keypair.sign_message(message).to_string())
}
