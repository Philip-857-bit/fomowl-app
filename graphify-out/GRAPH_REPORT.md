# Graph Report - .  (2026-10-08)

## Corpus Check
- 68 files · ~471,782 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 363 nodes · 460 edges · 72 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 59|Community 59]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 63|Community 63]]
- [[_COMMUNITY_Community 64|Community 64]]
- [[_COMMUNITY_Community 65|Community 65]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 67|Community 67]]
- [[_COMMUNITY_Community 68|Community 68]]
- [[_COMMUNITY_Community 69|Community 69]]
- [[_COMMUNITY_Community 70|Community 70]]
- [[_COMMUNITY_Community 71|Community 71]]

## God Nodes (most connected - your core abstractions)
1. `pde_ffi_dispatcher_primary_impl()` - 25 edges
2. `MainActivity` - 10 edges
3. `sign_legacy_evm_transaction()` - 6 edges
4. `eip155_request()` - 6 edges
5. `fixture_seed()` - 6 edges
6. `Create()` - 6 edges
7. `Destroy()` - 6 edges
8. `AppDelegate` - 5 edges
9. `sign_serialized_solana_transaction()` - 5 edges
10. `unsigned_legacy()` - 5 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities

### Community 0 - "Community 0"
Cohesion: 0.18
Nodes (27): pde_ffi_dispatcher_primary_impl(), pde_ffi_dispatcher_sync_impl(), wire__crate__api__argon2__derive_passcode_hash_argon2_impl(), wire__crate__api__bip32__derive_evm_address_from_private_key_impl(), wire__crate__api__bip32__derive_evm_address_from_seed_impl(), wire__crate__api__bip32__derive_evm_private_key_from_seed_impl(), wire__crate__api__bip32__derive_solana_address_from_private_key_impl(), wire__crate__api__bip32__derive_solana_address_from_seed_impl() (+19 more)

### Community 1 - "Community 1"
Cohesion: 0.14
Nodes (18): derive_evm_private_key_from_seed(), derive_solana_address_from_seed(), derive_solana_private_key_from_seed(), derive_tron_private_key_from_seed(), derive_wallet_from_seed(), derives_known_family_addresses_from_seed(), fixture_seed(), normalize_solana_private_key() (+10 more)

### Community 2 - "Community 2"
Cohesion: 0.17
Nodes (16): Create(), Destroy(), EnableFullDpiSupportIfAvailable(), GetClientArea(), GetThisFromHandle(), GetWindowClass(), MessageHandler(), OnCreate() (+8 more)

### Community 3 - "Community 3"
Cohesion: 0.13
Nodes (5): crate::api::bip32::SolanaPrivateKeyImport, i32, Option<String>, String, Vec<u8>

### Community 4 - "Community 4"
Cohesion: 0.13
Nodes (2): WalletCompatibilityFixture, WalletVector

### Community 5 - "Community 5"
Cohesion: 0.26
Nodes (13): build_and_sign_solana_transaction(), builder_rejects_instruction_plans_requiring_unavailable_signers(), builds_normalized_v0_instruction_payload_and_verifies_signature(), parse_pubkey(), preserves_extra_signature_slot(), rejects_signature_count_exceeding_required_signer_metadata(), rejects_wrong_expected_signer(), sign_serialized_solana_transaction() (+5 more)

### Community 6 - "Community 6"
Cohesion: 0.28
Nodes (12): eip155_request(), EvmTransactionFee, EvmTransactionRequest, LegacyEvmTransactionRequest, sign_evm_transaction(), sign_legacy_evm_transaction(), SignedEvmTransaction, test_chain_id_replay_protection() (+4 more)

### Community 7 - "Community 7"
Cohesion: 0.18
Nodes (1): MainActivity

### Community 8 - "Community 8"
Cohesion: 0.29
Nodes (6): generate_mnemonic(), generate_mnemonic_from_entropy(), mnemonic_to_seed(), test_generate_mnemonic_structure(), test_known_mnemonic_to_seed(), test_mnemonic_to_seed_error_format()

### Community 9 - "Community 9"
Cohesion: 0.31
Nodes (4): known_seed(), test_known_evm_derivation_index_0(), test_known_solana_derivation_index_0(), test_known_tron_derivation_index_0()

### Community 10 - "Community 10"
Cohesion: 0.39
Nodes (8): general_adapter_preserves_official_legacy_fixture(), general_adapter_rejects_ambiguous_fee_policy(), sign_evm_transaction(), sign_legacy_evm_transaction(), test_adapter_invalid_address(), test_adapter_invalid_gas_price(), test_adapter_invalid_key(), test_adapter_official_eip155_vector()

