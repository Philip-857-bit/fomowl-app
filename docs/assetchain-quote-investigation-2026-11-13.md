# Asset Chain quote and request investigation

## Evidence

The supplied staging trace shows a request for 100 native RWA to official USDT, `/api/swap/price`, returning HTTP 400 in 0.603 seconds with `Insufficient liquidity` / `No liquidity pool`. Native RWA resolves to the configured WRWA address for pool quoting. The old handler reached this response after finding a pool but failing to obtain a positive quoter simulation. It swallowed the distinction between a contract simulation failure and an upstream RPC failure. The trace does not prove that increasing the amount would help, nor that the wallet needed more funds. Price discovery does not require ownership of the sell asset.

Live public RPC, explorer API, and configured public backend probes returned 403/1010 from the investigation environment. Therefore live WRWA/USDT liquidity, the reason for the historical quoter failure, and a successful RWA/USDT trade are not established. XRWA is a separate token; this change never substitutes it for RWA or WRWA.

## Changes

- Shared app error classification distinguishes unavailable routes from explicit minimum-amount errors and incomplete responses. `No liquidity pool` no longer tells the user to enter a larger amount.
- Asset Chain uses one backend request with an 18-second transport timeout and a 22-second screen deadline. It does not start a second direct local pool scan after backend failure. The apparent Relay fallback also called the same backend provider, so it is skipped for Asset Chain.
- Backend discovery and simulation run at most four fee tiers concurrently. No pool, unsuccessful pool simulation, and unreliable RPC responses produce distinct 404, 422, and 503 responses. A 16-second absolute backend deadline prevents unbounded quote work. Price quotes remain valid when optional gas simulation fails for an unfunded wallet; firm transaction checks remain strict.
- Backend diagnostic logs record the affected pool, tokens, fee tier, amount, and failure category without RPC URLs or credentials. Deploy the backend changes before evaluating the updated errors in staging.

## Rate-limit log

The separate supplied log covers about 55 seconds and contains 157 unique HTTP responses, including 95 global rate-limit rejections. NFT reads account for 55 of those rejections. Burst connection requests were collateral to the global quota, not the separate five-challenges-per-minute Burst limit.

The configured requests-per-second value was passed to a library method that expects seconds per request. Backend wiring now uses an explicit replenishment period; configured 2 requests/second means one token every 500 ms rather than every two seconds. Numeric quota/burst values and proxy trust remain unchanged. Existing logs cannot establish the rejected requests' IP keys or whether users shared a proxy quota. See the sibling backend's `docs/rate-limiting-2026-11-13.md` for the full sanitized breakdown.

## Splash layout

The splash wordmark grows to the tagline's measured width, recalculates after fonts load, and scales down to fit narrow screens. The unlock-screen logo remains unchanged.

## Verification and rollout

147 focused Flutter tests passed across swap services, error classification, Asset Chain quote failures, and splash layout. Affected-source static analysis passed. The backend's actual market helper passed 10 RPC fixture tests, its rate policy passed two tests, and the integrated backend passed `cargo check --tests -q`. Both knowledge graphs were rebuilt and whitespace checks passed.

Deploy the backend quote/rate-policy changes and release the updated Flutter app to apply the fixes. No deployment, live swap, or other financial transaction was performed. Live WRWA/USDT execution remains unverified. The log cannot establish staging's effective client-IP keys or environment overrides; the added startup diagnostics make those settings observable without printing headers or credentials.
