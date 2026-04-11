# Cash in Web Mini-App Foundation

## Recommendation

Cash in should move to a hosted web mini-app model and should not remain a large native Flutter feature.

That direction is feasible and it is the better long-term foundation for Owllet if the goal is:

- shipping product changes without forcing a mobile release every time
- using the Discover/browser foundation as a host runtime
- eventually allowing other teams to build mini apps that live inside Owllet
- keeping wallet custody and account security under Owllet control

The right split is:

- native Owllet app for wallet custody, secure storage, signing, biometrics, push, session control, and core account security
- hosted web mini apps for fast-moving product surfaces like Cash in, bill pay, provider-specific flows, and dashboards
- Owllet backend as the policy and integration layer between the hosted mini app and third-party providers

## Why This Is The Better Option

### 1. Faster product iteration

A hosted mini app can be updated on the web stack without waiting for App Store or Play Store review cycles.

That matches your stated goal exactly: keep improving Cash in and future mini apps without having to republish the wallet app for every UI or provider workflow change.

### 2. Better platform foundation

The Discover/browser model can evolve into a real Owllet mini-app platform:

- Owllet hosts allowlisted mini-app origins
- Owllet controls which origins can request wallet-adjacent capabilities
- Owllet can later publish a lightweight JS bridge and session contract for approved builders
- third parties can ship mini apps faster than native feature releases

This is conceptually similar to other hosted mini-app ecosystems where the host app launches web apps by URL and exposes a controlled integration surface. Telegram's official Mini Apps docs are the clearest public example of this model: a hosted web app launched inside the container, with the host controlling the bridge and validating session data on the server.  
Source: https://core.telegram.org/bots/webapps

### 3. Keeps the dangerous parts out of the web layer

Cash in touches:

- wallet session state
- KYC
- fiat on-ramp/off-ramp
- bank account verification
- potential withdrawal approval

Those are exactly the flows where the web layer must not get direct access to:

- seed phrases
- private keys
- raw signing primitives
- partner API secrets
- device trust state

So the architecture should not be "web app talks directly to partner APIs."  
It should be "web app talks to Owllet backend; Owllet backend talks to Breet, Dojah, email, SMS, and other providers."

## Final Product Direction

### What stays native in Owllet

- wallet creation/import
- secure key storage
- transaction signing and approval
- biometrics and passcode gating
- main account security settings
- Owllet-branded TOTP setup and recovery handling
- push notifications
- deep-link handling and trusted session bootstrap

### What becomes a hosted mini app

- Cash in dashboard
- on-ramp and off-ramp order flows
- bank list, bank verification, bank payout status
- KYC step orchestration UI
- bills, utilities, data, airtime, education, cable TV, e-commerce
- provider-specific forms and catalogs
- transaction/activity views related to fiat services

## Why Breet Still Belongs Behind The Backend

Breet is a good fit for the first on-ramp and off-ramp provider, but it is a backend integration, not a client-side integration.

Breet's official docs show authenticated partner requests using headers like:

- `x-app-id`
- `x-app-secret`
- `X-Breet-Env`

Those credentials must never live in Flutter or in a public web mini app.

The Breet docs also expose the backend primitives we need for a proper Owllet integration:

- fetch sell and deposit assets
- generate deposit wallet address
- fetch supported withdrawal assets
- fetch banks
- validate bank account
- add bank
- initiate bank withdrawal
- fetch withdrawal status
- fetch trade transaction status

Official references:

- Quickstart: https://docs.breet.io/quickstart
- Error handling and auth expectations: https://docs.breet.io/errors
- OpenAPI reference: https://docs.breet.io/api-reference/openapi.json

### What this means for Owllet

The hosted Cash in mini app should call Owllet backend endpoints such as:

- `GET /cash-in/assets`
- `POST /cash-in/orders/deposit-address`
- `GET /cash-in/banks`
- `POST /cash-in/banks/validate`
- `POST /cash-in/withdrawals`
- `GET /cash-in/withdrawals/{id}`

The Owllet backend then talks to Breet.

This keeps:

- partner secrets safe
- response normalization under Owllet control
- retry and error handling centralized
- webhook verification centralized
- user and wallet authorization enforced server-side

## Why Dojah Still Belongs Behind The Backend

Dojah is a strong fit for Nigeria-first KYC, especially for:

- BVN verification
- NIN verification
- selfie and liveness checks
- broader easy-onboarding identity workflows

Official references:

- EasyOnboard overview: https://docs.dojah.io/overview/user-verification/easy-onboard
- Selfie verification example: https://docs.dojah.io/docs/nigeria/selfie-verification-vnin

### What this means for Owllet

The hosted Cash in mini app can present the KYC UX, but Owllet backend should own:

- Dojah credentials
- verification session creation
- result normalization
- storage of verified status
- provider callback handling

If Owllet later chooses Dojah's hosted onboarding widgets for some steps, that is still compatible with the hosted mini-app direction. The important rule is the same: provider trust and verification state remain backend-controlled.

## KYC Media Handling Recommendation

The document upload and selfie capture flows should not write directly from the browser to a random partner endpoint without Owllet mediation.

Recommended flow:

1. Mini app requests an upload session from Owllet backend.
2. Owllet backend returns a short-lived signed upload target or an Owllet-controlled upload endpoint.
3. The mini app uploads the document or selfie.
4. Owllet backend stores metadata and forwards or references the media for Dojah verification.
5. Owllet backend records the verification outcome and exposes it back to the mini app.

That gives Owllet:

- auditability
- retry control
- provider portability
- the ability to switch providers later without breaking the client