### Community 11 - "Community 11"
Cohesion: 0.48
Nodes (4): Ed25519Slip10Key, slip10_ed25519_derive_child(), slip10_ed25519_master_key(), slip10_key_from_hmac()

### Community 12 - "Community 12"
Cohesion: 0.57
Nodes (5): preserves_extra_signature_slot(), rejects_wrong_expected_signer(), sign_serialized_solana_transaction(), signs_legacy_one_sig_round_trip(), unsigned_legacy()

### Community 13 - "Community 13"
Cohesion: 0.33
Nodes (2): digest_files(), sha256_git_blob()

### Community 14 - "Community 14"
Cohesion: 0.62
Nodes (6): download_artifact(), fetch_artifacts(), gh_json(), main(), regenerate_manifest(), run()

### Community 15 - "Community 15"
Cohesion: 0.47
Nodes (2): AppDelegate, FlutterAppDelegate

### Community 16 - "Community 16"
Cohesion: 0.6
Nodes (5): derive_evm_address_from_private_key(), derive_evm_address_from_seed(), derive_evm_private_key_from_seed(), evm_address_from_public_key(), to_eip55_address()

### Community 17 - "Community 17"
Cohesion: 0.33
Nodes (0):

### Community 18 - "Community 18"
Cohesion: 0.33
Nodes (0):

### Community 19 - "Community 19"
Cohesion: 0.47
Nodes (4): personal_sign_decodes_eip_1193_hex_data_before_signing(), sign_personal_message(), sign_typed_data(), signs_typed_data_and_recovers_expected_address()

### Community 20 - "Community 20"
Cohesion: 0.67
Nodes (5): ensure_commit_available(), is_non_runtime_root(), is_rust_ffi_bridge_path(), main(), rust_ffi_bridge_hashes()

### Community 21 - "Community 21"
Cohesion: 0.67
Nodes (5): decode_base64_text(), has_expected_pem_block(), main(), normalize_text(), parse_key_material()

### Community 22 - "Community 22"
Cohesion: 0.33
Nodes (1): FlutterWindow()

### Community 23 - "Community 23"
Cohesion: 0.4
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 24 - "Community 24"
Cohesion: 0.4
Nodes (2): NotificationService, UNNotificationServiceExtension

### Community 25 - "Community 25"
Cohesion: 0.7
Nodes (4): derive_solana_address_from_private_key(), derive_solana_address_from_seed(), derive_solana_private_key_from_seed(), solana_keypair_from_bytes()

### Community 26 - "Community 26"
Cohesion: 0.7
Nodes (4): derive_tron_address_from_private_key(), derive_tron_address_from_seed(), derive_tron_private_key_from_seed(), tron_address_from_public_key()

### Community 27 - "Community 27"
Cohesion: 0.7
Nodes (4): contract_creation_preserves_data_and_empty_destination_for_both_fee_types(), eip1559_matches_independent_web3dart_fixture_and_recovers_sender(), fixture(), rejects_invalid_fee_policy_and_invalid_call_destination()

### Community 28 - "Community 28"
Cohesion: 0.5
Nodes (0):

### Community 29 - "Community 29"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 30 - "Community 30"
Cohesion: 0.5
Nodes (2): RunnerTests, XCTestCase

### Community 31 - "Community 31"
Cohesion: 0.5
Nodes (0):

### Community 32 - "Community 32"
Cohesion: 0.67
Nodes (2): decode_personal_sign_payload(), sign_personal_message()

### Community 33 - "Community 33"
Cohesion: 0.83
Nodes (3): sign_digest(), sign_digest_inner(), sign_digest_with_recovery_id()

### Community 34 - "Community 34"
Cohesion: 0.5
Nodes (0):

### Community 35 - "Community 35"
Cohesion: 0.67
Nodes (2): GetCommandLineArguments(), Utf8FromUtf16()

### Community 36 - "Community 36"
Cohesion: 0.67
Nodes (0):

### Community 37 - "Community 37"
Cohesion: 0.67
Nodes (1): bool

### Community 38 - "Community 38"
Cohesion: 0.67
Nodes (1): u32

### Community 39 - "Community 39"
Cohesion: 0.67
Nodes (1): u64

### Community 40 - "Community 40"
Cohesion: 0.67
Nodes (1): u8

### Community 41 - "Community 41"
Cohesion: 0.67
Nodes (1): ()

### Community 42 - "Community 42"
Cohesion: 0.67
Nodes (0):

### Community 43 - "Community 43"
Cohesion: 1.0
Nodes (0):

