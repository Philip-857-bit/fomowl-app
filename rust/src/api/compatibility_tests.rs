// ============================================================================
// Owllet Wallet Compatibility Baseline Tests
//
// INVARIANT CONTRACT:
// These vectors define Owllet's wallet compatibility contract.
// Any future change that modifies one of these addresses for the same mnemonic
// + derivation index is a BREAKING WALLET CHANGE and must not be merged
// without an explicit migration strategy.
//
// Owllet Derivation Invariants:
// - EVM:    m/44'/60'/0'/0/{index}       (secp256k1 -> Keccak256 -> EIP-55)
// - Solana: m/44'/501'/{index}'/0'       (SLIP-10 Ed25519 -> Base58)
// - TRON:   m/44'/195'/0'/0/{index}      (secp256k1 -> Keccak256 -> 0x41 Base58Check)
// ============================================================================

use crate::api::bip32::{
    derive_evm_address_from_private_key, derive_evm_address_from_seed,
    derive_evm_private_key_from_seed, derive_solana_address_from_private_key,
    derive_solana_address_from_seed, derive_solana_private_key_from_seed,
    derive_tron_address_from_private_key, derive_tron_address_from_seed,
    derive_tron_private_key_from_seed, normalize_solana_private_key, sign_solana_message,
    sign_tron_raw_hash,
};
use crate::api::bip39::{mnemonic_to_seed, validate_mnemonic};
use crate::api::secp256k1_api::{sign_personal_message, sign_typed_data};

use ed25519_dalek::{Signature as DalekSignature, Verifier, VerifyingKey};
use ethers_core::types::transaction::eip712::TypedData;
use ethers_core::types::Signature as EthersSignature;
use secp256k1::ecdsa::{RecoverableSignature, RecoveryId};
use secp256k1::{Message, Secp256k1};
use sha2::{Digest as Sha2Digest, Sha256};
use sha3::Keccak256;
use solana_keypair::Keypair;

#[derive(Debug, Clone, Copy)]
pub struct WalletVector {
    pub index: u32,
    pub evm_priv_hex: &'static str,
    pub evm_address: &'static str,
    pub solana_priv_hex: &'static str,
    pub solana_address: &'static str,
    pub tron_priv_hex: &'static str,
    pub tron_address: &'static str,
}

#[derive(Debug, Clone, Copy)]
pub struct WalletCompatibilityFixture {
    pub name: &'static str,
    pub mnemonic: &'static str,
    pub seed_hex: &'static str,
    pub vectors: &'static [WalletVector],
}

// ----------------------------------------------------------------------------
// Deterministic Test Vectors (Independently Verified)
// ----------------------------------------------------------------------------

