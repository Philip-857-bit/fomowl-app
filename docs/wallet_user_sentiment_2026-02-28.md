# Wallet User Sentiment Snapshot (Feb 28, 2026)

This note summarizes what users currently expect from mobile self-custody wallets, based on public docs + community feedback reviewed on **February 28, 2026**.

## What users clearly want now

1. **Paste contract, auto-detect token, done**
- Users expect token management search to accept contract addresses and auto-fill metadata (name/symbol/decimals), with manual entry only as fallback.
- Source: Trust Wallet support flow explicitly documents contract paste with auto-populate behavior.
  - https://support.trustwallet.com/support/solutions/articles/67000731431-how-to-add-a-custom-token-to-trust-wallet

2. **Fast, simple token discoverability**
- Wallets are expected to support both searchable token lists and custom token-by-address import on EVM chains.
- Sources:
  - https://support.metamask.io/manage-crypto/tokens/how-to-display-tokens-in-metamask
  - https://support.metamask.io/manage-crypto/tokens/how-to-find-a-token-contract-address

3. **Recovery UX without weakening self-custody**
- Market direction is strongly toward passkey/social-assisted onboarding plus explicit recovery options.
- Sources:
  - https://help.coinbase.com/en/wallet/getting-started/smart-wallet-recovery
  - https://crypto.news/metamask-google-apple-social-logins-wallet-access-2025/

4. **Anti-scam protection is now baseline, not optional**
- Users and support communities repeatedly focus on seed phrase scams, gas bait, fake support, and unsafe transfer patterns.
- Sources:
  - https://www.reddit.com/r/Bitcoin/comments/1mkqx7n
  - https://www.reddit.com/r/CoinBase/comments/1jb6dap
  - https://support.metamask.io/vi/stay-safe/safety-in-web3/why-am-i-being-warned-about-sending-tokens-to-a-contract/

5. **Mobile UX and reliability matter as much as features**
- Public wallet communities still report frustration with cluttered flows and discoverability issues in mobile experiences.
- Source:
  - https://community.metamask.io/t/the-user-experience-in-the-mobile-app-must-be-improved/30803

6. **Network handling should be explicit and easy**
- “Switch network” actions and per-network support boundaries need to be clear in wallet UX.
- Source:
  - https://help.coinbase.com/prime/onchain-wallet/add-a-custom-evm-network-on-the-onchain-wallet

## Product implications for Owllet

## P0 (must-have)
- Contract-paste token import from a single search input.
- Hidden/visible token toggles on the same screen.
- Strong scam guardrails (seed phrase warnings, suspicious transfer warnings, support impersonation warnings).
- Clear switch-network entry point in settings/home.

## P1 (high-value)
- Recovery hardening: passcode/biometric gates for sensitive actions and explicit recovery checks.
- Better token confidence signals: verified contract badges, token risk hints, explorer links.
- Better failure states: plain-language errors for quote, gas, and balance issues.

## P2 (differentiators)
- Personalized “AI suggestions” in manage tokens (based on wallet activity and active chain).
- Smart defaults for spam/scam token filtering.
- Portfolio-level risk/simulation before signing.

## Suggested KPI set for release tracking
- Time-to-add-token (contract paste to visible asset)
- % successful token imports on first attempt
- % swaps blocked by pre-checks (insufficient gas/balance)
- Support tickets by category (recovery, scam confusion, missing assets)
- 7-day retention of first-time wallet creators
