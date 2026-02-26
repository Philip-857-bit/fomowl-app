import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'constants/app_colors.dart';
import 'l10n/app_localizations.dart';
import 'services/wallet_service.dart';
import 'screens/auth/unlock_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/import_wallet_screen.dart';
import 'screens/onboarding/import_secret_phrase_screen.dart';
import 'screens/onboarding/import_private_key_screen.dart';
import 'screens/onboarding/create_wallet_screen.dart';
import 'screens/onboarding/confirm_phrase_screen.dart';
import 'screens/onboarding/verify_phrase_screen.dart';
import 'screens/onboarding/create_passcode_screen.dart';
import 'screens/onboarding/confirm_passcode_screen.dart';
import 'screens/onboarding/biometric_setup_screen.dart';
import 'screens/onboarding/face_id_verification_screen.dart';
import 'screens/onboarding/fingerprint_verification_screen.dart';
import 'screens/onboarding/congratulations_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/wallet/wallets_screen.dart';
import 'screens/wallet/select_token_screen.dart';
import 'screens/wallet/send_token_screen.dart';
import 'screens/wallet/transfer_confirmation_screen.dart';
import 'screens/wallet/token_detail_screen.dart';
import 'screens/wallet/token_management_screen.dart';
import 'screens/wallet/nft_gallery_screen.dart';
import 'screens/swap/swap_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/coming_soon_screen.dart';
import 'screens/profile/coming_soon_overlay.dart';
import 'screens/profile/login_profile_screen.dart';
import 'screens/profile/register_profile_screen.dart';
import 'screens/profile/decentralized_profile_screen.dart';
import 'screens/profile/backup_seed_phrase_screen.dart';
import 'screens/profile/privacy_policy_screen.dart';
import 'screens/profile/terms_and_conditions_screen.dart';
import 'screens/profile/add_network_screen.dart';
import 'screens/profile/kyc_success_screen.dart';
import 'screens/wallet/receive_token_screen.dart';
import 'screens/wallet/qr_scanner_screen.dart';
import 'screens/wallet/deposit_funds_screen.dart';
import 'screens/wallet/confirm_deposit_screen.dart';
import 'screens/transaction/transaction_processing_screen.dart';
import 'screens/transaction/transactions_screen.dart';
import 'screens/transaction/withdraw_to_bank_screen.dart';
import 'screens/payments/payments_screen.dart';
import 'screens/payments/bill_payment_screen.dart';
import 'screens/payments/electricity_suppliers_screen.dart';
import 'services/storage_service.dart';
import 'services/blockchain_service.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => BlockchainService()..init(),
      child: const FOMOwlWalletApp(),
    ),
  );
}

class FOMOwlWalletApp extends StatefulWidget {
  const FOMOwlWalletApp({super.key});

  @override
  State<FOMOwlWalletApp> createState() => FOMOwlWalletAppState();
  
  // Static method to update locale from anywhere in the app
  static void setLocale(BuildContext context, String languageCode) {
    final state = context.findAncestorStateOfType<FOMOwlWalletAppState>();
    state?.updateLocale(languageCode);
  }
}