pub const FIXTURE_1_ABANDON_12: WalletCompatibilityFixture = WalletCompatibilityFixture {
    name: "BIP-39 12-Word Standard Vector (abandon)",
    mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
    seed_hex: "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4",
    vectors: &[
        WalletVector {
            index: 0,
            evm_priv_hex: "1ab42cc412b618bdea3a599e3c9bae199ebf030895b039e9db1e30dafb12b727",
            evm_address: "0x9858EfFD232B4033E47d90003D41EC34EcaEda94",
            solana_priv_hex: "37df573b3ac4ad5b522e064e25b63ea16bcbe79d449e81a0268d1047948bb445",
            solana_address: "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk",
            tron_priv_hex: "b5a4cea271ff424d7c31dc12a3e43e401df7a40d7412a15750f3f0b6b5449a28",
            tron_address: "TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH",
        },
        WalletVector {
            index: 1,
            evm_priv_hex: "9a983cb3d832fbde5ab49d692b7a8bf5b5d232479c99333d0fc8e1d21f1b55b6",
            evm_address: "0x6Fac4D18c912343BF86fa7049364Dd4E424Ab9C0",
            solana_priv_hex: "ba5e7b6e3680b4eb81db8e54c8e466b2e9a899355888403355d858ab985d2fc4",
            solana_address: "Hh8QwFUA6MtVu1qAoq12ucvFHNwCcVTV7hpWjeY1Hztb",
            tron_priv_hex: "edb728e259afca2ddcc428459e7681b8414668649aedbc8d25c0872da219b2e6",
            tron_address: "TSeJkUh4Qv67VNFwY8LaAxERygNdy6NQZK",
        },
        WalletVector {
            index: 2,
            evm_priv_hex: "5b824bd1104617939cd07c117ddc4301eb5beeca0904f964158963d69ab9d831",
            evm_address: "0xb6716976A3ebe8D39aCEB04372f22Ff8e6802D7A",
            solana_priv_hex: "2f2d4843b13aec3867edc61fbeac4a1fa58797a8629aa35217bd183405bcc202",
            solana_address: "7WktogJEd2wQ9eH2oWusmcoFTgeYi6rS632UviTBJ2jm",
            tron_priv_hex: "0e5684898be2d272d54eb2be3fd41a12f720db6358cee02c2d23043eed4bf7a2",
            tron_address: "TYJPRrdB5APNeRs4R7fYZSwW3TcrTKw2gx",
        },
        WalletVector {
            index: 5,
            evm_priv_hex: "5a8787e6b7e11a74a22ee97b8164c7d69cd5668c6065bbfbc87e6a34a24b135c",
            evm_address: "0xA40cFBFc8534FFC84E20a7d8bBC3729B26a35F6f",
            solana_priv_hex: "62ef17513b1a1ffa96eb94c441fd3e7fc0f43df1a3780c96c14f6439ed40c2ac",
            solana_address: "2EUrWmf5xMmWER9BtDbXbGbZjoL7R3eTDMXYR6H6cKPj",
            tron_priv_hex: "b46d74cf377ce98d89d7c9eade68eb863791296122e2b1324057fdc190369cd0",
            tron_address: "TBdYXtwq18cAhi1BA574TrP6tw2G86anu1",
        },
        WalletVector {
            index: 10,
            evm_priv_hex: "1d8e676c6da57922d80336cffc5bf9020d0cce4730cff872aeb2dcce08320ce6",
            evm_address: "0xEf4ba16373841C53a9Ba168873fC3967118C1d37",
            solana_priv_hex: "0492ead19236fe31cb115a2a65f6a387bf3b9ca4d5ee4dc224b2250b06dcfb63",
            solana_address: "AcLS2t8rzEqeQnbJK4HBS7g8NBCa7SowjARdvxtqBE3t",
            tron_priv_hex: "34af354605ea14b98c27780a84debc11dadfd14e5fbbbf0eb388643579c018ae",
            tron_address: "TZFYo9FdnVdqFzBUZ3Wu4vwPqN9HVvF8jC",
        },
    ],
};

pub const FIXTURE_2_LEGAL_12: WalletCompatibilityFixture = WalletCompatibilityFixture {
    name: "BIP-39 12-Word Diverse Vocabulary Vector (legal winner)",
    mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow",
    seed_hex: "878386efb78845b3355bd15ea4d39ef97d179cb712b77d5c12b6be415fffeffe5f377ba02bf3f8544ab800b955e51fbff09828f682052a20faa6addbbddfb096",
    vectors: &[
        WalletVector {
            index: 0,
            evm_priv_hex: "33fa40f84e854b941c2b0436dd4a256e1df1cb41b9c1c0ccc8446408c19b8bf9",
            evm_address: "0x58A57ed9d8d624cBD12e2C467D34787555bB1b25",
            solana_priv_hex: "6987bdb06aa8a243a3019f41489ffa8e609c953a885a748d1849a8df760aa479",
            solana_address: "BLeUXTx9thHGT7VJUtF9vHEmfMDgW1nnKZ9UVer2CoLX",
            tron_priv_hex: "abde94314a030ae8860a58db8adde7fc962cca2455db9d2979e480038c49dcbc",
            tron_address: "TUJ2YbSDGtCqzRz7quPQidRCMC98jDAPXc",
        },
        WalletVector {
            index: 1,
            evm_priv_hex: "5e4f6a62c67d2b8735d3cda66e37854d7a80f59aab639c3a4bed7e2c7432a4e4",
            evm_address: "0x0D3eB21b6b21833A4939Cfff4810E9AE0758e12C",
            solana_priv_hex: "c5a802888a31cc47f49d1f758b3314fedaf1a51d2b3f05f69cd25740d95f149b",
            solana_address: "EdjcxP8MmXP4yRHguEVoH75kbXVfZNFXPgNfL9NqcXXK",
            tron_priv_hex: "edcc66fce35befa1a43a43ba93e57ba71a378b84ea7ea49ba6204063b25f53bf",
            tron_address: "TDsWXR86aKu4u3DnJiZrVxwuwDitd19qve",
        },
        WalletVector {
            index: 2,
            evm_priv_hex: "d46507376b3a8a4af4f1f934375df25213a09857a3ed1086ba284c82d387904b",
            evm_address: "0xe42f4612e154153B68e241e8FDe337e0c4dD6bBD",
            solana_priv_hex: "186d0fcf6c2f1c5ab85fd7491c393b1747f4d3dce83054d4348cd5af137f90f5",
            solana_address: "AFG4eoTGSCdNemYFQhhJBqT7tJwo3WdC4Raeq9SkXx7p",
            tron_priv_hex: "cb573d8c4419e131f3422952675ce2b3aff0e0c1c866f1ade049267fabf2ce2d",
            tron_address: "TLqWTABA7pkL7dT23xAmS52mmKajUqGdnf",
        },
        WalletVector {
            index: 5,
            evm_priv_hex: "f3a08eab76cded41a29234a8def21af5c6e508a99a12a97e61250e4c44729fdf",
            evm_address: "0x4fb070eF70961D204961c69B954B99808b9694BC",
            solana_priv_hex: "791800e0b486aab0816f72974292bae86a037a0b34db4f66c7086a7089655241",
            solana_address: "BnWk78yTZn6PmKnFQ1j2fqL4ZXekhQ6VYZVDNtU7d6Cq",
            tron_priv_hex: "970014b23df6b8cc56a1018dfd9f62829921478b482e8966253dc64af62620b7",
            tron_address: "TU5S19hCpnJKPwZ5ZAFnniRVehCEektoxU",
        },
        WalletVector {
            index: 10,
            evm_priv_hex: "283f32d137cb33954eaa0cb00734122e01fea93383d54ffef8abf8e2b91b1cab",
            evm_address: "0xF51B647eda3277c35436f52C8A1De50308C08f9D",
            solana_priv_hex: "65d4dfc95937f796bbef9cf555cc1ba89bf895fba37094d1c3d161130de181b4",
            solana_address: "AAzWqQifNKwwL6aLwD5dBqt37sjvP5TuWyqoJM51m7vc",
            tron_priv_hex: "34fe6464c350399d8aba64f23811a699d25f182d3cf0fc0c6d6bc5282ffd38df",
            tron_address: "TEH5Csd2UscTscnu4x4sUpE3qMy93QaT9L",
        },
    ],
};

