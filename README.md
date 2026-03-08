# FOMOwl Wallet

Flutter wallet client for multi-chain EVM balances, swaps, gasless orders, and wallet-scoped backend sync.

## Current notes

- The app now reads build-time environment values from `AppEnvironment`.
- Supported `--dart-define` keys:
  - `BACKEND_BASE_URL`
  - `COINGECKO_API_BASE_URL`
  - `CONNECTIVITY_CHECK_URL`
  - `PUSH_NOTIFICATIONS_ENABLED`
  - `FIREBASE_API_KEY`
  - `FIREBASE_ANDROID_APP_ID`
  - `FIREBASE_IOS_APP_ID`
  - `FIREBASE_MESSAGING_SENDER_ID`
  - `FIREBASE_PROJECT_ID`
  - `FIREBASE_STORAGE_BUCKET`
  - `FIREBASE_IOS_BUNDLE_ID`
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

Using a file instead of a long command:

```bash
flutter run --dart-define-from-file=.env
flutter build apk --release --dart-define-from-file=.env
```

The repo now includes a local [`.env`](/c:/Users/HP/Desktop/fomowlwallet/fomowl_wallet/.env)
with the Android Firebase values extracted from `google-services.json`.

Do not commit local secret files such as `.env`, `android/key.properties`,
keystores, or Firebase service-account JSON files. `google-services.json` may be
committed if you choose, but the Firebase service-account JSON must never be committed.

GitHub Actions release builds inject `BACKEND_BASE_URL` automatically. Set the repository variable `BACKEND_BASE_URL` to override the default hosted backend used by the pipeline.

## Push notification registration

The app can now register the current wallet/device with the backend notification
endpoints without changing the UI. Registration happens when the wallet reaches
the home screen and a Firebase Messaging token is available.

Required build-time values:

```text
PUSH_NOTIFICATIONS_ENABLED=true
FIREBASE_API_KEY=...
FIREBASE_ANDROID_APP_ID=...
FIREBASE_IOS_APP_ID=...
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_PROJECT_ID=...
```

Optional:

```text
FIREBASE_STORAGE_BUCKET=...
FIREBASE_IOS_BUNDLE_ID=...
```

If these values are missing, push registration stays disabled and the app still runs normally.

This repo does not include your Firebase project files. You still need to:

- create a Firebase project
- enable Firebase Cloud Messaging
- use matching Android/iOS app IDs
- add the usual native platform setup for your store builds if required by your Firebase configuration
- place `google-services.json` at `android/app/google-services.json` for Android builds

The backend must also be configured with matching Firebase service account
credentials so saved device tokens can actually receive pushes when
`/api/notifications/add` is called.

For CI Android builds, store the file content as a base64 secret named
`GOOGLE_SERVICES_JSON_BASE64`. The workflow will write it to
`android/app/google-services.json` before building.

## Android release signing

Release builds no longer use the debug signing key.

Configure one permanent release key using either:

- `android/key.properties` based on [`android/key.properties.example`](/c:/Users/HP/Desktop/fomowlwallet/fomowl_wallet/android/key.properties.example)
- CI environment variables:
  - `KEYSTORE_BASE64`
  - `KEYSTORE_FILE`
  - `KEYSTORE_PASSWORD`
  - `KEY_ALIAS`
  - `KEY_PASSWORD`

The `owllet-release.jks` file is not downloaded from anywhere. You generate it once yourself and keep it private.

It is your permanent Android release signing key. Every future APK/AAB update for the same installed app must be signed with this same key. If you lose it, direct APK updates signed outside Google Play will stop working for already-installed users.

Local generation example:

```powershell
cd fomowl_wallet
.\scripts\create_android_keystore.ps1 `
  -KeystorePath ".\keystore\owllet-release.jks" `
  -Alias "owllet" `
  -StorePassword "your_store_password" `
  -KeyPassword "your_key_password"
```

Then copy:

```text
android/key.properties.example -> android/key.properties
```

and set:

```text
storeFile=../keystore/owllet-release.jks
storePassword=your_store_password
keyAlias=owllet
keyPassword=your_key_password
```

For GitHub Actions, base64-encode that `.jks` file and store it in the `KEYSTORE_BASE64` secret, along with `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and `KEY_PASSWORD`.

To print the SHA-1 and SHA-256 fingerprints for Firebase:

```powershell
cd fomowl_wallet
.\scripts\get_android_fingerprints.ps1
```

If `android/key.properties` is not present, pass the values manually:

```powershell
cd fomowl_wallet
.\scripts\get_android_fingerprints.ps1 `
  -KeystorePath ".\keystore\owllet-release.jks" `
  -Alias "owllet" `
  -StorePassword "your_store_password" `
  -KeyPassword "your_key_password"
```

Helper command:

```powershell
cd fomowl_wallet
.\scripts\encode_android_keystore.ps1 -KeystorePath ".\keystore\owllet-release.jks"
```

If you prefer writing the encoded value to a file first:

```powershell
cd fomowl_wallet
.\scripts\encode_android_keystore.ps1 `
  -KeystorePath ".\keystore\owllet-release.jks" `
  -OutputPath ".\keystore\owllet-release.base64.txt"
```

If release signing is missing, Android release builds now fail fast instead of producing a debug-signed release APK/AAB.

## Quality checks

```bash
dart format lib test
flutter analyze
flutter test
```
