# Internal release and consumption

This package is proprietary. `publish = false` disables registry publication,
including crates.io. The release helper creates local artifacts and never uploads.
No private registry is configured by this release.

## Use from another Rust product

During development, use a path dependency:

```toml
[dependencies]
owllet-core = { path = "../owllet-core", version = "0.1.0", default-features = false, features = ["evm", "vault"] }
```

For internal distribution, download the verified `.crate` from your controlled
artifact store, check `SHA256SUMS`, and unpack it into your product's vendor
directory. The dependency path then points to `vendor/owllet-core-0.1.0`.
Alternatively, use an authorized private Git repository with an exact commit:

```toml
owllet-core = { git = "<PRIVATE_REPOSITORY_URL>", rev = "<EXACT_RELEASE_COMMIT>", default-features = false, features = ["evm", "solana", "tron", "vault"] }
```

Commit each product's `Cargo.lock` and build with `--locked`. Language bindings
are separate host adapters: Flutter uses FRB; a browser product still needs a
validated WASM/JavaScript adapter. Resource-constrained `no_std` devices are not
certified. The native consumer proves Rust reuse; it is not a desktop wallet UI.

## Create a verified local release

From the repository root with Python 3.11+ and Cargo installed:

```sh
# Only when intentionally updating dependency versions or the crate version:
python scripts/package_internal_core.py --inventory-only
# Commit changes, then build the proprietary package from a clean repository:
python scripts/package_internal_core.py
```

The helper verifies the internal publication policy and dependency inventory,
then uses Cargo to package and compile the extracted crate with all features.
It writes the `.crate`, `SHA256SUMS`, and `release.json` into
`target/internal-release/0.1.0/` inside this crate. The manifest records the source
commit, compiler and artifact hash. Existing artifacts with different content
cannot be overwritten under the same version; increment the version instead.

`DEPENDENCY_LICENSES.json` records all-feature runtime/build dependency license
metadata from Cargo. Dev-only dependencies are excluded. Third-party licensing
and notices remain governed by those dependencies' own terms.

## Validation before a release

Run core formatting, Clippy and tests, plus selected feature configurations.
Rebuild the native adapter before Flutter FFI tests. Run the independent consumer:

```sh
cargo run --locked --manifest-path rust/consumers/owllet-core-smoke/Cargo.toml -- --self-test
```

The consumer uses public offline fixtures only and makes no RPC calls. Hosts own
secure entropy, protected storage, user authentication, approved transaction
fields, permissions and network transport. No provider credentials belong here.