pub const FIXTURE_3_LETTER_24: WalletCompatibilityFixture = WalletCompatibilityFixture {
    name: "BIP-39 24-Word Vector (letter advice)",
    mnemonic: "letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic bless",
    seed_hex: "848bbe19cad445e46f35fd3d1a89463583ac2b60b5eb4cfcf955731775a5d9e17a81a71613fed83f1ae27b408478fdec2bbc75b5161d1937aa7cdf4ad686ef5f",
    vectors: &[
        WalletVector {
            index: 0,
            evm_priv_hex: "30534b1bded1d468262758af1c0c0868747d2db4341d2856da2aef4ca8efbcd9",
            evm_address: "0xc6e4A4f5A9743fAB9bC8D648499e63E083d2519A",
            solana_priv_hex: "cf1cefe713112580a9166613c3145c8b5e23de6ca3ce75424a92d42b5f7a6a7a",
            solana_address: "8kew2ge6x5ZxGnEf9cGTZo8232HjNakSbRF5v6fm5reH",
            tron_priv_hex: "afd696ca627d9c6ad7cc53b0fdd0677590aee85efbb29b222e8d5c7ca8a2d78d",
            tron_address: "TPkWYD6sB4fjey4o13L9rJo3SCQEF8Vay4",
        },
        WalletVector {
            index: 1,
            evm_priv_hex: "73ecbaeba49dbcd55661dfc7d0203c3e942ddf4faff31ede9dae2e94165317e2",
            evm_address: "0x13b1cfA9015733adaC7386BbAc45C8205C8Ac3E4",
            solana_priv_hex: "26022ff52d1e56f3736d0244211e60775000e517c3a6628662cec6d85f7a72a4",
            solana_address: "3fmHYFHNduRTQBREKj7q6eNfaxnSUzgVLiD8wo5CsD5c",
            tron_priv_hex: "3b62ece344267623ed8a4f5055545472864efa891663fb12ae915f665b3eade4",
            tron_address: "TUaXDaHWTQ8tvPsTN8LuzEddzyFMpDPvQn",
        },
        WalletVector {
            index: 2,
            evm_priv_hex: "f61d5784b2c5cdd8eaae656cd745c9f89e1d0d19311d43a5a72a49266c75355d",
            evm_address: "0x2A8390B2d455a52b55d36C36B80Fe0449207Adf5",
            solana_priv_hex: "8af119b5341b0c3a774e6d9b42e5fedaa07efd5666e66af24955eda4d08efe52",
            solana_address: "DzQYnW6V7tH29NQSZEEA4bY3LjjmFCt1zJ4w8neTdMJx",
            tron_priv_hex: "6dc2b961d2da347aa73b49347256001f98f8d76a3bd2efef8633d607222b9b5e",
            tron_address: "TPL4hPvETozsRu4PncHVHcXKKvZscYzZy4",
        },
        WalletVector {
            index: 5,
            evm_priv_hex: "38431d319b73838d303ae34351092edae0a04ec5c52c6aa9a110d2584ce297e2",
            evm_address: "0x7216Bbf71Ba9d9Ab9089162723EaAe4a95A451CC",
            solana_priv_hex: "d6b5cc4adec7982e1d9a85be7dc89cc538c95e1e3c2659e9ce0568ea48148d1d",
            solana_address: "G5TDpK8cRXvQ4vcEPHuqGUT3xFUPe48F6f1RrGK9o7Np",
            tron_priv_hex: "f97c79fd8f7bf7cf099eff31f208ad8ad26e2987d0da44a781af2acc7a9d0470",
            tron_address: "TJNoQ7tzyRH4Sg2Dfha6vNoPGp3pNzjLQ2",
        },
        WalletVector {
            index: 10,
            evm_priv_hex: "cee21f3aa4777f2e9b40421083945af65dc2aef82caa5f56276f6bc80d04c342",
            evm_address: "0x847b4B5cC4278854bE2b0F979da14C21A70a70e9",
            solana_priv_hex: "76395acc3340292f8c2b9e9a6969f99581827613ed160b0940cb439ba1ca23bb",
            solana_address: "A8d596z9mFM6XzwzK3zhrcnGhBWAjLAvQgqg1Sk837Lm",
            tron_priv_hex: "6bbf58f396c05b776d50e5e0aac399169e76f4e5a89ecf04afabe0ac4ad2b8f4",
            tron_address: "TM9gnsVHN2a1YWxReQhHPbCWzLLXVQZdyr",
        },
    ],
};

