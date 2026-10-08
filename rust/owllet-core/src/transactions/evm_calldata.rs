//! Standard token/NFT ABI calls shared by every host. Amounts are decimal
//! base units; fee discovery, permissions, and RPC remain outside the engine.
use ethers_core::{
    abi::{encode, Token},
    types::{Address, U256},
};
use sha3::{Digest, Keccak256};

fn address(value: &str) -> Result<Token, String> {
    value
        .parse::<Address>()
        .map(Token::Address)
        .map_err(|_| "Invalid EVM call address".into())
}
fn uint(value: &str) -> Result<Token, String> {
    if value.is_empty() || !value.bytes().all(|b| b.is_ascii_digit()) {
        return Err("EVM call integer must be unsigned decimal base units".into());
    }
    U256::from_dec_str(value)
        .map(Token::Uint)
        .map_err(|_| "EVM call integer exceeds uint256".into())
}
fn call(signature: &str, params: &[Token]) -> Vec<u8> {
    let mut data = Keccak256::digest(signature.as_bytes())[..4].to_vec();
    data.extend(encode(params));
    data
}
pub fn encode_erc20_transfer(to: &str, amount: &str) -> Result<Vec<u8>, String> {
    Ok(call(
        "transfer(address,uint256)",
        &[address(to)?, uint(amount)?],
    ))
}
pub fn encode_erc20_approve(spender: &str, amount: &str) -> Result<Vec<u8>, String> {
    Ok(call(
        "approve(address,uint256)",
        &[address(spender)?, uint(amount)?],
    ))
}
pub fn encode_erc20_allowance(owner: &str, spender: &str) -> Result<Vec<u8>, String> {
    Ok(call(
        "allowance(address,address)",
        &[address(owner)?, address(spender)?],
    ))
}
pub fn encode_erc721_safe_transfer(
    from: &str,
    to: &str,
    token_id: &str,
) -> Result<Vec<u8>, String> {
    Ok(call(
        "safeTransferFrom(address,address,uint256)",
        &[address(from)?, address(to)?, uint(token_id)?],
    ))
}
pub fn encode_erc1155_safe_transfer(
    from: &str,
    to: &str,
    token_id: &str,
    amount: &str,
    data: &[u8],
) -> Result<Vec<u8>, String> {
    Ok(call(
        "safeTransferFrom(address,address,uint256,uint256,bytes)",
        &[
            address(from)?,
            address(to)?,
            uint(token_id)?,
            uint(amount)?,
            Token::Bytes(data.to_vec()),
        ],
    ))
}
/// Strictly decodes one ABI uint256 word, such as an allowance result.
pub fn decode_uint256_result(data: &[u8]) -> Result<String, String> {
    if data.len() != 32 {
        return Err("Expected one 32-byte ABI uint256 result".into());
    }
    Ok(U256::from_big_endian(data).to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    const FROM: &str = "0x1111111111111111111111111111111111111111";
    const TO: &str = "0x3535353535353535353535353535353535353535";
    #[test]
    fn standard_calls_match_fixed_selectors_and_words() {
        let from = "0000000000000000000000001111111111111111111111111111111111111111";
        let to = "0000000000000000000000003535353535353535353535353535353535353535";
        let amount = format!("{:064x}", 42);
        assert_eq!(
            hex::encode(encode_erc20_transfer(TO, "42").unwrap()),
            format!("a9059cbb{to}{amount}")
        );
        assert_eq!(
            hex::encode(encode_erc20_approve(TO, "42").unwrap()),
            format!("095ea7b3{to}{amount}")
        );
        assert_eq!(
            hex::encode(encode_erc20_allowance(FROM, TO).unwrap()),
            format!("dd62ed3e{from}{to}")
        );
        assert_eq!(
            hex::encode(encode_erc721_safe_transfer(FROM, TO, "42").unwrap()),
            format!("42842e0e{from}{to}{amount}")
        );
        assert_eq!(
            hex::encode(encode_erc1155_safe_transfer(FROM, TO, "42", "3", &[]).unwrap()),
            format!("f242432a{from}{to}{amount}{:064x}{:064x}{:064x}", 3, 160, 0)
        );
    }
    #[test]
    fn dynamic_bytes_have_length_offset_and_padding() {
        let data = encode_erc1155_safe_transfer(FROM, TO, "0", "1", &[1, 2, 3]).unwrap();
        assert_eq!(data.len(), 228);
        assert_eq!(&data[196..199], &[1, 2, 3]);
        assert!(data[199..].iter().all(|b| *b == 0));
        assert_eq!(data[195], 3);
    }
    #[test]
    fn uint256_boundaries_and_malformed_inputs_fail_closed() {
        let max = U256::MAX.to_string();
        assert!(encode_erc20_approve(TO, &max).is_ok());
        for amount in [
            "-1",
            "+1",
            "0x01",
            "1.1",
            "",
            "115792089237316195423570985008687907853269984665640564039457584007913129639936",
        ] {
            assert!(encode_erc20_transfer(TO, amount).is_err());
        }
        assert!(encode_erc20_transfer("invalid", "1").is_err());
        assert_eq!(decode_uint256_result(&[255; 32]).unwrap(), max);
        assert!(decode_uint256_result(&[0; 31]).is_err());
        assert!(decode_uint256_result(&[0; 64]).is_err());
    }
}
