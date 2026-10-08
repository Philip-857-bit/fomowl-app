//! These public-API tests run in single-chain and minimal builds as well as the
//! full build, so feature gates cannot silently remove compatibility coverage.

use owllet_core::{generate_mnemonic_from_entropy, mnemonic_to_seed, validate_mnemonic};

const PHRASE: &str =
    "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

#[test]
fn mnemonic_api_works_without_platform_entropy() {
    let phrase = generate_mnemonic_from_entropy(&[0u8; 16]);
    assert_eq!(phrase, PHRASE);
    assert!(validate_mnemonic(&phrase));
    assert_eq!(
        hex::encode(mnemonic_to_seed(&phrase).expect("fixture seed")),
        "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4"
    );
}

#[cfg(all(feature = "secp256k1", not(feature = "evm"), not(feature = "tron")))]
#[test]
fn standalone_secp256k1_feature_preserves_derivation_and_signing() {
    use secp256k1::{ecdsa::RecoverableSignature, ecdsa::RecoveryId, Message, Secp256k1};

    let seed = mnemonic_to_seed(PHRASE).expect("fixture seed");
    let key =
        owllet_core::derive_secp256k1_private_key(&seed, "m/44'/60'/0'/0/0").expect("derive key");
    assert_eq!(
        key,
        "1ab42cc412b618bdea3a599e3c9bae199ebf030895b039e9db1e30dafb12b727"
    );
    let digest = [1u8; 32];
    let signature = owllet_core::sign_digest(&key, digest).expect("sign digest");
    let bytes = hex::decode(signature.trim_start_matches("0x")).expect("signature bytes");
    let signature = RecoverableSignature::from_compact(
        &bytes[..64],
        RecoveryId::try_from(i32::from(bytes[64]) - 27).expect("recovery id"),
    )
    .expect("recoverable signature");
    assert_eq!(
        Secp256k1::new()
            .recover_ecdsa(Message::from_digest(digest), &signature)
            .expect("recover signer"),
        owllet_core::public_key_from_private_key(&key).expect("derive public key")
    );
}

#[cfg(feature = "evm")]
#[test]
fn evm_feature_preserves_address_and_signing() {
    let seed = mnemonic_to_seed(PHRASE).expect("fixture seed");
    let key = owllet_core::derive_evm_private_key_from_seed(&seed, 0).expect("derive key");
    assert_eq!(
        owllet_core::derive_evm_address_from_private_key(&key).expect("derive address"),
        "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
    );
    let signature = owllet_core::sign_personal_message(&key, "hello").expect("sign message");
    let signature: ethers_core::types::Signature = signature.parse().expect("signature");
    assert_eq!(
        format!("{:#x}", signature.recover("hello").expect("recover signer")),
        "0x9858effd232b4033e47d90003d41ec34ecaeda94"
    );
}

#[cfg(feature = "evm")]
#[test]
fn evm_public_key_metadata_preserves_unprefixed_xy_format() {
    let key = format!("{:064x}", 1);
    assert_eq!(
        owllet_core::derive_evm_public_key_from_private_key(&key).expect("public key"),
        concat!(
            "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
            "483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"
        )
    );
}

#[cfg(feature = "solana")]
#[test]
fn solana_feature_preserves_address_and_signing() {
    let seed = mnemonic_to_seed(PHRASE).expect("fixture seed");
    let key = owllet_core::derive_solana_private_key_from_seed(&seed, 0).expect("derive key");
    let address =
        owllet_core::derive_solana_address_from_private_key(&key).expect("derive address");
    assert_eq!(address, "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk");
    let signature = owllet_core::sign_solana_message(&key, b"hello").expect("sign message");
    let public_key: [u8; 32] = bs58::decode(address)
        .into_vec()
        .expect("public key bytes")
        .try_into()
        .expect("32-byte public key");
    let signature_bytes = bs58::decode(signature).into_vec().expect("signature bytes");
    let signature = ed25519_dalek::Signature::from_slice(&signature_bytes).expect("signature");
    ed25519_dalek::VerifyingKey::from_bytes(&public_key)
        .expect("verifying key")
        .verify_strict(b"hello", &signature)
        .expect("valid signature");
}

#[cfg(feature = "tron")]
#[test]
fn tron_feature_preserves_address_and_signing() {
    use secp256k1::{ecdsa::RecoverableSignature, ecdsa::RecoveryId, Message, Secp256k1};

    let seed = mnemonic_to_seed(PHRASE).expect("fixture seed");
    let key = owllet_core::derive_tron_private_key_from_seed(&seed, 0).expect("derive key");
    let address = owllet_core::derive_tron_address_from_private_key(&key).expect("derive address");
    assert_eq!(address, "TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH");
    let digest = [1u8; 32];
    let signature =
        owllet_core::sign_tron_raw_hash(&key, &hex::encode(digest)).expect("sign transaction hash");
    let bytes = hex::decode(signature.strip_prefix("0x").expect("signature prefix"))
        .expect("signature bytes");
    let signature = RecoverableSignature::from_compact(
        &bytes[..64],
        RecoveryId::try_from(i32::from(bytes[64])).expect("recovery id"),
    )
    .expect("recoverable signature");
    let public_key = Secp256k1::new()
        .recover_ecdsa(Message::from_digest(digest), &signature)
        .expect("recover signer");
    assert_eq!(
        owllet_core::tron_address_from_public_key(&public_key),
        address
    );
}