pub const ALL_FIXTURES: &[WalletCompatibilityFixture] = &[
    FIXTURE_1_ABANDON_12,
    FIXTURE_2_LEGAL_12,
    FIXTURE_3_LETTER_24,
];

// ============================================================================
// 1. BIP-39 Seed Determinism and Normalization Tests
// ============================================================================

#[test]
fn test_bip39_seed_determinism() {
    for fixture in ALL_FIXTURES {
        let seed = mnemonic_to_seed(fixture.mnemonic.to_string())
            .unwrap_or_else(|e| panic!("Failed to generate seed for {}: {e}", fixture.name));
        let seed_hex = hex::encode(&seed);
        assert_eq!(
            seed_hex, fixture.seed_hex,
            "Mnemonic seed mismatch for fixture {}",
            fixture.name
        );
        assert_eq!(
            seed.len(),
            64,
            "BIP-39 512-bit seed must be exactly 64 bytes"
        );
    }
}

#[test]
fn test_bip39_mnemonic_normalization_and_validation() {
    for fixture in ALL_FIXTURES {
        // Valid phrase check
        assert!(
            validate_mnemonic(fixture.mnemonic.to_string()),
            "Fixture mnemonic must validate: {}",
            fixture.name
        );

        // Whitespace variations (leading, trailing, internal excess whitespace)
        let messy = format!("   {}\n\t  ", fixture.mnemonic.replace(' ', "   \n  "));
        let seed_from_messy = mnemonic_to_seed(messy).expect("BIP-39 parse with irregular spaces");
        assert_eq!(
            hex::encode(seed_from_messy),
            fixture.seed_hex,
            "Seed from irregularly formatted mnemonic must match fixture seed"
        );
    }

    // Negative validation tests
    assert!(!validate_mnemonic("".to_string()));
    assert!(!validate_mnemonic("not a mnemonic phrase".to_string()));
    assert!(!validate_mnemonic(
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon".to_string()
    )); // Invalid checksum word
}

// ============================================================================
// 2. EVM Derivation Compatibility Tests (Path: m/44'/60'/0'/0/{index})
// ============================================================================

