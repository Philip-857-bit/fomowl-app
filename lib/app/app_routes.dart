import 'package:flutter/material.dart';

import '../features/mini_apps/mini_app_host_screen.dart';
import '../features/shell/app_shell_controller.dart';
import '../features/shell/app_shell_screen.dart';
import '../features/shell/shell_route_redirect.dart';
import '../screens/auth/unlock_screen.dart';
import '../screens/earn/earn_coming_soon_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/onboarding/biometric_setup_screen.dart';
import '../screens/onboarding/blockchain_selection_screen.dart';
import '../screens/onboarding/congratulations_screen.dart';
import '../screens/onboarding/confirm_passcode_screen.dart';
import '../screens/onboarding/confirm_phrase_screen.dart';
import '../screens/onboarding/create_passcode_screen.dart';
import '../screens/onboarding/create_wallet_screen.dart';
import '../screens/onboarding/biometric_success_screen.dart';
import '../screens/onboarding/face_capture_screen.dart';
import '../screens/onboarding/face_id_verification_screen.dart';
import '../screens/onboarding/fingerprint_check_screen.dart';
import '../screens/onboarding/fingerprint_verification_screen.dart';
import '../screens/onboarding/import_private_key_screen.dart';
import '../screens/onboarding/import_secret_phrase_screen.dart';
import '../screens/onboarding/wallet_imported_screen.dart';
import '../screens/onboarding/import_wallet_screen.dart';
import '../screens/onboarding/language_selection_screen.dart';
import '../screens/onboarding/verify_phrase_screen.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../screens/payments/bill_payment_screen.dart';
import '../screens/payments/electricity_suppliers_screen.dart';
import '../screens/profile/add_network_screen.dart';
import '../screens/profile/backup_seed_phrase_screen.dart';
import '../screens/profile/coming_soon_overlay.dart';
import '../screens/profile/coming_soon_screen.dart';
import '../screens/profile/community_links_screen.dart';
import '../screens/profile/connected_apps_screen.dart';
import '../screens/profile/feedback_screen.dart';
import '../screens/profile/kyc_success_screen.dart';
import '../screens/profile/login_profile_screen.dart';
import '../screens/profile/password_security_screen.dart';
import '../screens/profile/privacy_policy_screen.dart';
import '../screens/profile/referrals_screen.dart';
import '../screens/profile/register_profile_screen.dart';
import '../screens/profile/terms_and_conditions_screen.dart';
import '../screens/profile/two_factor_setup_screen.dart';
import '../screens/transaction/transaction_processing_screen.dart';
import '../screens/transaction/transactions_screen.dart';
import '../screens/transaction/withdraw_to_bank_screen.dart';
import '../screens/wallet/confirm_deposit_screen.dart';
import '../screens/wallet/deposit_funds_screen.dart';
import '../screens/wallet/nft_gallery_screen.dart';
import '../screens/wallet/qr_scanner_screen.dart';
import '../screens/wallet/receive_token_screen.dart';
import '../screens/wallet/send_nft_screen.dart';
import '../screens/wallet/select_token_screen.dart';
import '../screens/wallet/send_token_screen.dart';
import '../screens/wallet/token_detail_screen.dart';
import '../screens/wallet/token_management_screen.dart';
import '../screens/wallet/transfer_confirmation_screen.dart';
import '../screens/wallet/wallets_screen.dart';

Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    '/unlock': (_) => const UnlockScreen(),
    '/welcome': (_) => const WelcomeScreen(),
    '/import-wallet': (_) => const ImportWalletScreen(),
    '/language-selection': (_) => const LanguageSelectionScreen(),
    '/import-secret-phrase': (_) => const ImportSecretPhraseScreen(),
    '/wallet-imported': (_) => const WalletImportedScreen(),
    '/import-private-key': (_) => const ImportPrivateKeyScreen(),
    '/create-wallet': (_) => const CreateWalletScreen(),
    '/confirm-phrase': (_) => const ConfirmPhraseScreen(),
    '/verify-phrase': (_) => const VerifyPhraseScreen(),
    '/create-passcode': (_) => const CreatePasscodeScreen(),
    '/confirm-passcode': (_) => const ConfirmPasscodeScreen(),
    '/biometric-setup': (_) => const BiometricSetupScreen(),
    '/face-id-verification': (_) => const FaceIdVerificationScreen(),
    '/face-id-check': (_) => const FaceCaptureScreen(),
    '/fingerprint-verification': (_) => const FingerprintVerificationScreen(),
    '/fingerprint-check': (_) => const FingerprintCheckScreen(),
    '/biometric-success': (_) => const BiometricSuccessScreen(),
    '/congratulations': (_) => const CongratulationsScreen(),
    '/blockchain-selection': (_) => const BlockchainSelectionScreen(),
    '/shell': (_) => const AppShellScreen(),
    '/home': (_) => const ShellRouteRedirect(tab: AppShellTab.wallet),
    '/earn': (_) => const EarnComingSoonScreen(),
    '/wallets': (_) => const WalletsScreen(),
    '/swap': (_) => const ShellRouteRedirect(tab: AppShellTab.swap),
    '/select-token': (_) => const SelectTokenScreen(),
    '/send-token': (_) => const SendTokenScreen(),
    '/send-nft': (_) => const SendNftScreen(),
    '/transfer-confirmation': (_) => const TransferConfirmationScreen(),
    '/token-detail': (_) => const TokenDetailScreen(),
    '/token-management': (_) => const TokenManagementScreen(),
    '/nft-gallery': (_) => NftGalleryScreen(),
    '/profile': (_) => const ShellRouteRedirect(tab: AppShellTab.settings),
    '/notifications': (_) => const NotificationsScreen(),
    '/receive-token': (_) => const ReceiveTokenScreen(),
    '/qr-scanner': (_) => const QrScannerScreen(),
    '/profile-login': (_) => const LoginProfileScreen(),
    '/profile-register': (_) => const RegisterProfileScreen(),
    '/coming-soon': (_) => const ComingSoonScreen(),
    '/privacy-policy': (_) => const PrivacyPolicyScreen(),
    '/terms-and-conditions': (_) => const TermsAndConditionsScreen(),
    '/backup-seed-phrase': (_) => const BackupSeedPhraseScreen(),
    '/password-security': (_) => const PasswordSecurityScreen(),
    '/two-factor-setup': (_) => const TwoFactorSetupScreen(),
    '/owllet-pay': (context) => MiniAppHostScreen.fromRoute(context),
    '/cash-in': (context) => MiniAppHostScreen.fromRoute(context),
    '/mini-app-host': (context) => MiniAppHostScreen.fromRoute(context),
    '/referrals': (_) => const ReferralsScreen(),
    '/feedback': (_) => const FeedbackScreen(),
    '/community': (_) => const CommunityLinksScreen(),
    '/connected-apps': (_) => const ConnectedAppsScreen(),
    '/add-network': (_) => const AddNetworkScreen(),
    '/transaction-processing': (_) => const TransactionProcessingScreen(),
    '/transactions': (_) => const TransactionsScreen(),
    '/bill-payment': (_) => const BillPaymentScreen(),
    '/withdraw-to-bank': (_) => const ComingSoonOverlay(
      title: 'Withdraw to Bank',
      child: WithdrawToBankScreen(),
    ),
    '/deposit-funds': (_) => const ComingSoonOverlay(
      title: 'Deposit Funds',
      child: DepositFundsScreen(),
    ),
    '/third-party-deposit': (_) => const ThirdPartyDepositScreen(),
    '/electricity-suppliers': (_) => const ElectricitySuppliersScreen(),
    '/kyc-success': (_) => const KycSuccessScreen(),
  };
}
