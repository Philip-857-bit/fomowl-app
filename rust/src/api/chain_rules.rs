//! Thin host bindings for reusable chain formats. RPC and permission policy
//! remain with the application; these functions never read key material.
use owllet_core::transactions::evm_calldata as abi;

pub fn encode_erc20_transfer_call(to_address: String, amount: String) -> Result<Vec<u8>, String> {
    abi::encode_erc20_transfer(&to_address, &amount)
}
pub fn encode_erc20_approve_call(
    spender_address: String,
    amount: String,
) -> Result<Vec<u8>, String> {
    abi::encode_erc20_approve(&spender_address, &amount)
}
pub fn encode_erc20_allowance_call(
    owner_address: String,
    spender_address: String,
) -> Result<Vec<u8>, String> {
    abi::encode_erc20_allowance(&owner_address, &spender_address)
}
pub fn encode_erc721_transfer_call(
    from_address: String,
    to_address: String,
    token_id: String,
) -> Result<Vec<u8>, String> {
    abi::encode_erc721_safe_transfer(&from_address, &to_address, &token_id)
}
pub fn encode_erc1155_transfer_call(
    from_address: String,
    to_address: String,
    token_id: String,
    amount: String,
    data: Vec<u8>,
) -> Result<Vec<u8>, String> {
    abi::encode_erc1155_safe_transfer(&from_address, &to_address, &token_id, &amount, &data)
}
pub fn decode_abi_uint256_result(data_hex: String) -> Result<String, String> {
    let bytes = hex::decode(data_hex.strip_prefix("0x").unwrap_or(&data_hex))
        .map_err(|_| "Invalid ABI result hex")?;
    abi::decode_uint256_result(&bytes)
}
pub fn tron_personal_message_digest(message: String) -> Vec<u8> {
    owllet_core::signing::tron::tron_personal_message_digest(&message).to_vec()
}

pub fn solana_transaction_message_bytes(transaction: Vec<u8>) -> Result<Vec<u8>, String> {
    owllet_core::transactions::solana_wire::solana_transaction_message_bytes(&transaction)
}
pub fn attach_solana_transaction_signature(
    transaction: Vec<u8>,
    signer_address: String,
    signature: Vec<u8>,
) -> Result<Vec<u8>, String> {
    owllet_core::transactions::solana_wire::attach_solana_transaction_signature(
        &transaction,
        &signer_address,
        &signature,
    )
}