#[test]
fn test_evm_derivation_compatibility_all_fixtures() {
    for fixture in ALL_FIXTURES {
        let seed = hex::decode(fixture.seed_hex).expect("valid fixture seed hex");

        for vector in fixture.vectors {
            // Seed -> m/44'/60'/0'/0/index -> private key
            let priv_key = derive_evm_private_key_from_seed(seed.clone(), vector.index)
                .unwrap_or_else(|e| {
                    panic!(
                        "EVM privkey derivation failed for {} index {}: {e}",
                        fixture.name, vector.index
                    )
                });
            assert_eq!(
                priv_key, vector.evm_priv_hex,
                "EVM private key mismatch for {} index {}",
                fixture.name, vector.index
            );

            // Seed -> EVM Address
            let address_from_seed = derive_evm_address_from_seed(seed.clone(), vector.index)
                .unwrap_or_else(|e| {
                    panic!(
                        "EVM address derivation failed for {} index {}: {e}",
                        fixture.name, vector.index
                    )
                });
            assert_eq!(
                address_from_seed, vector.evm_address,
                "EVM address from seed mismatch for {} index {}",
                fixture.name, vector.index
            );

            // Private Key -> EVM Address
            let address_from_priv = derive_evm_address_from_private_key(priv_key)
                .expect("EVM address from private key");
            assert_eq!(
                address_from_priv, vector.evm_address,
                "EVM address from private key mismatch for {} index {}",
                fixture.name, vector.index
            );

            // Verify EIP-55 format
            assert!(
                address_from_seed.starts_with("0x"),
                "EVM address must start with 0x"
            );
            assert_eq!(
                address_from_seed.len(),
                42,
                "EVM address must be 42 characters"
            );
            // Verify checksum capitalization is preserved
            assert_ne!(
                address_from_seed,
                address_from_seed.to_lowercase(),
                "EIP-55 address should have mixed case"
            );
        }
    }
}

// ============================================================================
// 3. Solana Derivation Compatibility Tests (Path: m/44'/501'/{index}'/0')
// ============================================================================

#[test]
fn test_solana_derivation_compatibility_all_fixtures() {
    for fixture in ALL_FIXTURES {
        let seed = hex::decode(fixture.seed_hex).expect("valid fixture seed hex");

        for vector in fixture.vectors {
            // Seed -> m/44'/501'/index'/0' -> Ed25519 private key bytes
            let priv_bytes = derive_solana_private_key_from_seed(seed.clone(), vector.index)
                .unwrap_or_else(|e| {
                    panic!(
                        "Solana privkey derivation failed for {} index {}: {e}",
                        fixture.name, vector.index
                    )
                });
            assert_eq!(
                hex::encode(&priv_bytes),
                vector.solana_priv_hex,
                "Solana private key mismatch for {} index {}",
                fixture.name,
                vector.index
            );
            assert_eq!(priv_bytes.len(), 32, "Solana Ed25519 seed must be 32 bytes");

            // Seed -> Solana Base58 Address
            let address_from_seed = derive_solana_address_from_seed(seed.clone(), vector.index)
                .unwrap_or_else(|e| {
                    panic!(
                        "Solana address derivation failed for {} index {}: {e}",
                        fixture.name, vector.index
                    )
                });
            assert_eq!(
                address_from_seed, vector.solana_address,
                "Solana address from seed mismatch for {} index {}",
                fixture.name, vector.index
            );

            // Private Key Bytes -> Solana Base58 Address
            let address_from_priv = derive_solana_address_from_private_key(priv_bytes)
                .expect("Solana address from private key");
            assert_eq!(
                address_from_priv, vector.solana_address,
                "Solana address from private key mismatch for {} index {}",
                fixture.name, vector.index
            );

            // Verify Base58 decoded length is 32 bytes (Ed25519 public key)
            let decoded = bs58::decode(&address_from_seed)
                .into_vec()
                .expect("valid Solana base58 address");
            assert_eq!(
                decoded.len(),
                32,
                "Solana address must decode to 32 public key bytes"
            );
        }
    }
}

// ============================================================================
// 4. TRON Derivation Compatibility Tests (Path: m/44'/195'/0'/0/{index})
// ============================================================================

