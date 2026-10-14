# Bitcoin Breet cash-out host

Native Bitcoin cash-out is scoped to the OwlletPay host, an admitted mainnet
seed wallet and an enabled user Bitcoin preference. The frontend also requires
the host's explicit `requestBitcoinCashout` capability and an available live
Breet sell asset. Native BTC never uses Centiiv or an automatic stablecoin swap.

The host accepts only an operation reference from the mini-app. It obtains the
exact destination, integer satoshis and funding deadline from the authenticated
backend plan using a wallet session. The existing immutable Bitcoin confirmation
screen validates the Rust plan before approval. Authentication uses the existing
safe unlock helper; signing and broadcast remain in the established opaque Rust
custody and verified transaction paths.

The reference guard is persisted before broadcast. An accepted submission and an
unknown outcome both prevent another payment. Only a recognized pre-provider
rejection from that live attempt may remove its guard. Restart recovery performs
chain observation and idempotent profile-JWT acknowledgement, never signing or
rebroadcast. Exact positive confirmation plus successful acknowledgement permits
reconciliation. A funding deadline does not release an uncertain submission.

For a confirmed RBF replacement, protected receipts retain the winning immutable
plan and signed transaction. Rust revalidates these before producing a scoped
payment-evidence capability. Cash-out reconciliation additionally checks the
original wallet/txid, network, single destination and exact amount, then requires
a fresh positive winning-transaction observation and backend acknowledgement.
Old display-only receipts yield no payment evidence. Receipt retention is bounded;
missing evidence keeps the payment guard rather than authorizing another send.
The original callback txid remains separate from the observed winning txid.

BTC amounts shown by the frontend are formatted from integer satoshi strings.
Its legacy withdrawal input remains a fiat/USD budget, not a native BTC amount.
Fiat payout is estimated: Breet's verified provider events determine the final
conversion and bank settlement. BTC submission is never reported as fiat payout
success. Unknown submission is explicitly retained and must not be resent.

All development tests use unfunded fixtures or mocked responses. No live Breet
Bitcoin deposit, mainnet funding or bank payout has been validated by this work.
Production rollout, the Owllet Core pin and other-chain execution are unchanged.
