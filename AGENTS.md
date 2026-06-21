## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `python3 -c "from graphify.watch import _rebuild_code; from pathlib import Path; _rebuild_code(Path('.'))"` to keep the graph current

## Payment / KYC / swap providers

This Flutter app is a **client of the Owllet backend** (`BACKEND_BASE_URL`,
default `https://fomowl-backend.onrender.com`). Swap and Cash In flows go through
backend endpoints — the app does **not** call payment/KYC/swap providers or hold
their credentials directly. Cash In is a hosted mini app (`CASH_IN_MINI_APP_URL`)
that uses the Owllet mini-app bridge.

The authoritative provider reference (base URLs, auth, endpoints) lives in the
backend repo:

- **Payments / KYC** (Breet, VTpass/eBills, Dojah, Centiiv) —
  `fomowl-backend/docs/integrations/payment-kyc-providers.md`
- **Swap / bridge aggregators** (0x, Jupiter, OpenOcean, Relay, SunSwap, CoW) —
  `fomowl-backend/docs/integrations/swap-aggregators.md`

Keep provider/partner secrets server-side; the app should only consume
backend-prepared routes and quotes.