### Community 44 - "Community 44"
Cohesion: 1.0
Nodes (0):

### Community 45 - "Community 45"
Cohesion: 1.0
Nodes (0):

### Community 46 - "Community 46"
Cohesion: 1.0
Nodes (0):

### Community 47 - "Community 47"
Cohesion: 1.0
Nodes (0):

### Community 48 - "Community 48"
Cohesion: 1.0
Nodes (0):

### Community 49 - "Community 49"
Cohesion: 1.0
Nodes (0):

### Community 50 - "Community 50"
Cohesion: 1.0
Nodes (0):

### Community 51 - "Community 51"
Cohesion: 1.0
Nodes (0):

### Community 52 - "Community 52"
Cohesion: 1.0
Nodes (0):

### Community 53 - "Community 53"
Cohesion: 1.0
Nodes (0):

### Community 54 - "Community 54"
Cohesion: 1.0
Nodes (0):

### Community 55 - "Community 55"
Cohesion: 1.0
Nodes (0):

### Community 56 - "Community 56"
Cohesion: 1.0
Nodes (0):

### Community 57 - "Community 57"
Cohesion: 1.0
Nodes (0):

### Community 58 - "Community 58"
Cohesion: 1.0
Nodes (0):

### Community 59 - "Community 59"
Cohesion: 1.0
Nodes (0):

### Community 60 - "Community 60"
Cohesion: 1.0
Nodes (0):

### Community 61 - "Community 61"
Cohesion: 1.0
Nodes (0):

### Community 62 - "Community 62"
Cohesion: 1.0
Nodes (0):

### Community 63 - "Community 63"
Cohesion: 1.0
Nodes (0):

### Community 64 - "Community 64"
Cohesion: 1.0
Nodes (0):

### Community 65 - "Community 65"
Cohesion: 1.0
Nodes (0):

### Community 66 - "Community 66"
Cohesion: 1.0
Nodes (0):

### Community 67 - "Community 67"
Cohesion: 1.0
Nodes (0):

### Community 68 - "Community 68"
Cohesion: 1.0
Nodes (0):

### Community 69 - "Community 69"
Cohesion: 1.0
Nodes (0):

### Community 70 - "Community 70"
Cohesion: 1.0
Nodes (0):

### Community 71 - "Community 71"
Cohesion: 1.0
Nodes (0):

## Knowledge Gaps
- **11 isolated node(s):** `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry`, `LegacyEvmTransactionRequest`, `SignedEvmTransaction`, `EvmTransactionFee` (+6 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 43`** (2 nodes): `solana.rs`, `sign_solana_message()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 44`** (2 nodes): `tron.rs`, `sign_tron_raw_hash()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 45`** (2 nodes): `derive_passcode_hash_argon2()`, `argon2.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 46`** (2 nodes): `Resolve-Symlinks()`, `resolve_symlinks.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 47`** (2 nodes): `shorebird_release_manifest.py`, `main()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 48`** (2 nodes): `write_shorebird_yaml.py`, `main()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 49`** (2 nodes): `RegisterPlugins()`, `generated_plugin_registrant.cc`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 50`** (2 nodes): `wWinMain()`, `main.cpp`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 51`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 52`** (1 nodes): `settings.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 53`** (1 nodes): `GeneratedPluginRegistrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 54`** (1 nodes): `Runner-Bridging-Header.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 55`** (1 nodes): `lib.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 56`** (1 nodes): `mod.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 57`** (1 nodes): `lib.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 58`** (1 nodes): `mod.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 59`** (1 nodes): `dummy_file.c`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 60`** (1 nodes): `dummy_file.c`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 61`** (1 nodes): `bump_mobile_version.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 62`** (1 nodes): `create_android_keystore.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 63`** (1 nodes): `encode_android_keystore.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 64`** (1 nodes): `encode_google_services_json.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 65`** (1 nodes): `generate_shorebird_patch_keys.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 66`** (1 nodes): `get_android_fingerprints.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 67`** (1 nodes): `shorebird_patch_local.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 68`** (1 nodes): `generated_plugin_registrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 69`** (1 nodes): `resource.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 70`** (1 nodes): `utils.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 71`** (1 nodes): `win32_window.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `i32` connect `Community 3` to `Community 0`?**
  _High betweenness centrality (0.001) - this node is a cross-community bridge._
- **What connects `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry`, `LegacyEvmTransactionRequest` to the rest of the system?**
  _11 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.14 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.13 - nodes in this community are weakly interconnected._
- **Should `Community 4` be split into smaller, more focused modules?**
  _Cohesion score 0.13 - nodes in this community are weakly interconnected._
