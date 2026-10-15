# Native Bitcoin Bridge

Bitcoin is available only in Bridge, never ordinary Swap or Limit. This
implementation uses Relay's live chain catalog and a committed route quote;
catalog membership alone does not make a route executable. Mainnet is supported
where runtime policy, wallet support, user preference and the actual provider
route permit it. Testnet4 remains a wallet-testing network, not a bridge route.

## Approval and custody

The backend binds the quote to the exact input amount, origin and destination
assets, sender, recipient, owned refund address, minimum output and deadlines.
Bitcoin-origin quotes use a strict, single-use deposit address. Provider PSBTs
are discarded. The device builds its own transaction through Owllet Core,
validates the immutable plan, shows destination and refund details, authenticates
through the existing unlock helper and signs inside opaque Rust custody.

The short quote-approval deadline and the provider's order deadline are distinct.
Neither changes the approved network fee or authorizes a later automatic payment.
Counter-chain-to-Bitcoin routes retain the existing supported chain executor and
require review of the Bitcoin recipient and minimum received amount.

## Submission and recovery

A protected, wallet-scoped journal records the quote, signed transaction ID and
attempt nonce before broadcast. One unresolved Bitcoin bridge blocks another
funding attempt, including after restart or a newly fetched quote. A timeout,
missing transaction, rate limit or provider outage never releases that guard.
Only exact, recognized pre-provider rejection evidence can release a live attempt.
There is no automatic rebroadcast or re-funding.

Bitcoin submission, Bitcoin confirmation and destination delivery are separate
states. Read-only recovery observes the original transaction or a Core-verified
RBF replacement preserving the exact deposit amount and recipient. Positive
Bitcoin confirmation plus Relay's matching final delivery or refund result can
resolve the business journal. Refund wording explicitly attributes the result
to Relay; it does not promise a particular refund chain or assert a wallet credit.
Common Bitcoin input reservations are reconciled separately and never cleared
by bridge-provider status. Completed request IDs remain protected throughout
the provider order window.

## Limits and validation evidence

No production policy is enabled by this change. No seed, XPUB, private key or
signing authority is transmitted to the provider or backend. Amounts at the
funding boundary are integer units; network fees remain Core-planned.

Captured public API fixtures and mocked failure tests cover both bridge
directions. Read-only live quote probes do not prove settlement. No funded
bridge, production transaction or physical-device bridge test is claimed.
Provider final-delivery/refund reporting remains a trust boundary, consistent
with the existing bridge architecture. Bitcoin block times and destination
delivery are variable; Submitted is not a promise of eventual confirmation.