## 2FA Decision

TOTP authenticator should be treated as a core Owllet account-security feature, not a Cash in feature.

That means:

- enable and setup lives in the main Owllet security settings
- the branding should be Owllet-branded
- the hosted mini app can respect 2FA state, but it should not own the primary setup experience

The backend implementation can remain standards-based TOTP.  
Reference: RFC 6238, Time-Based One-Time Password Algorithm  
Source: https://www.rfc-editor.org/rfc/rfc6238

## SMS Provider Reality Check

There is no truly durable "free" production SMS provider that Owllet should build around for phone verification.

That is why phone verification should stay behind a feature flag until a paid provider is chosen.

Firebase's official docs make it clear that phone auth is limited and pricing depends on usage and region rather than being a forever-free production channel.

Official references:

- Limits: https://firebase.google.com/docs/auth/limits
- Pricing: https://firebase.google.com/docs/phone-number-verification/pricing

So the product direction should be:

- authenticator and TOTP first
- SMS phone verification later, once Owllet chooses a real provider

## Security Model For The Mini-App Platform

If Owllet wants Cash in to be the first mini app and later let others build on the platform, the browser foundation should evolve with these rules:

### 1. Allowlisted origins only for mini apps

Not every normal website should be treated like an Owllet mini app.

Owllet should maintain an allowlist of trusted mini-app origins.

### 2. Separate browsing from privileged mini-app access

General browsing can exist, but privileged capabilities must remain locked down.

Privileged capabilities include:

- session bootstrap
- wallet-adjacent requests
- payout or KYC actions
- access to signed user context

### 3. No private key access from mini apps

Hosted mini apps should never receive:

- seed phrase
- raw private key
- unrestricted signing APIs

If a future mini app needs blockchain actions, Owllet must gate those through explicit native approval flows.

### 4. Signed session handoff

When Owllet opens a mini app, it should be able to pass a short-lived signed session token or launch token that the backend can verify.

That allows the mini app to know:

- which Owllet account opened it
- what permissions are allowed
- when the session expires

without exposing internal app secrets.

### 5. Backend mediation for all partner calls

Mini apps talk to Owllet backend.  
Owllet backend talks to partners.

That is the non-negotiable rule if Owllet wants to host third-party mini apps safely.

## Recommended Rollout

### Phase 1: Foundation

- keep the Discover/browser foundation
- keep allowlist enforcement
- keep privileged access behind Owllet policy
- move Cash in from native Flutter screens to a hosted Owllet web app
- keep 2FA in the native main app

### Phase 2: Cash in web app

- build Cash in as a hosted Owllet-owned web app
- use Owllet backend for Breet and Dojah orchestration
- ship rapidly without native app releases

### Phase 3: Mini-app platform contract

- define launch token format
- define trusted-origin policy
- define mini-app lifecycle callbacks
- define review and publishing requirements for third-party apps

### Phase 4: Third-party mini apps

- let approved builders host their mini apps
- Owllet reviews and allowlists them
- sensitive capabilities remain permissioned and mediated

## Practical Conclusion

Yes, what you described is feasible, and it is the right direction if Owllet wants:

- fast product iteration
- a mini-app ecosystem
- less dependence on mobile app release cycles
- clean separation between wallet security and fast-moving fintech product surfaces

The key architectural decision is this:

> Cash in should be a hosted Owllet mini app, but the trust boundary must stay in Owllet native and Owllet backend.

That means:

- web for experience
- backend for provider integrations
- native for custody and security

## Recommended Web Stack

Do not build a custom web framework from scratch for Owllet.

That would slow the project down, increase security risk, and create long-term maintenance cost with no real upside at this stage.

The better approach is:

- use a mature web framework
- keep Owllet-specific behavior in an internal package or SDK

### Recommended framework

The best fit for Cash in is Next.js with React and TypeScript.

Why:

- mature SSR and routing model
- strong ecosystem and hiring pool
- easy split between public pages, authenticated app pages, and API-adjacent server logic
- good fit for provider dashboards, KYC flows, auth handoff, and embedded web-app experiences
- easy to build a secure, server-aware app that still feels fast

Official reference:

- Next.js docs: https://nextjs.org/docs

### What Owllet should build on top of it

Create an internal package such as `@owllet/mini-app-sdk`.

That package should contain:

- Owllet mini-app bridge client
- launch context parsing
- theme tokens for embedded Owllet apps
- signed launch token helpers
- mini-app permission and capability helpers
- analytics hooks for embedded usage

So the stack becomes:

- framework: Next.js
- Owllet platform layer: `@owllet/mini-app-sdk`
- backend integration layer: Owllet backend APIs

That is much better than inventing an Owllet-only framework.

### When to consider something else

- If the goal was mostly content or landing pages, Astro would be a good speed-first option.
- If the goal was a smaller but still serious app stack, SvelteKit would also be viable.

But for Cash in, account state, KYC, embedded app shells, and future mini-app ecosystem work, Next.js is the safer and more practical default.

## What I Changed In The App

- Restored the native Cash in Flutter module out of the mobile app so the app is no longer tied to that product shell.
- Moved the authenticator setup flow back into the main Owllet app as an Owllet-branded security screen.

## Notes About The Earlier Native Mockups

The native Cash in screens that existed before the restore did not use the PNG mockups from your Downloads folder directly.

They used existing repo assets such as:

- `assets/images/logo.png`
- `assets/images/first_page_bg.png`
- `assets/images/owl_lock.png`

The download mockups were used as visual reference only, not imported as runtime image assets.
