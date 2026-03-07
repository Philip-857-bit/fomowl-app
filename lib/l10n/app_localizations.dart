import 'package:flutter/material.dart';

/// App Localizations
/// Provides localized strings for the app
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', ''),
    Locale('es', ''),
    Locale('fr', ''),
    Locale('zh', ''),
    Locale('ar', ''),
  ];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'zh': 'Chinese',
    'ar': 'Arabic',
  };

  Map<String, String> get _localizedStrings {
    switch (locale.languageCode) {
      case 'es':
        return _spanishStrings;
      case 'fr':
        return _frenchStrings;
      case 'zh':
        return _chineseStrings;
      case 'ar':
        return _arabicStrings;
      default:
        return _englishStrings;
    }
  }

  String translate(String key) {
    return _localizedStrings[key] ?? _englishStrings[key] ?? key;
  }

  // --- Onboarding ---
  String get appName => translate('app_name');
  String get welcomeTitle => translate('welcome_title');
  String get welcomeSubtitle => translate('welcome_subtitle');
  String get createWallet => translate('create_wallet');
  String get importWallet => translate('import_wallet');
  String get chooseLanguage => translate('choose_language');
  String get chooseDesiredLanguage => translate('choose_desired_language');
  String get tradeInstantly => translate('trade_instantly');
  String get spendEffortlessly => translate('spend_effortlessly');
  String get getStarted => translate('get_started');
  String get alreadyHaveWallet => translate('already_have_wallet');
  String get importExistingWallet => translate('import_existing_wallet');
  String get secretPhrase => translate('secret_phrase');
  String get privateKey => translate('private_key');
  String get enterPasscode => translate('enter_passcode');
  String get confirmPasscode => translate('confirm_passcode');
  String get setupBiometric => translate('setup_biometric');
  String get enableFaceId => translate('enable_face_id');
  String get enableFingerprint => translate('enable_fingerprint');
  String get skip => translate('skip');
  String get continue_ => translate('continue');
  String get congratulations => translate('congratulations');
  String get walletCreated => translate('wallet_created');
  String get walletImported => translate('wallet_imported');
  String get goToWallet => translate('go_to_wallet');

  // --- Bottom Navigation ---
  String get home => translate('home');
  String get wallet => translate('wallet');
  String get swap => translate('swap');
  String get earn => translate('earn');
  String get payment => translate('payment');
  String get me => translate('me');
  String get settings => translate('settings');

  // --- Home Screen ---
  String get balance => translate('balance');
  String get tokens => translate('tokens');
  String get nfts => translate('nfts');
  String get loadingBalances => translate('loading_balances');
  String get noTokensYet => translate('no_tokens_yet');
  String get depositTokens => translate('deposit_tokens');
  String get totalBalance => translate('total_balance');
  String get nftPreview => translate('nft_preview');
  String get viewAll => translate('view_all');
  String get noNftsFound => translate('no_nfts_found');
  String get nftPreviewDescription => translate('nft_preview_description');

  // --- Actions ---
  String get send => translate('send');
  String get receive => translate('receive');
  String get buy => translate('buy');
  String get sell => translate('sell');

  // --- Wallets ---
  String get wallets => translate('wallets');
  String get activeWallet => translate('active_wallet');
  String get addWallet => translate('add_wallet');
  String get createNewWallet => translate('create_new_wallet');
  String get importSeedPhrase => translate('import_seed_phrase');
  String get importPrivateKey => translate('import_private_key');
  String get mainWallet => translate('main_wallet');
  String get addressCopied => translate('address_copied');

  // --- Profile ---
  String get profile => translate('profile');
  String get general => translate('general');
  String get manageWallets => translate('manage_wallets');
  String get switchNetwork => translate('switch_network');
  String get currency => translate('currency');
  String get chooseYourLanguage => translate('choose_your_language');
  String get referrals => translate('referrals');
  String get security => translate('security');
  String get others => translate('others');
  String get passwordSecurity => translate('password_security');
  String get network => translate('network');
  String get selectNetwork => translate('select_network');
  String get addCustomNetwork => translate('add_custom_network');
  String get seedPhraseBackup => translate('seed_phrase_backup');
  String get resetWallet => translate('reset_wallet');
  String get resetApp => translate('reset_app');
  String get privacyPolicy => translate('privacy_policy');
  String get termsOfService => translate('terms_of_service');
  String get feedback => translate('feedback');
  String get joinOurCommunity => translate('join_our_community');

  // --- NFT ---
  String get noNftsYet => translate('no_nfts_yet');
  String get nftCollection => translate('nft_collection');

  // --- Transactions ---
  String get transactionHistory => translate('transaction_history');
  String get notifications => translate('notifications');
  String get transactionBroadcast => translate('transaction_broadcast');
  String get transactionFailed => translate('transaction_failed');
  String get confirmTransfer => translate('confirm_transfer');
  String get gasFee => translate('gas_fee');
  String get transactionDetails => translate('transaction_details');
  String get transferWarningMessage => translate('transfer_warning_message');
  String get maxTotal => translate('max_total');
  String get amount => translate('amount');
  String get estimationFailed => translate('estimation_failed');

  // --- Errors ---
  String get networkError => translate('network_error');
  String get connectionFailed => translate('connection_failed');
  String get tryAgain => translate('try_again');
  String get comingSoon => translate('coming_soon');
  String get resetFailed => translate('reset_failed');
  String get confirmClearLocalData => translate('confirm_clear_local_data');
  String get cancel => translate('cancel');
  String get actionRequired => translate('action_required');
  String get sendToken => translate('send_token');
  String get enterReceivingAddress => translate('enter_receiving_address');
  String get invalidEthereumAddress => translate('invalid_ethereum_address');
  String get enterValidAmount => translate('enter_valid_amount');
  String get insufficientBalance => translate('insufficient_balance');
  String get createPasscodeTitle => translate('create_passcode_title');
  String get createPasscodeDescription =>
      translate('create_passcode_description');
  String get confirmPasscodeTitle => translate('confirm_passcode_title');
  String get confirmPasscodeDescription =>
      translate('confirm_passcode_description');
  String get failedToSavePasscode => translate('failed_to_save_passcode');
  String get passcodesDoNotMatch => translate('passcodes_do_not_match');
  String get unlockWalletReason => translate('unlock_wallet_reason');
  String get unlockEnterPasscode => translate('unlock_enter_passcode');
  String get lockedOutTitle => translate('locked_out_title');
  String unlockTryAgainIn(int seconds) =>
      translate('unlock_try_again_in').replaceFirst('{seconds}', '$seconds');
  String attemptsRemaining(int count) =>
      translate('attempts_remaining').replaceFirst('{count}', '$count');
  String incorrectPasscodeRemaining(int count) => translate(
    'incorrect_passcode_remaining',
  ).replaceFirst('{count}', '$count');
  String tooManyAttemptsLocked(int seconds) => translate(
    'too_many_attempts_locked',
  ).replaceFirst('{seconds}', '$seconds');
  String get enterPasscodeTitle => translate('enter_passcode_title');
  String get passcodeHint => translate('passcode_hint');
  String get walletNameLabel => translate('wallet_name_label');
  String get enterWalletNameHint => translate('enter_wallet_name_hint');
  String get enterSecretPhraseHint => translate('enter_secret_phrase_hint');
  String get secretPhraseHelperText => translate('secret_phrase_helper_text');
  String get paste => translate('paste');
  String get walletImportedSuccessfully =>
      translate('wallet_imported_successfully');
  String get enterSecretPhrasePrompt => translate('enter_secret_phrase_prompt');
  String get enterWalletNamePrompt => translate('enter_wallet_name_prompt');
  String get invalidSecretPhrasePrompt =>
      translate('invalid_secret_phrase_prompt');
  String importWalletFailed(String error) =>
      translate('import_wallet_failed').replaceFirst('{error}', error);
  String get enterPrivateKeyPrompt => translate('enter_private_key_prompt');
  String get invalidPrivateKeyLength => translate('invalid_private_key_length');
  String get invalidPrivateKeyCharacters =>
      translate('invalid_private_key_characters');
  String get enterPrivateKeyHint => translate('enter_private_key_hint');
  String get privateKeyHelperText => translate('private_key_helper_text');
  String get incorrectPasscode => translate('incorrect_passcode');
  String get confirm => translate('confirm');
  String get feedbackTitle => translate('feedback_title');
  String get feedbackSubtitle => translate('feedback_subtitle');
  String get feedbackCategory => translate('feedback_category');
  String get feedbackSubjectOptional => translate('feedback_subject_optional');
  String get feedbackMessage => translate('feedback_message');
  String get feedbackContactEmailOptional =>
      translate('feedback_contact_email_optional');
  String get feedbackCategoryGeneral => translate('feedback_category_general');
  String get feedbackCategoryBug => translate('feedback_category_bug');
  String get feedbackCategoryFeature => translate('feedback_category_feature');
  String get feedbackCategoryDesign => translate('feedback_category_design');
  String get feedbackSubjectHint => translate('feedback_subject_hint');
  String get feedbackMessageHint => translate('feedback_message_hint');
  String get feedbackEmailHint => translate('feedback_email_hint');
  String get submitFeedback => translate('submit_feedback');
  String get enterFeedbackMessage => translate('enter_feedback_message');
  String get noActiveWalletFound => translate('no_active_wallet_found');
  String get feedbackSubmitted => translate('feedback_submitted');
  String get feedbackSubmitFailed => translate('feedback_submit_failed');
  String get manageWalletsTitle => translate('manage_wallets_title');
  String get createAddWallet => translate('create_add_wallet');
  String get renameWallet => translate('rename_wallet');
  String get viewPrivateKey => translate('view_private_key');
  String get removeWallet => translate('remove_wallet');
  String get save => translate('save');
  String get walletRenamed => translate('wallet_renamed');
  String get walletRemoved => translate('wallet_removed');
  String get unableToLoadWallets => translate('unable_to_load_wallets');
  String get newWalletCreated => translate('new_wallet_created');
  String unableToCreateWallet(String error) =>
      translate('unable_to_create_wallet').replaceFirst('{error}', error);
  String walletSetAsActive(String name) =>
      translate('wallet_set_as_active').replaceFirst('{name}', name);
  String unableToSwitchWallet(String error) =>
      translate('unable_to_switch_wallet').replaceFirst('{error}', error);
  String unableToRenameWallet(String error) =>
      translate('unable_to_rename_wallet').replaceFirst('{error}', error);
  String unableToRemoveWallet(String error) =>
      translate('unable_to_remove_wallet').replaceFirst('{error}', error);
  String get mustKeepOneWallet => translate('must_keep_one_wallet');
  String get removeWalletWarning => translate('remove_wallet_warning');
  String get authenticationRequired => translate('authentication_required');
  String get noPrivateKeyFound => translate('no_private_key_found');
  String get privateKeySecurityWarning =>
      translate('private_key_security_warning');
  String get activeWalletLabel => translate('active_wallet_label');
  String get addToken => translate('add_token');
  String get authenticateToViewPrivateKey =>
      translate('authenticate_to_view_private_key');
  String unableToLoadPrivateKey(String error) =>
      translate('unable_to_load_private_key').replaceFirst('{error}', error);
  String get manageTokens => translate('manage_tokens');
  String get visibleTokens => translate('visible_tokens');
  String get addedTokens => translate('added_tokens');
  String get suggestedTokens => translate('suggested_tokens');
  String get searchResults => translate('search_results');
  String get noTokensDetectedYet => translate('no_tokens_detected_yet');
  String get noMatchingTokensFound => translate('no_matching_tokens_found');
  String get pasteContractToAddToken =>
      translate('paste_contract_to_add_token');
  String get noSuggestedTokensYet => translate('no_suggested_tokens_yet');
  String get noRemoteTokensFound => translate('no_remote_tokens_found');
  String get tokenRemoved => translate('token_removed');
  String get tokenAlreadyAvailable => translate('token_already_available');
  String get tokenAlreadyExistsOnNetwork =>
      translate('token_already_exists_on_network');
  String tokenAdded(String symbol) =>
      translate('token_added').replaceFirst('{symbol}', symbol);
  String tokenAddFailed(String error) =>
      translate('token_add_failed').replaceFirst('{error}', error);
  String get missingTokenContractAddress =>
      translate('missing_token_contract_address');
  String get tokenDetected => translate('token_detected');
  String get contractAddressLabel => translate('contract_address_label');
  String get ignore => translate('ignore');
  String get added => translate('added');
  String get couldNotDetectTokenMetadata =>
      translate('could_not_detect_token_metadata');
  String get myBalance => translate('my_balance');
  String get tokenNotFound => translate('token_not_found');
  String get loading => translate('loading');
  String get copiedToClipboard => translate('copied_to_clipboard');
  String get passwordSecurityTitle => translate('password_security_title');
  String get accessControl => translate('access_control');
  String get changePassword => translate('change_password');
  String get passcodeUnlock => translate('passcode_unlock');
  String get biometricsFaceId => translate('biometrics_face_id');
  String get advancedSecurity => translate('advanced_security');
  String get twoFactorAuth => translate('two_factor_auth');
  String get onLabel => translate('on_label');
  String get offLabel => translate('off_label');
  String get autoLockTimer => translate('auto_lock_timer');
  String autoLockMinutesLabel(int minutes) => translate(
    'auto_lock_minutes_label',
  ).replaceFirst('{minutes}', '$minutes');
  String get securityPreferencesLoadFailed =>
      translate('security_preferences_load_failed');
  String get retry => translate('retry');
  String get unableToUpdateBiometric => translate('unable_to_update_biometric');
  String get unableToUpdateTwoFactor =>
      translate('unable_to_update_two_factor');
  String get unableToUpdateAutoLock => translate('unable_to_update_auto_lock');
  String get securitySummary => translate('security_summary');
  String get searchTokenOrPasteContract =>
      translate('search_token_or_paste_contract');
  String get clearSearch => translate('clear_search');
  String get createWalletCopiedSeed => translate('create_wallet_copied_seed');
  String get secretRecoveryPhrase => translate('secret_recovery_phrase');
  String get seedPhraseShareWarning => translate('seed_phrase_share_warning');
  String get tapToReveal => translate('tap_to_reveal');
  String get copyToClipboard => translate('copy_to_clipboard');
  String get beSureNoOneWatching => translate('be_sure_no_one_watching');
  String get verifyAllWords => translate('verify_all_words');
  String get seedPhraseMismatch => translate('seed_phrase_mismatch');
  String walletCreationError(String error) =>
      translate('wallet_creation_error').replaceFirst('{error}', error);
  String get referralsHeadline => translate('referrals_headline');
  String get referralsSubtitle => translate('referrals_subtitle');
  String get yourReferralCode => translate('your_referral_code');
  String get myCode => translate('my_code');
  String get myReferral => translate('my_referral');
  String get noReferral => translate('no_referral');
  String get rewardsEarned => translate('rewards_earned');
  String get referredUsers => translate('referred_users');
  String referredUsersCount(int count) =>
      translate('referred_users_count').replaceFirst('{count}', '$count');
  String get addReferral => translate('add_referral');
  String get enterReferralCode => translate('enter_referral_code');
  String get unableToLoadReferrals => translate('unable_to_load_referrals');
  String get enterReferralCodePrompt => translate('enter_referral_code_prompt');
  String get ownReferralCodeError => translate('own_referral_code_error');
  String get referralAdded => translate('referral_added');
  String get unableToAddReferral => translate('unable_to_add_referral');
  String get referralCodeCopied => translate('referral_code_copied');
  String get refresh => translate('refresh');
  String get backupSeedPhraseTitle => translate('backup_seed_phrase_title');
  String get authenticateToViewSeedPhrase =>
      translate('authenticate_to_view_seed_phrase');
  String get authenticationRequiredSeedPhrase =>
      translate('authentication_required_seed_phrase');
  String get securityWarning => translate('security_warning');
  String get seedPhraseMasterKeyWarning =>
      translate('seed_phrase_master_key_warning');
  String get seedPhraseSafetyBullets => translate('seed_phrase_safety_bullets');
  String get iUnderstand => translate('i_understand');
  String get noSeedPhraseStored => translate('no_seed_phrase_stored');
  String get seedPhraseCopied => translate('seed_phrase_copied');
  String get backupSeedPhraseIntro => translate('backup_seed_phrase_intro');

  // --- LANGUAGE STRINGS ---

  static const Map<String, String> _englishStrings = {
    'app_name': 'Owllet',
    'welcome_title': 'Hi, Welcome Owlian',
    'welcome_subtitle':
        'Create your secured wallet, back it up and jump right into the Owllet ecosystem',
    'create_wallet': 'Create Wallet',
    'import_wallet': 'Import Wallet',
    'choose_language': 'Choose your language',
    'choose_desired_language': 'Choose your desired language',
    'trade_instantly': 'Trade Instantly.',
    'spend_effortlessly': 'Spend Effortlessly.',
    'get_started': 'Get Started',
    'already_have_wallet': 'Already have a wallet?',
    'import_existing_wallet': 'Import existing wallet',
    'secret_phrase': 'Secret Phrase',
    'private_key': 'Private Key',
    'enter_passcode': 'Enter Passcode',
    'confirm_passcode': 'Confirm Passcode',
    'setup_biometric': 'Setup Biometric',
    'enable_face_id': 'Enable Face ID',
    'enable_fingerprint': 'Enable Fingerprint',
    'skip': 'Skip',
    'continue': 'Continue',
    'home': 'Home',
    'wallet': 'Wallet',
    'swap': 'Swap',
    'earn': 'Earn',
    'payment': 'Payment',
    'me': 'Me',
    'settings': 'Settings',
    'balance': 'Balance',
    'tokens': 'Tokens',
    'nfts': 'NFTs',
    'loading_balances': 'Loading balances...',
    'no_tokens_yet': 'No tokens yet',
    'deposit_tokens': 'Deposit tokens to get started',
    'total_balance': 'Total Balance',
    'nft_preview': 'NFT Preview',
    'view_all': 'View all',
    'no_nfts_found': 'No NFTs found',
    'nft_preview_description':
        'Your NFT preview will appear here on supported networks.',
    'send': 'Send',
    'receive': 'Receive',
    'buy': 'Buy',
    'sell': 'Sell',
    'wallets': 'Wallets',
    'active_wallet': 'ACTIVE WALLET',
    'add_wallet': 'Add Wallet',
    'create_new_wallet': 'Create New Wallet',
    'import_seed_phrase': 'Import Seed Phrase',
    'import_private_key': 'Import Private Key',
    'main_wallet': 'Main Wallet',
    'address_copied': 'Address copied!',
    'profile': 'Profile',
    'general': 'General',
    'manage_wallets': 'Manage Wallets',
    'switch_network': 'Switch Network',
    'currency': 'Currency',
    'choose_your_language': 'Choose Your Language',
    'referrals': 'Referrals',
    'security': 'Security',
    'others': 'Others',
    'password_security': 'Password & Security',
    'network': 'Network',
    'select_network': 'Select Network',
    'add_custom_network': 'Add Custom Network',
    'seed_phrase_backup': 'Seed Phrase Backup',
    'reset_wallet': 'Reset Wallet',
    'privacy_policy': 'Privacy Policy',
    'terms_of_service': 'Terms of Service',
    'feedback': 'Feedback',
    'join_our_community': 'Join Our Community',
    'reset_app': 'Reset App',
    'no_nfts_yet': 'No NFTs yet',
    'nft_collection': 'NFT Collection',
    'transaction_history': 'Transaction History',
    'notifications': 'Notifications',
    'transaction_broadcast': 'Transaction Broadcast!',
    'transaction_failed': 'Transaction failed',
    'confirm_transfer': 'Confirm Transfer',
    'gas_fee': 'Gas Fee',
    'transaction_details': 'TRANSACTION DETAILS',
    'transfer_warning_message':
        'Verify the recipient address carefully. Transactions are permanent and cannot be reversed.',
    'max_total': 'MAX TOTAL',
    'amount': 'AMOUNT',
    'estimation_failed': 'Estimation Failed',
    'network_error': 'Network error',
    'connection_failed': 'Connection failed. Please check your internet.',
    'try_again': 'Try Again',
    'coming_soon': 'Coming Soon',
    'congratulations': 'Congratulations!',
    'wallet_created': 'Your wallet has been created successfully',
    'wallet_imported': 'Your wallet has been imported successfully',
    'go_to_wallet': 'Go to Wallet',
    'reset_failed': 'Failed to reset app data. Please try again.',
    'confirm_clear_local_data':
        'This clears local wallet data on this device. Ensure your seed phrase is backed up.',
    'cancel': 'Cancel',
    'action_required': 'Action Required',
    'send_token': 'Send Token',
    'enter_receiving_address': 'Please enter a receiving address',
    'invalid_ethereum_address': 'Invalid Ethereum address',
    'enter_valid_amount': 'Please enter a valid amount',
    'insufficient_balance': 'Insufficient balance',
    'create_passcode_title': 'Create Passcode',
    'create_passcode_description':
        'Enter a 6 digit code that only you can remember',
    'confirm_passcode_title': 'Confirm Passcode',
    'confirm_passcode_description':
        'Confirm the digits you entered if they are correct',
    'failed_to_save_passcode': 'Failed to save passcode',
    'passcodes_do_not_match': 'Passcodes do not match. Please try again.',
    'unlock_wallet_reason': 'Unlock your wallet',
    'unlock_enter_passcode': 'Enter your passcode',
    'locked_out_title': 'Locked out',
    'unlock_try_again_in': 'Try again in {seconds}s',
    'attempts_remaining': '{count} attempts remaining',
    'incorrect_passcode_remaining':
        'Incorrect passcode. {count} attempts remaining.',
    'too_many_attempts_locked':
        'Too many failed attempts. Locked for {seconds} seconds.',
    'enter_passcode_title': 'Enter Passcode',
    'passcode_hint': 'Passcode',
    'wallet_name_label': 'Wallet name',
    'enter_wallet_name_hint': 'Enter wallet name',
    'enter_secret_phrase_hint': 'Enter your 12 or 24-word secret phrase',
    'secret_phrase_helper_text':
        'Your secret phrase is 12 or 24 words separated by single spaces',
    'paste': 'Paste',
    'wallet_imported_successfully': 'Wallet imported successfully!',
    'enter_secret_phrase_prompt': 'Please enter your secret phrase',
    'enter_wallet_name_prompt': 'Please enter a wallet name',
    'invalid_secret_phrase_prompt':
        'Invalid secret phrase. Please check and try again.',
    'import_wallet_failed': 'Failed to import wallet: {error}',
    'enter_private_key_prompt': 'Please enter your private key',
    'invalid_private_key_length':
        'Invalid private key. Must be 64 hexadecimal characters.',
    'invalid_private_key_characters':
        'Invalid private key. Must contain only hexadecimal characters (0-9, a-f).',
    'enter_private_key_hint': 'Enter your private key',
    'private_key_helper_text':
        'Your private key comprises of 64 alphanumeric characters',
    'incorrect_passcode': 'Incorrect passcode',
    'confirm': 'Confirm',
    'feedback_title': 'Feedback',
    'feedback_subtitle': 'Help us improve Owllet by sharing your thoughts.',
    'feedback_category': 'Category',
    'feedback_subject_optional': 'Subject (Optional)',
    'feedback_message': 'Message',
    'feedback_contact_email_optional': 'Contact Email (Optional)',
    'feedback_category_general': 'General',
    'feedback_category_bug': 'Bug Report',
    'feedback_category_feature': 'Feature Request',
    'feedback_category_design': 'Design Feedback',
    'feedback_subject_hint': 'Short summary',
    'feedback_message_hint': 'Tell us what happened or what you need',
    'feedback_email_hint': 'you@example.com',
    'submit_feedback': 'Submit Feedback',
    'enter_feedback_message': 'Please enter your feedback message',
    'no_active_wallet_found': 'No active wallet found',
    'feedback_submitted': 'Feedback submitted. Thank you.',
    'feedback_submit_failed': 'Unable to submit feedback. Please try again.',
    'manage_wallets_title': 'Manage Wallets',
    'create_add_wallet': 'Create / Add Wallet',
    'rename_wallet': 'Rename Wallet',
    'view_private_key': 'View Private Key',
    'remove_wallet': 'Remove Wallet',
    'save': 'Save',
    'wallet_renamed': 'Wallet renamed',
    'wallet_removed': 'Wallet removed',
    'unable_to_load_wallets': 'Unable to load wallets',
    'new_wallet_created': 'New wallet created',
    'unable_to_create_wallet': 'Unable to create wallet: {error}',
    'wallet_set_as_active': '{name} set as active',
    'unable_to_switch_wallet': 'Unable to switch wallet: {error}',
    'unable_to_rename_wallet': 'Unable to rename wallet: {error}',
    'unable_to_remove_wallet': 'Unable to remove wallet: {error}',
    'must_keep_one_wallet': 'You must keep at least one wallet',
    'remove_wallet_warning':
        'Remove this wallet from this device? This does not delete the wallet onchain.',
    'authentication_required': 'Authentication required',
    'no_private_key_found': 'No private key found',
    'private_key_security_warning':
        'Never share this with anyone. Anyone with this key can access your funds.',
    'active_wallet_label': 'Active wallet',
    'add_token': 'Add Token',
    'authenticate_to_view_private_key': 'Authenticate to view your private key',
    'unable_to_load_private_key': 'Unable to load private key: {error}',
    'manage_tokens': 'Manage Tokens',
    'visible_tokens': 'Visible Tokens',
    'added_tokens': 'Added Tokens',
    'suggested_tokens': 'Suggested Tokens',
    'search_results': 'Search Results',
    'no_tokens_detected_yet': 'No tokens detected for this wallet yet.',
    'no_matching_tokens_found': 'No matching tokens found.',
    'paste_contract_to_add_token':
        'Paste a contract address above to add a token instantly.',
    'no_suggested_tokens_yet': 'No suggested tokens available yet.',
    'no_remote_tokens_found': 'No remote tokens found.',
    'token_removed': 'Token removed',
    'token_already_available': 'Token already available in your list',
    'token_already_exists_on_network': 'Token already exists on this network',
    'token_added': '{symbol} added',
    'token_add_failed': 'Failed to add token: {error}',
    'missing_token_contract_address': 'Missing token contract address',
    'token_detected': 'Token Detected',
    'contract_address_label': 'Contract Address',
    'ignore': 'Ignore',
    'added': 'Added',
    'could_not_detect_token_metadata':
        'Could not detect token metadata from this contract on the selected network',
    'my_balance': 'MY BALANCE',
    'token_not_found': 'Token not found',
    'loading': 'Loading...',
    'copied_to_clipboard': 'Copied to clipboard',
    'password_security_title': 'Password & Security',
    'access_control': 'Access Control',
    'change_password': 'Change Password',
    'passcode_unlock': 'Passcode unlock',
    'biometrics_face_id': 'Biometrics / Face ID',
    'advanced_security': 'Advanced Security',
    'two_factor_auth': 'Two-Factor Authentication (2FA)',
    'on_label': 'On',
    'off_label': 'Off',
    'auto_lock_timer': 'Auto-Lock Timer',
    'auto_lock_minutes_label': '{minutes} minute(s)',
    'security_preferences_load_failed': 'Failed to load security preferences',
    'retry': 'Retry',
    'unable_to_update_biometric': 'Unable to update biometric setting',
    'unable_to_update_two_factor': 'Unable to update 2FA setting',
    'unable_to_update_auto_lock': 'Unable to update auto-lock setting',
    'security_summary':
        'Enable additional security measures to protect your digital assets from unauthorized access.',
    'search_token_or_paste_contract': 'Search token or paste contract address',
    'clear_search': 'Clear search',
    'create_wallet_copied_seed': 'Secret phrase copied to clipboard',
    'secret_recovery_phrase': 'Secret recovery phrase',
    'seed_phrase_share_warning':
        'Never share your seed phrase with anybody even your family members.',
    'tap_to_reveal': 'Tap to reveal',
    'copy_to_clipboard': 'Copy to clipboard',
    'be_sure_no_one_watching': 'Be sure no one is watching',
    'verify_all_words': 'Please fill in all 12 words',
    'seed_phrase_mismatch': 'The seed phrase does not match. Please try again.',
    'wallet_creation_error': 'Error creating wallet: {error}',
    'referrals_headline': 'Invite Friends and Earn Rewards Together',
    'referrals_subtitle':
        'Earn up to \$0.5 for every user you refer using your referral code.',
    'your_referral_code': 'YOUR REFERRAL CODE',
    'my_code': 'My Code',
    'my_referral': 'My Referral',
    'no_referral': 'No referral',
    'rewards_earned': 'Rewards Earned',
    'referred_users': 'Referred Users',
    'referred_users_count': '{count} users',
    'add_referral': 'Add Referral',
    'enter_referral_code': 'Enter referral code',
    'unable_to_load_referrals': 'Unable to load referrals',
    'enter_referral_code_prompt': 'Enter a referral code',
    'own_referral_code_error': 'You cannot use your own referral code',
    'referral_added': 'Referral added',
    'unable_to_add_referral': 'Unable to add referral',
    'referral_code_copied': 'Referral code copied',
    'refresh': 'Refresh',
    'backup_seed_phrase_title': 'Backup Seed Phrase',
    'authenticate_to_view_seed_phrase': 'Authenticate to view your seed phrase',
    'authentication_required_seed_phrase':
        'Authentication required to view seed phrase',
    'security_warning': 'Security Warning',
    'seed_phrase_master_key_warning':
        'Your seed phrase is the master key to your wallet. Anyone with it can move all your funds.',
    'seed_phrase_safety_bullets':
        '• Never share it with anyone\n• Never enter it on websites\n• Write it down and store it offline',
    'i_understand': 'I Understand',
    'no_seed_phrase_stored': 'No seed phrase stored for this wallet',
    'seed_phrase_copied': 'Seed phrase copied to clipboard',
    'backup_seed_phrase_intro':
        'Your 12-word recovery phrase is the only way to recover your wallet if you lose your phone or forget your password.',
  };

  static const Map<String, String> _spanishStrings = {
    'app_name': 'Owllet',
    'welcome_title': 'Hola, Bienvenido Owlian',
    'welcome_subtitle':
        'Crea tu billetera segura, respáldala y sumérgete en el ecosistema Owllet',
    'create_wallet': 'Crear Billetera',
    'import_wallet': 'Importar Billetera',
    'choose_language': 'Elige tu idioma',
    'choose_desired_language': 'Elige tu idioma deseado',
    'trade_instantly': 'Comercia Instantáneamente.',
    'spend_effortlessly': 'Gasta Sin Esfuerzo.',
    'get_started': 'Comenzar',
    'already_have_wallet': '¿Ya tienes una billetera?',
    'import_existing_wallet': 'Importar billetera existente',
    'secret_phrase': 'Frase Secreta',
    'private_key': 'Clave Privada',
    'enter_passcode': 'Ingresar Código',
    'confirm_passcode': 'Confirmar Código',
    'setup_biometric': 'Configurar Biométrico',
    'enable_face_id': 'Habilitar Face ID',
    'enable_fingerprint': 'Habilitar Huella',
    'skip': 'Omitir',
    'continue': 'Continuar',
    'home': 'Inicio',
    'wallet': 'Billetera',
    'swap': 'Intercambiar',
    'earn': 'Ganar',
    'payment': 'Pago',
    'me': 'Yo',
    'settings': 'Ajustes',
    'balance': 'Saldo',
    'tokens': 'Tokens',
    'nfts': 'NFTs',
    'loading_balances': 'Cargando saldos...',
    'no_tokens_yet': 'Todavía no hay tokens',
    'deposit_tokens': 'Deposita tokens para comenzar',
    'total_balance': 'Saldo Total',
    'nft_preview': 'Vista previa de NFT',
    'view_all': 'Ver todo',
    'no_nfts_found': 'No se encontraron NFTs',
    'nft_preview_description':
        'La vista previa de tus NFT aparecerá aquí en redes compatibles.',
    'send': 'Enviar',
    'receive': 'Recibir',
    'buy': 'Comprar',
    'sell': 'Vender',
    'wallets': 'Billeteras',
    'active_wallet': 'BILLETERA ACTIVA',
    'add_wallet': 'Agregar Billetera',
    'create_new_wallet': 'Crear Nueva Billetera',
    'import_seed_phrase': 'Importar Frase Semilla',
    'import_private_key': 'Importar Clave Privada',
    'main_wallet': 'Billetera Principal',
    'address_copied': '¡Dirección copiada!',
    'profile': 'Perfil',
    'general': 'General',
    'manage_wallets': 'Gestionar Billeteras',
    'switch_network': 'Cambiar Red',
    'currency': 'Moneda',
    'choose_your_language': 'Elige tu idioma',
    'referrals': 'Referidos',
    'security': 'Seguridad',
    'others': 'Otros',
    'password_security': 'Contraseña y Seguridad',
    'network': 'Red',
    'select_network': 'Seleccionar Red',
    'add_custom_network': 'Agregar Red Personalizada',
    'seed_phrase_backup': 'Respaldo de Frase',
    'reset_wallet': 'Restablecer Billetera',
    'privacy_policy': 'Política de Privacidad',
    'terms_of_service': 'Términos de Servicio',
    'feedback': 'Comentarios',
    'join_our_community': 'Únete a Nuestra Comunidad',
    'reset_app': 'Restablecer App',
    'no_nfts_yet': 'Todavía no hay NFTs',
    'nft_collection': 'Colección NFT',
    'transaction_history': 'Historial de Transacciones',
    'notifications': 'Notificaciones',
    'transaction_broadcast': '¡Transacción enviada!',
    'transaction_failed': 'Transacción fallida',
    'confirm_transfer': 'Confirmar Transferencia',
    'gas_fee': 'Tarifa de Gas',
    'transaction_details': 'DETALLES DE LA TRANSACCIÓN',
    'transfer_warning_message':
        'Verifique la dirección del destinatario cuidadosamente. Las transacciones son permanentes y no se pueden revertir.',
    'max_total': 'TOTAL MÁXIMO',
    'amount': 'CANTIDAD',
    'estimation_failed': 'Estimación fallida',
    'network_error': 'Error de red',
    'connection_failed': 'Conexión fallida. Verifique su internet.',
    'try_again': 'Reintentar',
    'coming_soon': 'Próximamente',
    'congratulations': '¡Felicitaciones!',
    'wallet_created': 'Tu billetera ha sido creada exitosamente',
    'wallet_imported': 'Tu billetera ha sido importada exitosamente',
    'go_to_wallet': 'Ir a Billetera',
    'reset_failed':
        'Error al restablecer los datos de la aplicación. Por favor, inténtalo de nuevo.',
    'confirm_clear_local_data':
        'Esto borra los datos de la billetera local en este dispositivo. Asegúrese de que su frase de recuperación esté respaldada.',
    'cancel': 'Cancelar',
    'action_required': 'Acción requerida',
  };

  static const Map<String, String> _frenchStrings = {
    'app_name': 'Owllet',
    'welcome_title': 'Bonjour, Bienvenue Owlian',
    'welcome_subtitle':
        'Créez votre portefeuille sécurisé, sauvegardez-le et plongez dans l\'écosystème Owllet',
    'create_wallet': 'Créer un Portefeuille',
    'import_wallet': 'Importer un Portefeuille',
    'choose_language': 'Choisissez votre langue',
    'choose_desired_language': 'Choisissez votre langue souhaitée',
    'trade_instantly': 'Échangez Instantanément.',
    'spend_effortlessly': 'Dépensez Sans Effort.',
    'get_started': 'Commencer',
    'already_have_wallet': 'Vous avez déjà un portefeuille?',
    'import_existing_wallet': 'Importer un portefeuille existant',
    'secret_phrase': 'Phrase Secrète',
    'private_key': 'Clé Privée',
    'enter_passcode': 'Entrer le Code',
    'confirm_passcode': 'Confirmer le Code',
    'setup_biometric': 'Configurer Biométrique',
    'enable_face_id': 'Activer Face ID',
    'enable_fingerprint': 'Activer Empreinte',
    'skip': 'Passer',
    'continue': 'Continuer',
    'home': 'Accueil',
    'wallet': 'Portefeuille',
    'swap': 'Échanger',
    'earn': 'Gagner',
    'payment': 'Paiement',
    'me': 'Moi',
    'settings': 'Paramètres',
    'balance': 'Solde',
    'tokens': 'Jetons',
    'nfts': 'NFTs',
    'loading_balances': 'Chargement des soldes...',
    'no_tokens_yet': 'Pas encore de jetons',
    'deposit_tokens': 'Déposez des jetons pour commencer',
    'total_balance': 'Solde Total',
    'nft_preview': 'Aperçu NFT',
    'view_all': 'Voir tout',
    'no_nfts_found': 'Aucun NFT trouvé',
    'nft_preview_description':
        'Votre aperçu NFT apparaîtra ici sur les réseaux pris en charge.',
    'send': 'Envoyer',
    'receive': 'Recevoir',
    'buy': 'Acheter',
    'sell': 'Vendre',
    'wallets': 'Portefeuilles',
    'active_wallet': 'PORTEFEUILLE ACTIF',
    'add_wallet': 'Ajouter un Portefeuille',
    'create_new_wallet': 'Créer un Nouveau Portefeuille',
    'import_seed_phrase': 'Importer une Phrase Secrète',
    'import_private_key': 'Importer une Clé Privée',
    'main_wallet': 'Portefeuille Principal',
    'address_copied': 'Adresse copiée!',
    'profile': 'Profil',
    'general': 'Général',
    'manage_wallets': 'Gérer les Portefeuilles',
    'switch_network': 'Changer de Réseau',
    'currency': 'Devise',
    'choose_your_language': 'Choisissez votre langue',
    'referrals': 'Parrainages',
    'security': 'Sécurité',
    'others': 'Autres',
    'password_security': 'Mot de passe et sécurité',
    'network': 'Réseau',
    'select_network': 'Sélectionner le Réseau',
    'add_custom_network': 'Ajouter un Réseau Personnalisé',
    'seed_phrase_backup': 'Sauvegarde de Phrase',
    'reset_wallet': 'Réinitialiser le Portefeuille',
    'privacy_policy': 'Politique de Confidentialité',
    'terms_of_service': 'Conditions d’utilisation',
    'feedback': 'Retour',
    'join_our_community': 'Rejoignez Notre Communauté',
    'reset_app': 'Réinitialiser l’application',
    'no_nfts_yet': 'Pas encore de NFTs',
    'nft_collection': 'Collection NFT',
    'transaction_history': 'Historique des Transactions',
    'notifications': 'Notifications',
    'transaction_broadcast': 'Transaction envoyée!',
    'transaction_failed': 'Transaction échouée',
    'confirm_transfer': 'Confirmer le Transfert',
    'gas_fee': 'Frais de Gas',
    'transaction_details': 'DÉTAILS DE LA TRANSACTION',
    'transfer_warning_message':
        'Vérifiez attentivement l\'adresse du destinataire. Les transactions sont permanentes et ne peuvent pas être annulées.',
    'max_total': 'TOTAL MAXIMUM',
    'amount': 'MONTANT',
    'estimation_failed': 'Estimation échouée',
    'network_error': 'Erreur réseau',
    'connection_failed': 'Connexion échouée. Vérifiez votre internet.',
    'try_again': 'Réessayer',
    'coming_soon': 'Bientôt Disponible',
    'congratulations': 'Félicitations!',
    'wallet_created': 'Votre portefeuille a été créé avec succès',
    'wallet_imported': 'Votre portefeuille a été importé avec succès',
    'go_to_wallet': 'Aller au Portefeuille',
    'reset_failed':
        'Échec de la réinitialisation des données de l\'application. Veuillez réessayer.',
    'confirm_clear_local_data':
        'Cela efface les données du portefeuille local sur cet appareil. Assurez-vous que votre phrase de récupération est sauvegardée.',
    'cancel': 'Annuler',
    'action_required': 'Action requise',
  };

  static const Map<String, String> _chineseStrings = {
    'app_name': 'Owllet',
    'welcome_title': '你好，欢迎 Owlian',
    'welcome_subtitle': '创建您的安全钱包，备份它，然后立即进入 Owllet 生态系统',
    'create_wallet': '创建钱包',
    'import_wallet': '导入钱包',
    'choose_language': '选择您的语言',
    'choose_desired_language': '选择您想要的语言',
    'trade_instantly': '即时交易。',
    'spend_effortlessly': '轻松消费。',
    'get_started': '开始使用',
    'already_have_wallet': '已有钱包？',
    'import_existing_wallet': '导入现有钱包',
    'secret_phrase': '助记词',
    'private_key': '私钥',
    'enter_passcode': '输入密码',
    'confirm_passcode': '确认密码',
    'setup_biometric': '设置生物识别',
    'enable_face_id': '启用面容 ID',
    'enable_fingerprint': '启用指纹',
    'skip': '跳过',
    'continue': '继续',
    'home': '首页',
    'wallet': '钱包',
    'swap': '兑换',
    'earn': '赚取',
    'payment': '支付',
    'me': '我',
    'settings': '设置',
    'balance': '余额',
    'tokens': '代币',
    'nfts': 'NFTs',
    'loading_balances': '加载余额中...',
    'no_tokens_yet': '暂无代币',
    'deposit_tokens': '存入代币开始使用',
    'total_balance': '总余额',
    'nft_preview': 'NFT 预览',
    'view_all': '查看全部',
    'no_nfts_found': '未找到 NFT',
    'nft_preview_description': '您的 NFT 预览将显示在支持的网络上。',
    'send': '发送',
    'receive': '接收',
    'buy': '购买',
    'sell': '出售',
    'wallets': '钱包管理',
    'active_wallet': '活跃钱包',
    'add_wallet': '添加钱包',
    'create_new_wallet': '创建新钱包',
    'import_seed_phrase': '导入助记词',
    'import_private_key': '导入私钥',
    'main_wallet': '主钱包',
    'address_copied': '地址已复制！',
    'profile': '个人资料',
    'general': '常规',
    'manage_wallets': '管理钱包',
    'switch_network': '切换网络',
    'currency': '货币',
    'choose_your_language': '选择语言',
    'referrals': '推荐',
    'security': '安全',
    'others': '其他',
    'password_security': '密码与安全',
    'network': '网络',
    'select_network': '选择网络',
    'add_custom_network': '添加自定义网络',
    'seed_phrase_backup': '助记词备份',
    'reset_wallet': '重置钱包',
    'privacy_policy': '隐私政策',
    'terms_of_service': '服务条款',
    'feedback': '反馈',
    'join_our_community': '加入社区',
    'reset_app': '重置应用',
    'no_nfts_yet': '暂无 NFT',
    'nft_collection': 'NFT 收藏',
    'transaction_history': '交易历史',
    'notifications': '通知',
    'transaction_broadcast': '交易已广播！',
    'transaction_failed': '交易失败',
    'confirm_transfer': '确认转账',
    'gas_fee': 'Gas 费用',
    'transaction_details': '交易详情',
    'transfer_warning_message': '请仔细核对收款地址。交易是永久性的，无法撤销。',
    'max_total': '最大总额',
    'amount': '金额',
    'estimation_failed': '估算失败',
    'network_error': '网络错误',
    'connection_failed': '连接失败，请检查网络。',
    'try_again': '重试',
    'coming_soon': '即将推出',
    'congratulations': '恭喜！',
    'wallet_created': '您的钱包已成功创建',
    'wallet_imported': '您的钱包已成功导入',
    'go_to_wallet': '前往钱包',
    'reset_failed': '重置应用数据失败。请再试一次。',
    'confirm_clear_local_data': '这将清除此设备上的本地钱包数据。请确保您的助记词已备份。',
    'cancel': '取消',
    'action_required': '需要操作',
  };

  static const Map<String, String> _arabicStrings = {
    'app_name': 'Owllet',
    'welcome_title': 'مرحباً يا Owlian',
    'welcome_subtitle':
        'أنشئ محفظتك الآمنة، قم بنسخها احتياطياً وانطلق في نظام Owllet البيئي',
    'create_wallet': 'إنشاء محفظة',
    'import_wallet': 'استيراد محفظة',
    'choose_language': 'اختر لغتك',
    'choose_desired_language': 'اختر اللغة المطلوبة',
    'trade_instantly': 'تداول فوري.',
    'spend_effortlessly': 'إنفاق سهل.',
    'get_started': 'ابدأ الآن',
    'already_have_wallet': 'هل لديك محفظة بالفعل؟',
    'import_existing_wallet': 'استيراد محفظة موجودة',
    'secret_phrase': 'العبارة السرية',
    'private_key': 'المفتاح الخاص',
    'enter_passcode': 'أدخل الرمز',
    'confirm_passcode': 'تأكيد الرمز',
    'setup_biometric': 'إعداد البيومترية',
    'enable_face_id': 'تفعيل Face ID',
    'enable_fingerprint': 'تفعيل البصمة',
    'skip': 'تخطي',
    'continue': 'متابعة',
    'home': 'الرئيسية',
    'wallet': 'المحفظة',
    'swap': 'تبديل',
    'earn': 'كسب',
    'payment': 'دفع',
    'me': 'أنا',
    'settings': 'الإعدادات',
    'balance': 'الرصيد',
    'tokens': 'الرموز',
    'nfts': 'NFTs',
    'loading_balances': 'جاري تحميل الأرصدة...',
    'no_tokens_yet': 'لا يوجد رموز بعد',
    'deposit_tokens': 'قم بإيداع الرموز للبدء',
    'total_balance': 'الرصيد الإجمالي',
    'nft_preview': 'معاينة NFT',
    'view_all': 'عرض الكل',
    'no_nfts_found': 'لم يتم العثور على NFTs',
    'nft_preview_description':
        'ستظهر معاينة NFT الخاصة بك هنا على الشبكات المدعومة.',
    'send': 'إرسال',
    'receive': 'استقبال',
    'buy': 'شراء',
    'sell': 'بيع',
    'wallets': 'المحافظ',
    'active_wallet': 'المحفظة النشطة',
    'add_wallet': 'إضافة محفظة',
    'create_new_wallet': 'إنشاء محفظة جديدة',
    'import_seed_phrase': 'استيراد عبارة سرية',
    'import_private_key': 'استيراد مفتاح خاص',
    'main_wallet': 'المحفظة الرئيسية',
    'address_copied': 'تم نسخ العنوان!',
    'profile': 'الملف الشخصي',
    'general': 'عام',
    'manage_wallets': 'إدارة المحافظ',
    'switch_network': 'تبديل الشبكة',
    'currency': 'العملة',
    'choose_your_language': 'اختر لغتك',
    'referrals': 'الإحالات',
    'security': 'الأمان',
    'others': 'أخرى',
    'password_security': 'كلمة المرور والأمان',
    'network': 'الشبكة',
    'select_network': 'اختر الشبكة',
    'add_custom_network': 'إضافة شبكة مخصصة',
    'seed_phrase_backup': 'نسخ العبارة السرية',
    'reset_wallet': 'إعادة تعيين المحفظة',
    'privacy_policy': 'سياسة الخصوصية',
    'terms_of_service': 'شروط الخدمة',
    'feedback': 'ملاحظات',
    'join_our_community': 'انضم إلى مجتمعنا',
    'reset_app': 'إعادة تعيين التطبيق',
    'no_nfts_yet': 'لا يوجد NFTs بعد',
    'nft_collection': 'مجموعة NFT',
    'transaction_history': 'سجل المعاملات',
    'notifications': 'الإشعارات',
    'transaction_broadcast': 'تم إرسال المعاملة!',
    'transaction_failed': 'فشلت المعاملة',
    'confirm_transfer': 'تأكيد التحويل',
    'gas_fee': 'رسوم الغاز',
    'transaction_details': 'تفاصيل المعاملة',
    'transfer_warning_message':
        'تحقق من عنوان المستلم بعناية. المعاملات دائمة ولا يمكن التراجع عنها.',
    'max_total': 'المجموع الأقصى',
    'amount': 'المبلغ',
    'estimation_failed': 'فشل التقدير',
    'network_error': 'خطأ في الشبكة',
    'connection_failed': 'فشل الاتصال. يرجى التحقق من الإنترنت.',
    'try_again': 'حاول مجدداً',
    'coming_soon': 'قريباً',
    'congratulations': 'تهانينا!',
    'wallet_created': 'تم إنشاء محفظتك بنجاح',
    'wallet_imported': 'تم استيراد محفظتك بنجاح',
    'go_to_wallet': 'الذهاب إلى المحفظة',
    'reset_failed':
        'فشل في إعادة تعيين بيانات التطبيق. يرجى المحاولة مرة أخرى.',
    'confirm_clear_local_data':
        'سيؤدي هذا إلى مسح بيانات المحفظة المحلية على هذا الجهاز. تأكد من الاحتفاظ بنسخة احتياطية من العبارة السرية.',
    'cancel': 'إلغاء',
    'action_required': 'مطلوب اتخاذ إجراء',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'es', 'fr', 'zh', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
