# Transaction confirmation and receipt details

Confirmations retain the amount, destination, network, network fee and total as primary information. Protocol mechanics use the shared, collapsed `AdvancedTransactionDetails` presentation component. Bitcoin confirmation continues to use the validated immutable Rust plan.

- Bitcoin: input format, fee rate, estimated vbytes and RBF come from the plan. History exposes transaction ID, confirmations and block height; replacement-plan mechanics appear only when that plan is available.
- EVM: confirmation shows the selected typed fee quote. Receipt nonce and submitted gas caps require the matching protected outbound record. Actual execution cost requires a matching confirmed receipt and is `gasUsed * effectiveGasPrice`; separate rollup data charges are not inferred.
- Solana: confirmation labels the existing fee estimate explicitly. Receipt fees and compute consumption come from bound backend facts. Priority fees appear only when explicitly provided, never by subtracting a presumed base fee.
- TRON: confirmation leaves unknown fees network-calculated. Receipt energy, bandwidth and burned fees appear only when returned. The optional energy fee limit is not represented as a cap on bandwidth charges.

Token totals keep asset and native fee units separate. Integer transfer amounts, rather than a display-only amount argument, determine confirmation amounts. Missing fees remain unavailable rather than becoming zero.

The optional Solana/TRON receipt fields are supplied by backend commit `bc9e3dd680d66db1fe04b1cd6adfd75824ac6b17` (draft PR #60). Older responses without these fields remain readable. Fetches bind network and transaction identity, have bounded response sizes/timeouts and never retry broadcasts. Late receipt responses cannot replace a newly opened transaction.

This change does not alter signing, custody, SDK pins, transaction execution, replacement policies, submission reservations or production rollout. No secret material, raw transactions, signatures or calldata is exposed in advanced details.
