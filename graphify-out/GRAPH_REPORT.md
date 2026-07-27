# Graph Report - .  (2026-07-27)

## Corpus Check
- 47 files · ~429,765 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 236 nodes · 320 edges · 50 communities detected
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

## God Nodes (most connected - your core abstractions)
1. `pde_ffi_dispatcher_primary_impl()` - 22 edges
2. `derive_solana_private_key_from_seed()` - 10 edges
3. `MainActivity` - 9 edges
4. `fixture_seed()` - 6 edges
5. `Create()` - 6 edges
6. `Destroy()` - 6 edges
7. `AppDelegate` - 5 edges
8. `solana_keypair_from_bytes()` - 5 edges
9. `solana_message_signature_verifies()` - 5 edges
10. `main()` - 5 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities

### Community 0 - "Community 0"
Cohesion: 0.11
Nodes (35): derive_evm_address_from_private_key(), derive_evm_address_from_seed(), derive_evm_private_key_from_seed(), derive_secp256k1_private_key(), derive_solana_address_from_private_key(), derive_solana_address_from_seed(), derive_solana_private_key_from_seed(), derive_tron_address_from_private_key() (+27 more)

### Community 1 - "Community 1"
Cohesion: 0.2
Nodes (24): pde_ffi_dispatcher_primary_impl(), pde_ffi_dispatcher_sync_impl(), wire__crate__api__argon2__derive_passcode_hash_argon2_impl(), wire__crate__api__bip32__derive_evm_address_from_private_key_impl(), wire__crate__api__bip32__derive_evm_address_from_seed_impl(), wire__crate__api__bip32__derive_evm_private_key_from_seed_impl(), wire__crate__api__bip32__derive_solana_address_from_private_key_impl(), wire__crate__api__bip32__derive_solana_address_from_seed_impl() (+16 more)

### Community 2 - "Community 2"
Cohesion: 0.17
Nodes (16): Create(), Destroy(), EnableFullDpiSupportIfAvailable(), GetClientArea(), GetThisFromHandle(), GetWindowClass(), MessageHandler(), OnCreate() (+8 more)

### Community 3 - "Community 3"
Cohesion: 0.17
Nodes (4): crate::api::bip32::SolanaPrivateKeyImport, i32, String, Vec<u8>

### Community 4 - "Community 4"
Cohesion: 0.2
Nodes (1): MainActivity

### Community 5 - "Community 5"
Cohesion: 0.52
Nodes (6): sign_digest(), sign_digest_inner(), sign_digest_with_recovery_id(), sign_personal_message(), sign_typed_data(), signs_typed_data_and_recovers_expected_address()

### Community 6 - "Community 6"
Cohesion: 0.33
Nodes (2): digest_files(), sha256_git_blob()

### Community 7 - "Community 7"
Cohesion: 0.62
Nodes (6): download_artifact(), fetch_artifacts(), gh_json(), main(), regenerate_manifest(), run()

### Community 8 - "Community 8"
Cohesion: 0.47
Nodes (2): AppDelegate, FlutterAppDelegate

### Community 9 - "Community 9"
Cohesion: 0.4
Nodes (5): build_and_sign_solana_transaction(), parse_pubkey(), RelayAccountMeta, RelayInstruction, RelayLookupTable

### Community 10 - "Community 10"
Cohesion: 0.67
Nodes (5): ensure_commit_available(), is_non_runtime_root(), is_rust_ffi_bridge_path(), main(), rust_ffi_bridge_hashes()

### Community 11 - "Community 11"
Cohesion: 0.67
Nodes (5): decode_base64_text(), has_expected_pem_block(), main(), normalize_text(), parse_key_material()

### Community 12 - "Community 12"
Cohesion: 0.33
Nodes (1): FlutterWindow()

### Community 13 - "Community 13"
Cohesion: 0.4
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 14 - "Community 14"
Cohesion: 0.4
Nodes (2): NotificationService, UNNotificationServiceExtension

### Community 15 - "Community 15"
Cohesion: 0.5
Nodes (0): 

### Community 16 - "Community 16"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 17 - "Community 17"
Cohesion: 0.5
Nodes (2): RunnerTests, XCTestCase