class FOMOwlWalletAppState extends State<FOMOwlWalletApp> {
  final StorageService _storage = StorageService();
  Locale _locale = const Locale('en', '');

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final languageCode = await _storage.getLanguage();
    if (languageCode != null && mounted) {
      setState(() {
        _locale = Locale(languageCode, '');
      });
    }
  }

  void updateLocale(String languageCode) {
    if (mounted) {
      setState(() {
        _locale = Locale(languageCode, '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Owllet Wallet',
      debugShowCheckedModeBanner: false,
      
      // Localization
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primaryAccent,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryAccent,
          secondary: AppColors.primaryAccent,
          surface: AppColors.cardBackground,
        ),
        useMaterial3: true,
      ),
      home: const AppBootstrapper(),
      routes: {
        '/unlock': (context) => const UnlockScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/import-wallet': (context) => const ImportWalletScreen(),
        '/import-secret-phrase': (context) => const ImportSecretPhraseScreen(),
        '/import-private-key': (context) => const ImportPrivateKeyScreen(),
        '/create-wallet': (context) => const CreateWalletScreen(),
        '/confirm-phrase': (context) => const ConfirmPhraseScreen(),
        '/verify-phrase': (context) => const VerifyPhraseScreen(),
        '/create-passcode': (context) => const CreatePasscodeScreen(),
        '/confirm-passcode': (context) => const ConfirmPasscodeScreen(),
        '/biometric-setup': (context) => const BiometricSetupScreen(),
        '/face-id-verification': (context) => const FaceIdVerificationScreen(),
        '/fingerprint-verification': (context) => const FingerprintVerificationScreen(),
        '/congratulations': (context) => const CongratulationsScreen(),
        '/home': (context) => const HomeScreen(),
        '/wallets': (context) => const WalletsScreen(),
        '/swap': (context) => const SwapScreen(),
        '/select-token': (context) => const SelectTokenScreen(),
        '/send-token': (context) => const SendTokenScreen(),
        '/transfer-confirmation': (context) => const TransferConfirmationScreen(),
        '/token-detail': (context) => const TokenDetailScreen(),
        '/token-management': (context) => const TokenManagementScreen(),
        '/nft-gallery': (context) => NftGalleryScreen(),
        '/profile': (context) => const DecentralizedProfileScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/receive-token': (context) => const ReceiveTokenScreen(),
        '/qr-scanner': (context) => const QrScannerScreen(),
        '/profile-login': (context) => const LoginProfileScreen(),
        '/profile-register': (context) => const RegisterProfileScreen(),
        '/coming-soon': (context) => const ComingSoonScreen(),
        '/privacy-policy': (context) => const PrivacyPolicyScreen(),
        '/terms-and-conditions': (context) => const TermsAndConditionsScreen(),
        '/backup-seed-phrase': (context) => const BackupSeedPhraseScreen(),
        '/add-network': (context) => const AddNetworkScreen(),
        // Fiat/Centralized routes → Coming Soon until backend is live
        '/transaction-processing': (context) => const ComingSoonOverlay(title: 'Transaction Processing', child: TransactionProcessingScreen()),
        '/transactions': (context) => const TransactionsScreen(),
        '/payments': (context) => const ComingSoonOverlay(title: 'Payments', child: PaymentsScreen()),
        '/bill-payment': (context) => const ComingSoonOverlay(title: 'Pay Bills', child: BillPaymentScreen()),
        '/withdraw-to-bank': (context) => const ComingSoonOverlay(title: 'Withdraw to Bank', child: WithdrawToBankScreen()),
        '/deposit-funds': (context) => const ComingSoonOverlay(title: 'Deposit Funds', child: DepositFundsScreen()),
        '/third-party-deposit': (context) => const ComingSoonOverlay(title: 'Provider Deposit', child: ThirdPartyDepositScreen()),
        '/electricity-suppliers': (context) => const ComingSoonOverlay(title: 'Electricity Suppliers', child: ElectricitySuppliersScreen()),
        '/kyc-success': (context) => const ComingSoonOverlay(title: 'Identity Verified', child: KycSuccessScreen()),
      },
    );
  }
}

/// Bootstrapper component replacing visual splash screen
/// Native splash handles UI presentation while this loads
class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  final WalletService _walletService = WalletService();
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final hasWallet = await _walletService.hasWallet();
    if (!mounted) return;

    Widget nextScreen = const WelcomeScreen();

    if (hasWallet) {
      final passcode = await _storage.getPasscode();
      if (passcode != null && passcode.isNotEmpty) {
        nextScreen = const UnlockScreen();
      } else {
        nextScreen = const HomeScreen();
      }
    }

    if (!mounted) return;

    FlutterNativeSplash.remove();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Dissolve animation: Fake timing function ease-in, duration 300ms
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Blank `#131313` backdrop mimicking the native splash 
    // before the dissolve triggers off the framework.
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      body: const SizedBox.expand(),
    );
  }
}
