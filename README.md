# FOMOwl Wallet

A decentralized crypto wallet built with Flutter, supporting multiple platforms (iOS, Android, Windows, Web).

## 🚀 Features (In Development)

### Phase 1 - Traditional EOA Wallet
- ✅ Onboarding flow with first page
- 🔄 Wallet creation with BIP39 mnemonic
- 🔄 Biometric authentication (Face ID/Fingerprint)
- 🔄 Multi-chain support (Ethereum, Polygon, BSC)
- 🔄 Send/Receive tokens
- 🔄 Token swapping
- 🔄 Transaction history
- 🔄 P2P trading
- 🔄 Bill payments

### Phase 2 - Smart Account (Future)
- Account Abstraction (ERC-4337)
- Social recovery
- Gasless transactions
- Session keys

## 📱 Supported Platforms

- ✅ Android
- ✅ iOS
- ✅ Windows
- ✅ Web
- ⏳ macOS (coming soon)
- ⏳ Linux (coming soon)

## 🛠️ Tech Stack

### Frontend
- **Framework**: Flutter 3.38.6
- **Language**: Dart 3.10.7
- **State Management**: Provider
- **Navigation**: GoRouter
- **UI**: Material Design 3 with custom dark theme

### Packages (Latest 2026 Versions)
- `google_fonts: ^8.0.0` - Custom fonts (Fredoka)
- `web3dart: ^2.7.3` - Ethereum blockchain interaction
- `bip39: ^1.0.6` - Mnemonic generation
- `bip32: ^2.0.0` - HD wallet derivation
- `flutter_secure_storage: ^10.0.0` - Secure key storage
- `local_auth: ^3.0.0` - Biometric authentication
- `qr_flutter: ^4.1.0` - QR code generation
- `mobile_scanner: ^7.1.4` - QR code scanning

## 🎨 Design System

### Colors
- **Background**: `#121212` (Dark gray)
- **Primary Accent**: `#C03223` (Red/Orange)
- **Text Primary**: `#FFFFFF` (White)
- **Text Secondary**: `#909090` (Gray)

### Typography
- **Headings**: Fredoka (600 weight)
- **Body**: Fredoka (400 weight)
- **Captions**: Inter (400 weight)

## 🚦 Getting Started

### Prerequisites
- Flutter SDK 3.38.6 or higher
- Dart SDK 3.10.7 or higher
- Android Studio / VS Code
- Xcode (for iOS development)

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd fomowl_wallet
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Enable Developer Mode (Windows)**
```bash
start ms-settings:developers
```
Enable "Developer Mode" to support symlinks.

4. **Run the app**
```bash
# Android
flutter run

# iOS
flutter run -d ios

# Windows
flutter run -d windows

# Web
flutter run -d chrome
```

## 📂 Project Structure

```
lib/
├── constants/          # App-wide constants
│   ├── app_colors.dart
│   └── app_text_styles.dart
├── models/            # Data models
├── screens/           # UI screens
│   └── onboarding/
│       └── first_page_screen.dart
├── services/          # Business logic & APIs
├── utils/             # Helper functions
├── widgets/           # Reusable widgets
└── main.dart          # App entry point

assets/
└── images/            # Image assets
    ├── first_page_bg.png
    └── logo.png
```

## 🧪 Debug Mode Features

The app currently runs in **debug mode** with:
- Mock wallet data for testing
- No backend/blockchain connection required
- Full UI flow testing enabled
- Hot reload for rapid development

## 🔐 Security Notes

- Private keys are encrypted with AES-256
- Biometric authentication required for sensitive operations
- Secure storage using platform-specific secure enclaves
- Never sends private keys to backend

## 📝 Development Roadmap

### Current Sprint
- [x] Project setup
- [x] Design system implementation
- [x] First page/splash screen
- [ ] Welcome page
- [ ] Language selection
- [ ] Create wallet flow
- [ ] Passcode setup
- [ ] Biometric setup

### Next Sprint
- [ ] Dashboard/Home screen
- [ ] Token list
- [ ] Send/Receive functionality
- [ ] QR code scanner
- [ ] Transaction history

## 🤝 Contributing

This is a private project. Contributions are by invitation only.

## 📄 License

Proprietary - All rights reserved

## 📞 Support

For issues or questions, contact the development team.

---

**Built with ❤️ using Flutter**