#[test]
fn test_tron_derivation_compatibility_all_fixtures() {
    for fixture in ALL_FIXTURES {
        let seed = hex::decode(fixture.seed_hex).expect("valid fixture seed hex");

        for vector in fixture.vectors {
            // Seed -> m/44'/195'/0'/0/index -> secp256k1 private key
            let priv_key = derive_tron_private_key_from_seed(seed.clone(), vector.index)
                .unwrap_or_else(|e| {
                    panic!(
                        "TRON privkey derivation failed for {} index {}: {e}",
                        fixture.name, vector.index
                    )
                });
            assert_eq!(
                priv_key, vector.tron_priv_hex,
                "TRON private key mismatch for {} index {}",
                fixture.name, vector.index
            );

            // Seed -> TRON Base58Check Address
            let address_from_seed = derive_tron_address_from_seed(seed.clone(), vector.index)
                .unwrap_or_else(|e| {
                    panic!(
                        "TRON address derivation failed for {} index {}: {e}",
                        fixture.name, vector.index
                    )
                });
            assert_eq!(
                address_from_seed, vector.tron_address,
                "TRON address from seed mismatch for {} index {}",
                fixture.name, vector.index
            );

            // Private Key -> TRON Base58Check Address
            let address_from_priv = derive_tron_address_from_private_key(priv_key)
                .expect("TRON address from private key");
            assert_eq!(
                address_from_priv, vector.tron_address,
                "TRON address from private key mismatch for {} index {}",
                fixture.name, vector.index
            );

            // Invariants for TRON mainnet addresses
            assert!(
                address_from_seed.starts_with('T'),
                "TRON address must start with 'T'"
            );
            assert_eq!(
                address_from_seed.len(),
                34,
                "TRON Base58Check address must be 34 characters"
            );

            // Checksum verification
            let decoded = bs58::decode(&address_from_seed)
                .into_vec()
                .expect("valid TRON base58");
            assert_eq!(
                decoded.len(),
                25,
                "TRON address payload + checksum = 25 bytes"
            );
            assert_eq!(decoded[0], 0x41, "TRON address prefix byte must be 0x41");

            let payload = &decoded[..21];
            let checksum = &decoded[21..25];
            let expected_checksum = &Sha256::digest(Sha256::digest(payload))[..4];
            assert_eq!(
                checksum, expected_checksum,
                "TRON address checksum must match"
            );
        }
    }
}

// ============================================================================
// 5. Imported Private-Key Compatibility Tests
// ============================================================================

#[test]
fn test_evm_imported_private_key_compatibility() {
    let raw_key = "1ab42cc412b618bdea3a599e3c9bae199ebf030895b039e9db1e30dafb12b727";
    let expected_address = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94";

    // Raw hex
    assert_eq!(
        derive_evm_address_from_private_key(raw_key.to_string()).unwrap(),
        expected_address
    );

    // 0x-prefixed hex
    assert_eq!(
        derive_evm_address_from_private_key(format!("0x{raw_key}")).unwrap(),
        expected_address
    );

    // Uppercase hex
    assert_eq!(
        derive_evm_address_from_private_key(raw_key.to_uppercase()).unwrap(),
        expected_address
    );

    // Invalid private key rejected
    assert!(derive_evm_address_from_private_key("0x123".to_string()).is_err());
    assert!(derive_evm_address_from_private_key("invalid_hex".to_string()).is_err());
}

#[test]
fn test_tron_imported_private_key_compatibility() {
    let raw_key = "b5a4cea271ff424d7c31dc12a3e43e401df7a40d7412a15750f3f0b6b5449a28";
    let expected_address = "TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH";

    // Raw hex
    assert_eq!(
        derive_tron_address_from_private_key(raw_key.to_string()).unwrap(),
        expected_address
    );

    // 0x-prefixed hex
    assert_eq!(
        derive_tron_address_from_private_key(format!("0x{raw_key}")).unwrap(),
        expected_address
    );

    // Uppercase hex
    assert_eq!(
        derive_tron_address_from_private_key(raw_key.to_uppercase()).unwrap(),
        expected_address
    );

    // Invalid private key rejected
    assert!(derive_tron_address_from_private_key("0x123".to_string()).is_err());
}

