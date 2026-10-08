# Independent native consumer

A small native Rust CLI that consumes only the public `owllet-core` APIs.
It has its own manifest and lockfile and no Flutter/FRB/backend dependencies.
It proves a second host can share derivation, calldata, signing, authenticated
vaults, account locking, and Solana transaction compilation/serialization.

From the repository root:

```sh
cargo run --locked --manifest-path rust/consumers/owllet-core-smoke/Cargo.toml -- --self-test
```

The CLI uses **public test fixtures** and makes no RPC calls or broadcasts.
Never send funds to the fixture accounts or reuse fixture keys/nonces in products.
Real hosts provide protected storage, authentication, secure entropy, permissions,
network transport, and lifecycle management around the same core APIs.

This is a native integration proof, not a desktop wallet UI or a WASM/device
certification. CI compiles and runs the proof on Windows and Linux.
