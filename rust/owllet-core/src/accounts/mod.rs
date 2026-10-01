pub mod derivation;
pub mod evm;
pub mod solana;
pub mod tron;

pub use derivation::*;
pub use evm::*;
pub use solana::*;
pub use tron::*;

#[cfg(test)]
mod tests {
    use super::*;

    const KNOWN_SEED_HEX: &str =
        "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4";

    fn known_seed() -> Vec<u8> {
        hex::decode(KNOWN_SEED_HEX).expect("valid hex seed")
    }

    #[test]
    fn test_known_evm_derivation_index_0() {
        let seed = known_seed();
        let priv_key =
            derive_evm_private_key_from_seed(&seed, 0).expect("derive EVM private key index 0");
        assert_eq!(
            priv_key,
            "1ab42cc412b618bdea3a599e3c9bae199ebf030895b039e9db1e30dafb12b727"
        );

        let address = derive_evm_address_from_seed(&seed, 0).expect("derive EVM address index 0");
        assert_eq!(address, "0x9858EfFD232B4033E47d90003D41EC34EcaEda94");

        let address_from_priv = derive_evm_address_from_private_key(&priv_key)
            .expect("derive EVM address from private key");
        assert_eq!(
            address_from_priv,
            "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
        );
    }

    #[test]
    fn test_known_solana_derivation_index_0() {
        let seed = known_seed();
        let priv_seed = derive_solana_private_key_from_seed(&seed, 0)
            .expect("derive Solana private key index 0");
        assert_eq!(
            hex::encode(&priv_seed),
            "37df573b3ac4ad5b522e064e25b63ea16bcbe79d449e81a0268d1047948bb445"
        );

        let address =
            derive_solana_address_from_seed(&seed, 0).expect("derive Solana address index 0");
        assert_eq!(address, "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk");

        let address_from_priv = derive_solana_address_from_private_key(&priv_seed)
            .expect("derive Solana address from private key bytes");
        assert_eq!(
            address_from_priv,
            "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
        );
    }

    #[test]
    fn test_known_tron_derivation_index_0() {
        let seed = known_seed();
        let priv_key =
            derive_tron_private_key_from_seed(&seed, 0).expect("derive TRON private key index 0");
        assert_eq!(
            priv_key,
            "b5a4cea271ff424d7c31dc12a3e43e401df7a40d7412a15750f3f0b6b5449a28"
        );

        let address = derive_tron_address_from_seed(&seed, 0).expect("derive TRON address index 0");
        assert_eq!(address, "TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH");

        let address_from_priv = derive_tron_address_from_private_key(&priv_key)
            .expect("derive TRON address from private key");
        assert_eq!(address_from_priv, "TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH");
    }

    #[test]
    fn test_negative_invalid_seed_length() {
        let short_seed = vec![0u8; 15];
        let err = derive_evm_private_key_from_seed(&short_seed, 0).unwrap_err();
        assert!(err.contains("Invalid BIP-32 seed length"));

        let long_seed = vec![0u8; 65];
        let err_solana = derive_solana_private_key_from_seed(&long_seed, 0).unwrap_err();
        assert!(err_solana.contains("Invalid BIP-32 seed length"));
    }

    #[test]
    fn test_negative_invalid_evm_private_key() {
        let err = derive_evm_address_from_private_key("invalid_hex").unwrap_err();
        assert!(err.contains("Invalid private key"));

        let err_len = derive_evm_address_from_private_key("010203").unwrap_err();
        assert!(err_len.contains("Invalid private key length"));
    }

    #[test]
    fn test_negative_invalid_tron_private_key() {
        let err = derive_tron_address_from_private_key("not_hex").unwrap_err();
        assert!(err.contains("Invalid private key"));
    }

    #[test]
    fn test_negative_invalid_solana_private_key_bytes() {
        let invalid_len_bytes = vec![0u8; 31];
        let err = derive_solana_address_from_private_key(&invalid_len_bytes).unwrap_err();
        assert!(err.contains("Invalid Solana Solana private key key length"));
    }
}