#[test]
fn test_solana_imported_private_key_compatibility_all_formats() {
    let seed_bytes =
        hex::decode("37df573b3ac4ad5b522e064e25b63ea16bcbe79d449e81a0268d1047948bb445")
            .expect("valid hex");
    let secret_array: [u8; 32] = seed_bytes.as_slice().try_into().unwrap();
    let keypair = Keypair::new_from_array(secret_array);
    let expected_address = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk";

    // 1. Raw 32-byte seed
    let addr = derive_solana_address_from_private_key(seed_bytes.clone()).unwrap();
    assert_eq!(addr, expected_address);

    // 2. 64-char Hex 32-byte seed (without 0x)
    let res = normalize_solana_private_key(hex::encode(&seed_bytes)).unwrap();
    assert_eq!(res.address, expected_address);
    assert_eq!(res.private_key_bytes, seed_bytes);

    // 3. 0x-prefixed Hex 32-byte seed
    let res = normalize_solana_private_key(format!("0x{}", hex::encode(&seed_bytes))).unwrap();
    assert_eq!(res.address, expected_address);

    // 4. Base58 encoded 32-byte seed
    let b58_seed = bs58::encode(&seed_bytes).into_string();
    let res = normalize_solana_private_key(b58_seed).unwrap();
    assert_eq!(res.address, expected_address);
    assert_eq!(res.private_key_bytes, seed_bytes);

    // 5. 64-byte Keypair (Phantom / Solflare standard Base58)
    let b58_keypair = keypair.to_base58_string();
    let res = normalize_solana_private_key(b58_keypair).unwrap();
    assert_eq!(res.address, expected_address);
    assert_eq!(res.private_key_bytes, seed_bytes);

    // 6. 128-char Hex 64-byte keypair
    let hex_keypair = hex::encode(keypair.to_bytes());
    let res = normalize_solana_private_key(hex_keypair).unwrap();
    assert_eq!(res.address, expected_address);
    assert_eq!(res.private_key_bytes, seed_bytes);

    // 7. JSON Byte Array representation (Solana CLI id.json format)
    let json_bytes = format!("{:?}", keypair.to_bytes().to_vec());
    let res = normalize_solana_private_key(json_bytes).unwrap();
    assert_eq!(res.address, expected_address);
    assert_eq!(res.private_key_bytes, seed_bytes);

    // Negative Test: Corrupted 64-byte keypair (tampered public half) MUST be rejected
    let mut tampered = keypair.to_bytes();
    tampered[63] ^= 0xFF; // Corrupt public key part
    let tampered_b58 = bs58::encode(tampered).into_string();
    let err =
        normalize_solana_private_key(tampered_b58).expect_err("Must reject corrupted keypair");
    assert!(
        err.contains("Invalid Solana") || err.contains("keypair"),
        "Unexpected error on tampered keypair: {err}"
    );

    // Negative Test: Empty or garbage input rejected
    assert!(normalize_solana_private_key("".to_string()).is_err());
    assert!(normalize_solana_private_key("not-a-valid-solana-key".to_string()).is_err());
}

// ============================================================================
// 6. Signing Compatibility Tests (EVM, Solana, TRON)
// ============================================================================

#[test]
fn test_evm_eip191_personal_signing_and_recovery() {
    let priv_key = "1ab42cc412b618bdea3a599e3c9bae199ebf030895b039e9db1e30dafb12b727";
    let expected_address = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94";
    let message = "Owllet wallet compatibility verification message";

    // Sign message
    let signature_hex = sign_personal_message(priv_key.to_string(), message.to_string())
        .expect("EIP-191 sign personal message");
    assert!(signature_hex.starts_with("0x"));
    assert_eq!(signature_hex.len(), 132); // 65 bytes in hex = 130 chars + "0x"

    // Verify and recover signer
    let signature: EthersSignature = signature_hex.parse().expect("valid ethers signature");
    let recovered_address = signature
        .recover(message)
        .expect("recover signer from EIP-191");

    assert_eq!(
        format!("{:#x}", recovered_address).to_lowercase(),
        expected_address.to_lowercase(),
        "Recovered EVM signer must match expected address"
    );

    // Verify hex-encoded payload produces same result (EIP-1193 hex payload compatibility)
    let hex_message = format!("0x{}", hex::encode(message.as_bytes()));
    let hex_signature = sign_personal_message(priv_key.to_string(), hex_message)
        .expect("sign EIP-1193 hex message");
    assert_eq!(
        hex_signature, signature_hex,
        "Signing hex-encoded message must match UTF-8 signing"
    );
}

#[test]
fn test_evm_eip712_typed_data_signing_and_recovery() {
    let priv_key = "1ab42cc412b618bdea3a599e3c9bae199ebf030895b039e9db1e30dafb12b727";
    let expected_address = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94";

    let typed_data_json = r#"{
      "types": {
        "EIP712Domain": [
          {"name": "name", "type": "string"},
          {"name": "version", "type": "string"},
          {"name": "chainId", "type": "uint256"},
          {"name": "verifyingContract", "type": "address"}
        ],
        "TransferIntent": [
          {"name": "recipient", "type": "address"},
          {"name": "amount", "type": "uint256"},
          {"name": "nonce", "type": "uint256"}
        ]
      },
      "primaryType": "TransferIntent",
      "domain": {
        "name": "Owllet Core",
        "version": "1.0",
        "chainId": 1,
        "verifyingContract": "0x0000000000000000000000000000000000000001"
      },
      "message": {
        "recipient": "0x6Fac4D18c912343BF86fa7049364Dd4E424Ab9C0",
        "amount": 1000000000000000000,
        "nonce": 42
      }
    }"#;

    let signature_hex = sign_typed_data(priv_key.to_string(), typed_data_json.to_string())
        .expect("sign EIP-712 typed data");
    assert!(signature_hex.starts_with("0x"));
    assert_eq!(signature_hex.len(), 132);

    let signature: EthersSignature = signature_hex.parse().expect("parse typed data signature");
    let typed_data: TypedData =
        serde_json::from_str(typed_data_json).expect("parse typed data struct");
    let recovered_address = signature
        .recover_typed_data(&typed_data)
        .expect("recover typed data signer");

    assert_eq!(
        format!("{:#x}", recovered_address).to_lowercase(),
        expected_address.to_lowercase(),
        "Recovered EIP-712 signer must match expected address"
    );
}

