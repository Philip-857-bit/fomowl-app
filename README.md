# FOMOwl Wallet

Flutter wallet client for multi-chain EVM balances, swaps, gasless orders, and wallet-scoped backend sync.

## Current notes

- The app now reads build-time environment values from `AppEnvironment`.
- Supported `--dart-define` keys:
  - `BACKEND_BASE_URL`
  - `COINGECKO_API_BASE_URL`
  - `CONNECTIVITY_CHECK_URL`
- If `BACKEND_BASE_URL` is omitted, local defaults are used:
  - Android emulator: `http://10.0.2.2:3000`
  - iOS/desktop/web: `http://127.0.0.1:3000`
- Network settings sync uses wallet challenge-response auth instead of trusting a raw wallet address.
- Swap and gasless flows route through the configured backend rather than hardcoded production URLs.

## Run locally

```bash
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=http://127.0.0.1:3000
```

Android emulator example:

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000
```

Multiple build-time values example:

```bash
flutter run \
  --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=COINGECKO_API_BASE_URL=https://api.coingecko.com/api/v3 \
  --dart-define=CONNECTIVITY_CHECK_URL=https://www.google.com
```

GitHub Actions release builds inject `BACKEND_BASE_URL` automatically. Set the repository variable `BACKEND_BASE_URL` to override the default hosted backend used by the pipeline.

## Quality checks

```bash
dart format lib test
flutter analyze
flutter test
```
