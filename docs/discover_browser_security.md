# Discover Browser Security Note

## Intended Use

`flutter_inappwebview` is used only for Owllet's curated Discover DApp browser. It is not used for general browsing, onboarding, passcode, backup, or wallet management flows.

## Security Controls

- Discover only opens DApps from a backend-managed allowlist
- URL normalization and origin checks gate navigation
- Provider injection is limited to approved injectable origins
- All wallet actions are routed through `DappProviderBridge`
- Connection, signing, chain switching, add-chain, and transaction sends require explicit user approval
- Added chains must provide HTTPS RPC endpoints and must return the requested `eth_chainId`

## Isolation Guarantee

Private keys, seed phrases, and signing internals are never exposed directly to WebView APIs.

- Key material remains in Owllet storage and native signing paths
- Web content only sees the reviewed provider bridge surface
- WebView code cannot call wallet key-management code directly
- Every signing or transaction request still requires explicit Flutter-side user confirmation

## Dependency Review

Reviewed on 2026-03-30.

- Current pinned package: `flutter_inappwebview` `6.1.5`
- Latest stable package version found on pub.dev at review time: `6.1.5`
- Newer prerelease visible on pub.dev at review time: `6.2.0-beta.3`
- No package-specific GitHub Advisories or OSV entries were found for the Flutter package name during this review

## Pinning Decision

`6.1.5` remains pinned because it is the latest stable version at review time. No upgrade was required, and the Discover browser keeps strong allowlist, origin, approval, and key-isolation controls around the WebView surface.