#[test]
fn test_solana_deterministic_message_signing_and_verification() {
    let priv_seed = hex::decode("37df573b3ac4ad5b522e064e25b63ea16bcbe79d449e81a0268d1047948bb445")
        .expect("valid hex");
    let expected_address = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk";
    let message = b"Owllet deterministic Solana test transaction payload".to_vec();

    let signature_b58 =
        sign_solana_message(priv_seed, message.clone()).expect("sign Solana message");

    // 1. Verify using ed25519-dalek VerifyingKey
    let pubkey_bytes = bs58::decode(expected_address)
        .into_vec()
        .expect("decode base58 pubkey");
    let pubkey_array: [u8; 32] = pubkey_bytes.as_slice().try_into().unwrap();
    let verifying_key = VerifyingKey::from_bytes(&pubkey_array).expect("valid verifying key");

    let sig_bytes = bs58::decode(&signature_b58)
        .into_vec()
        .expect("decode signature");
    let dalek_sig = DalekSignature::from_slice(&sig_bytes).expect("valid 64-byte signature");

    assert!(
        verifying_key.verify(&message, &dalek_sig).is_ok(),
        "Solana signature verification with ed25519-dalek must pass"
    );

    // 2. Determinism check: verify signature is reproducible across runs
    let priv_seed_2 =
        hex::decode("37df573b3ac4ad5b522e064e25b63ea16bcbe79d449e81a0268d1047948bb445").unwrap();
    let signature_b58_2 = sign_solana_message(priv_seed_2, message).unwrap();
    assert_eq!(
        signature_b58, signature_b58_2,
        "Solana signatures must be strictly deterministic"
    );
}

#[test]
fn test_tron_raw_hash_signing_and_recovery() {
    let priv_key = "b5a4cea271ff424d7c31dc12a3e43e401df7a40d7412a15750f3f0b6b5449a28";
    let expected_address = "TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH";

    // Simulate 32-byte TRON raw transaction hash
    let raw_hash_bytes = Sha256::digest(b"Owllet TRON transaction payload raw data");
    let raw_hash_hex = hex::encode(raw_hash_bytes);

    let signature_hex =
        sign_tron_raw_hash(priv_key.to_string(), raw_hash_hex.clone()).expect("sign TRON raw hash");
    let sig_clean = signature_hex
        .strip_prefix("0x")
        .expect("0x signature prefix");
    assert_eq!(sig_clean.len(), 130); // 64 bytes r,s + 1 byte v (0 or 1)

    // Parse compact signature and recovery id
    let compact_bytes = hex::decode(&sig_clean[..128]).expect("compact signature");
    let v_byte = u8::from_str_radix(&sig_clean[128..130], 16).expect("recovery id");
    assert!(v_byte <= 1, "TRON recovery id must be 0 or 1 (not +27)");

    let recovery_id = RecoveryId::from_u8_masked(v_byte);
    let recoverable_sig =
        RecoverableSignature::from_compact(&compact_bytes, recovery_id).expect("recoverable sig");

    let msg = Message::from_digest(raw_hash_bytes.into());
    let recovered_pubkey = Secp256k1::new()
        .recover_ecdsa(msg, &recoverable_sig)
        .expect("recover secp256k1 public key");

    // Derive TRON address from recovered public key and assert exact match
    let uncompressed = recovered_pubkey.serialize_uncompressed();
    let hash = Keccak256::digest(&uncompressed[1..]);
    let mut payload = Vec::with_capacity(25);
    payload.push(0x41);
    payload.extend_from_slice(&hash[12..]);
    let checksum = Sha256::digest(Sha256::digest(&payload));
    payload.extend_from_slice(&checksum[..4]);
    let recovered_tron_address = bs58::encode(payload).into_string();

    assert_eq!(
        recovered_tron_address, expected_address,
        "Recovered TRON address must match expected address"
    );
}