### Community 18 - "Community 18"
Cohesion: 0.5
Nodes (0): 

### Community 19 - "Community 19"
Cohesion: 0.67
Nodes (2): GetCommandLineArguments(), Utf8FromUtf16()

### Community 20 - "Community 20"
Cohesion: 0.67
Nodes (1): bool

### Community 21 - "Community 21"
Cohesion: 0.67
Nodes (1): u32

### Community 22 - "Community 22"
Cohesion: 0.67
Nodes (1): u8

### Community 23 - "Community 23"
Cohesion: 0.67
Nodes (1): ()

### Community 24 - "Community 24"
Cohesion: 0.67
Nodes (0): 

### Community 25 - "Community 25"
Cohesion: 1.0
Nodes (0): 

### Community 26 - "Community 26"
Cohesion: 1.0
Nodes (0): 

### Community 27 - "Community 27"
Cohesion: 1.0
Nodes (0): 

### Community 28 - "Community 28"
Cohesion: 1.0
Nodes (0): 

### Community 29 - "Community 29"
Cohesion: 1.0
Nodes (0): 

### Community 30 - "Community 30"
Cohesion: 1.0
Nodes (0): 

### Community 31 - "Community 31"
Cohesion: 1.0
Nodes (0): 

### Community 32 - "Community 32"
Cohesion: 1.0
Nodes (0): 

### Community 33 - "Community 33"
Cohesion: 1.0
Nodes (0): 

### Community 34 - "Community 34"
Cohesion: 1.0
Nodes (0): 

### Community 35 - "Community 35"
Cohesion: 1.0
Nodes (0): 

### Community 36 - "Community 36"
Cohesion: 1.0
Nodes (0): 

### Community 37 - "Community 37"
Cohesion: 1.0
Nodes (0): 

### Community 38 - "Community 38"
Cohesion: 1.0
Nodes (0): 

### Community 39 - "Community 39"
Cohesion: 1.0
Nodes (0): 

### Community 40 - "Community 40"
Cohesion: 1.0
Nodes (0): 

### Community 41 - "Community 41"
Cohesion: 1.0
Nodes (0): 

### Community 42 - "Community 42"
Cohesion: 1.0
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

## Knowledge Gaps
- **5 isolated node(s):** `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry`, `RelayInstruction`, `RelayAccountMeta`, `RelayLookupTable`
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 25`** (2 nodes): `derive_passcode_hash_argon2()`, `argon2.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 26`** (2 nodes): `Resolve-Symlinks()`, `resolve_symlinks.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 27`** (2 nodes): `shorebird_release_manifest.py`, `main()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 28`** (2 nodes): `write_shorebird_yaml.py`, `main()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 29`** (2 nodes): `RegisterPlugins()`, `generated_plugin_registrant.cc`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 30`** (2 nodes): `wWinMain()`, `main.cpp`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 31`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 32`** (1 nodes): `settings.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 33`** (1 nodes): `GeneratedPluginRegistrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 34`** (1 nodes): `Runner-Bridging-Header.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 35`** (1 nodes): `lib.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 36`** (1 nodes): `mod.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 37`** (1 nodes): `dummy_file.c`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 38`** (1 nodes): `dummy_file.c`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 39`** (1 nodes): `bump_mobile_version.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 40`** (1 nodes): `create_android_keystore.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 41`** (1 nodes): `encode_android_keystore.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 42`** (1 nodes): `encode_google_services_json.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 43`** (1 nodes): `generate_shorebird_patch_keys.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 44`** (1 nodes): `get_android_fingerprints.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 45`** (1 nodes): `shorebird_patch_local.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 46`** (1 nodes): `generated_plugin_registrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 47`** (1 nodes): `resource.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 48`** (1 nodes): `utils.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 49`** (1 nodes): `win32_window.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `i32` connect `Community 3` to `Community 1`?**
  _High betweenness centrality (0.002) - this node is a cross-community bridge._
- **What connects `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry`, `RelayInstruction` to the rest of the system?**
  _5 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.11 - nodes in this community are weakly interconnected._