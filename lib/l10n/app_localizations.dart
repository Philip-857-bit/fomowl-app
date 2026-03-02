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
    'es': 'EspaÃ±ol',
    'fr': 'FranÃ§ais',
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
    return _localizedStrings[key] ?? key;
  }

  // â”€â”€â”€ Onboarding â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€â”€ Bottom Navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String get home => translate('home');
  String get wallet => translate('wallet');
  String get swap => translate('swap');
  String get earn => translate('earn');
  String get payment => translate('payment');
  String get me => translate('me');
  String get settings => translate('settings');

  // â”€â”€â”€ Home Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€â”€ Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String get send => translate('send');
  String get receive => translate('receive');
  String get buy => translate('buy');
  String get sell => translate('sell');

  // â”€â”€â”€ Wallets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String get wallets => translate('wallets');
  String get activeWallet => translate('active_wallet');
  String get addWallet => translate('add_wallet');
  String get createNewWallet => translate('create_new_wallet');
  String get importSeedPhrase => translate('import_seed_phrase');
  String get importPrivateKey => translate('import_private_key');
  String get mainWallet => translate('main_wallet');
  String get addressCopied => translate('address_copied');

  // â”€â”€â”€ Profile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€â”€ NFT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String get noNftsYet => translate('no_nfts_yet');
  String get nftCollection => translate('nft_collection');

  // â”€â”€â”€ Transactions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€â”€ Errors â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String get networkError => translate('network_error');
  String get connectionFailed => translate('connection_failed');
  String get tryAgain => translate('try_again');
  String get comingSoon => translate('coming_soon');

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // LANGUAGE STRINGS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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
    'network_error': 'Network error',
    'connection_failed': 'Connection failed. Please check your internet.',
    'try_again': 'Try Again',
    'coming_soon': 'Coming Soon',
    'congratulations': 'Congratulations!',
    'wallet_created': 'Your wallet has been created successfully',
    'wallet_imported': 'Your wallet has been imported successfully',
    'go_to_wallet': 'Go to Wallet',
  };

  static const Map<String, String> _spanishStrings = {
    'app_name': 'Owllet',
    'welcome_title': 'Hola, Bienvenido Owlian',
    'welcome_subtitle':
        'Crea tu billetera segura, respÃ¡ldala y sumÃ©rgete en el ecosistema Owllet',
    'create_wallet': 'Crear Billetera',
    'import_wallet': 'Importar Billetera',
    'choose_language': 'Elige tu idioma',
    'choose_desired_language': 'Elige tu idioma deseado',
    'trade_instantly': 'Comercia InstantÃ¡neamente.',
    'spend_effortlessly': 'Gasta Sin Esfuerzo.',
    'get_started': 'Comenzar',
    'already_have_wallet': 'Â¿Ya tienes una billetera?',
    'import_existing_wallet': 'Importar billetera existente',
    'secret_phrase': 'Frase Secreta',
    'private_key': 'Clave Privada',
    'enter_passcode': 'Ingresar CÃ³digo',
    'confirm_passcode': 'Confirmar CÃ³digo',
    'setup_biometric': 'Configurar BiomÃ©trico',
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
    'no_tokens_yet': 'TodavÃ­a no hay tokens',
    'deposit_tokens': 'Deposita tokens para comenzar',
    'total_balance': 'Saldo Total',
    'nft_preview': 'Vista previa de NFT',
    'view_all': 'Ver todo',
    'no_nfts_found': 'No se encontraron NFTs',
    'nft_preview_description':
        'La vista previa de tus NFT aparecerÃ¡ aquÃ­ en redes compatibles.',
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
    'address_copied': 'Â¡DirecciÃ³n copiada!',
    'profile': 'Perfil',
    'general': 'General',
    'manage_wallets': 'Gestionar Billeteras',
    'switch_network': 'Cambiar Red',
    'currency': 'Moneda',
    'choose_your_language': 'Elige tu idioma',
    'referrals': 'Referidos',
    'security': 'Seguridad',
    'others': 'Otros',
    'password_security': 'ContraseÃ±a y Seguridad',
    'network': 'Red',
    'select_network': 'Seleccionar Red',
    'add_custom_network': 'Agregar Red Personalizada',
    'seed_phrase_backup': 'Respaldo de Frase',
    'reset_wallet': 'Restablecer Billetera',
    'privacy_policy': 'PolÃ­tica de Privacidad',
    'terms_of_service': 'TÃ©rminos de Servicio',
    'feedback': 'Comentarios',
    'join_our_community': 'Ãšnete a Nuestra Comunidad',
    'reset_app': 'Restablecer App',
    'no_nfts_yet': 'TodavÃ­a no hay NFTs',
    'nft_collection': 'ColecciÃ³n NFT',
    'transaction_history': 'Historial de Transacciones',
    'notifications': 'Notificaciones',
    'transaction_broadcast': 'Â¡TransacciÃ³n enviada!',
    'transaction_failed': 'TransacciÃ³n fallida',
    'confirm_transfer': 'Confirmar Transferencia',
    'gas_fee': 'Tarifa de Gas',
    'transaction_details': 'DETALLES DE LA TRANSACCIÃ“N',
    'transfer_warning_message':
        'Verifique la direcciÃ³n del destinatario cuidadosamente. Las transacciones son permanentes y no se pueden revertir.',
    'max_total': 'TOTAL MÃXIMO',
    'amount': 'CANTIDAD',
    'network_error': 'Error de red',
    'connection_failed': 'ConexiÃ³n fallida. Verifique su internet.',
    'try_again': 'Reintentar',
    'coming_soon': 'PrÃ³ximamente',
    'congratulations': 'Â¡Felicitaciones!',
    'wallet_created': 'Tu billetera ha sido creada exitosamente',
    'wallet_imported': 'Tu billetera ha sido importada exitosamente',
    'go_to_wallet': 'Ir a Billetera',
  };

  static const Map<String, String> _frenchStrings = {
    'app_name': 'Owllet',
    'welcome_title': 'Bonjour, Bienvenue Owlian',
    'welcome_subtitle':
        'CrÃ©ez votre portefeuille sÃ©curisÃ©, sauvegardez-le et plongez dans l\'Ã©cosystÃ¨me Owllet',
    'create_wallet': 'CrÃ©er un Portefeuille',
    'import_wallet': 'Importer un Portefeuille',
    'choose_language': 'Choisissez votre langue',
    'choose_desired_language': 'Choisissez votre langue souhaitÃ©e',
    'trade_instantly': 'Ã‰changez InstantanÃ©ment.',
    'spend_effortlessly': 'DÃ©pensez Sans Effort.',
    'get_started': 'Commencer',
    'already_have_wallet': 'Vous avez dÃ©jÃ  un portefeuille?',
    'import_existing_wallet': 'Importer un portefeuille existant',
    'secret_phrase': 'Phrase SecrÃ¨te',
    'private_key': 'ClÃ© PrivÃ©e',
    'enter_passcode': 'Entrer le Code',
    'confirm_passcode': 'Confirmer le Code',
    'setup_biometric': 'Configurer BiomÃ©trique',
    'enable_face_id': 'Activer Face ID',
    'enable_fingerprint': 'Activer Empreinte',
    'skip': 'Passer',
    'continue': 'Continuer',
    'home': 'Accueil',
    'wallet': 'Portefeuille',
    'swap': 'Ã‰changer',
    'earn': 'Gagner',
    'payment': 'Paiement',
    'me': 'Moi',
    'settings': 'ParamÃ¨tres',
    'balance': 'Solde',
    'tokens': 'Jetons',
    'nfts': 'NFTs',
    'loading_balances': 'Chargement des soldes...',
    'no_tokens_yet': 'Pas encore de jetons',
    'deposit_tokens': 'DÃ©posez des jetons pour commencer',
    'total_balance': 'Solde Total',
    'nft_preview': 'AperÃ§u NFT',
    'view_all': 'Voir tout',
    'no_nfts_found': 'Aucun NFT trouvÃ©',
    'nft_preview_description':
        'Votre aperÃ§u NFT apparaÃ®tra ici sur les rÃ©seaux pris en charge.',
    'send': 'Envoyer',
    'receive': 'Recevoir',
    'buy': 'Acheter',
    'sell': 'Vendre',
    'wallets': 'Portefeuilles',
    'active_wallet': 'PORTEFEUILLE ACTIF',
    'add_wallet': 'Ajouter un Portefeuille',
    'create_new_wallet': 'CrÃ©er un Nouveau Portefeuille',
    'import_seed_phrase': 'Importer une Phrase SecrÃ¨te',
    'import_private_key': 'Importer une ClÃ© PrivÃ©e',
    'main_wallet': 'Portefeuille Principal',
    'address_copied': 'Adresse copiÃ©e!',
    'profile': 'Profil',
    'general': 'GÃ©nÃ©ral',
    'manage_wallets': 'GÃ©rer les Portefeuilles',
    'switch_network': 'Changer de RÃ©seau',
    'currency': 'Devise',
    'choose_your_language': 'Choisissez votre langue',
    'referrals': 'Parrainages',
    'security': 'SÃ©curitÃ©',
    'others': 'Autres',
    'password_security': 'Mot de passe et sÃ©curitÃ©',
    'network': 'RÃ©seau',
    'select_network': 'SÃ©lectionner le RÃ©seau',
    'add_custom_network': 'Ajouter un RÃ©seau PersonnalisÃ©',
    'seed_phrase_backup': 'Sauvegarde de Phrase',
    'reset_wallet': 'RÃ©initialiser le Portefeuille',
    'privacy_policy': 'Politique de ConfidentialitÃ©',
    'terms_of_service': 'Conditions dâ€™utilisation',
    'feedback': 'Retour',
    'join_our_community': 'Rejoignez Notre CommunautÃ©',
    'reset_app': 'RÃ©initialiser lâ€™application',
    'no_nfts_yet': 'Pas encore de NFTs',
    'nft_collection': 'Collection NFT',
    'transaction_history': 'Historique des Transactions',
    'notifications': 'Notifications',
    'transaction_broadcast': 'Transaction envoyÃ©e!',
    'transaction_failed': 'Transaction Ã©chouÃ©e',
    'confirm_transfer': 'Confirmer le Transfert',
    'gas_fee': 'Frais de Gas',
    'transaction_details': 'DÃ‰TAILS DE LA TRANSACTION',
    'transfer_warning_message':
        'VÃ©rifiez attentivement l\'adresse du destinataire. Les transactions sont permanentes et ne peuvent pas Ãªtre annulÃ©es.',
    'max_total': 'TOTAL MAXIMUM',
    'amount': 'MONTANT',
    'network_error': 'Erreur rÃ©seau',
    'connection_failed': 'Connexion Ã©chouÃ©e. VÃ©rifiez votre internet.',
    'try_again': 'RÃ©essayer',
    'coming_soon': 'BientÃ´t Disponible',
    'congratulations': 'FÃ©licitations!',
    'wallet_created': 'Votre portefeuille a Ã©tÃ© crÃ©Ã© avec succÃ¨s',
    'wallet_imported': 'Votre portefeuille a Ã©tÃ© importÃ© avec succÃ¨s',
    'go_to_wallet': 'Aller au Portefeuille',
  };

  static const Map<String, String> _chineseStrings = {
    'app_name': 'Owllet',
    'welcome_title': 'ä½ å¥½ï¼Œæ¬¢è¿Ž Owlian',
    'welcome_subtitle':
        'åˆ›å»ºæ‚¨çš„å®‰å…¨é’±åŒ…ï¼Œå¤‡ä»½å®ƒï¼Œç„¶åŽç«‹å³è¿›å…¥ Owllet ç”Ÿæ€ç³»ç»Ÿ',
    'create_wallet': 'åˆ›å»ºé’±åŒ…',
    'import_wallet': 'å¯¼å…¥é’±åŒ…',
    'choose_language': 'é€‰æ‹©æ‚¨çš„è¯­è¨€',
    'choose_desired_language': 'é€‰æ‹©æ‚¨æƒ³è¦çš„è¯­è¨€',
    'trade_instantly': 'å³æ—¶äº¤æ˜“ã€‚',
    'spend_effortlessly': 'è½»æ¾æ¶ˆè´¹ã€‚',
    'get_started': 'å¼€å§‹ä½¿ç”¨',
    'already_have_wallet': 'å·²æœ‰é’±åŒ…ï¼Ÿ',
    'import_existing_wallet': 'å¯¼å…¥çŽ°æœ‰é’±åŒ…',
    'secret_phrase': 'åŠ©è®°è¯',
    'private_key': 'ç§é’¥',
    'enter_passcode': 'è¾“å…¥å¯†ç ',
    'confirm_passcode': 'ç¡®è®¤å¯†ç ',
    'setup_biometric': 'è®¾ç½®ç”Ÿç‰©è¯†åˆ«',
    'enable_face_id': 'å¯ç”¨é¢å®¹ ID',
    'enable_fingerprint': 'å¯ç”¨æŒ‡çº¹',
    'skip': 'è·³è¿‡',
    'continue': 'ç»§ç»­',
    'home': 'é¦–é¡µ',
    'wallet': 'é’±åŒ…',
    'swap': 'å…‘æ¢',
    'earn': 'èµšå–',
    'payment': 'æ”¯ä»˜',
    'me': 'æˆ‘',
    'settings': 'è®¾ç½®',
    'balance': 'ä½™é¢',
    'tokens': 'ä»£å¸',
    'nfts': 'NFTs',
    'loading_balances': 'åŠ è½½ä½™é¢ä¸­...',
    'no_tokens_yet': 'æš‚æ— ä»£å¸',
    'deposit_tokens': 'å­˜å…¥ä»£å¸å¼€å§‹ä½¿ç”¨',
    'total_balance': 'æ€»ä½™é¢',
    'nft_preview': 'NFT é¢„è§ˆ',
    'view_all': 'æŸ¥çœ‹å…¨éƒ¨',
    'no_nfts_found': 'æœªæ‰¾åˆ° NFT',
    'nft_preview_description':
        'æ‚¨çš„ NFT é¢„è§ˆå°†æ˜¾ç¤ºåœ¨æ”¯æŒçš„ç½‘ç»œä¸Šã€‚',
    'send': 'å‘é€',
    'receive': 'æŽ¥æ”¶',
    'buy': 'è´­ä¹°',
    'sell': 'å‡ºå”®',
    'wallets': 'é’±åŒ…ç®¡ç†',
    'active_wallet': 'æ´»è·ƒé’±åŒ…',
    'add_wallet': 'æ·»åŠ é’±åŒ…',
    'create_new_wallet': 'åˆ›å»ºæ–°é’±åŒ…',
    'import_seed_phrase': 'å¯¼å…¥åŠ©è®°è¯',
    'import_private_key': 'å¯¼å…¥ç§é’¥',
    'main_wallet': 'ä¸»é’±åŒ…',
    'address_copied': 'åœ°å€å·²å¤åˆ¶ï¼',
    'profile': 'ä¸ªäººèµ„æ–™',
    'general': 'å¸¸è§„',
    'manage_wallets': 'ç®¡ç†é’±åŒ…',
    'switch_network': 'åˆ‡æ¢ç½‘ç»œ',
    'currency': 'è´§å¸',
    'choose_your_language': 'é€‰æ‹©è¯­è¨€',
    'referrals': 'æŽ¨è',
    'security': 'å®‰å…¨',
    'others': 'å…¶ä»–',
    'password_security': 'å¯†ç ä¸Žå®‰å…¨',
    'network': 'ç½‘ç»œ',
    'select_network': 'é€‰æ‹©ç½‘ç»œ',
    'add_custom_network': 'æ·»åŠ è‡ªå®šä¹‰ç½‘ç»œ',
    'seed_phrase_backup': 'åŠ©è®°è¯å¤‡ä»½',
    'reset_wallet': 'é‡ç½®é’±åŒ…',
    'privacy_policy': 'éšç§æ”¿ç­–',
    'terms_of_service': 'æœåŠ¡æ¡æ¬¾',
    'feedback': 'åé¦ˆ',
    'join_our_community': 'åŠ å…¥ç¤¾åŒº',
    'reset_app': 'é‡ç½®åº”ç”¨',
    'no_nfts_yet': 'æš‚æ—  NFT',
    'nft_collection': 'NFT æ”¶è—',
    'transaction_history': 'äº¤æ˜“åŽ†å²',
    'notifications': 'é€šçŸ¥',
    'transaction_broadcast': 'äº¤æ˜“å·²å¹¿æ’­ï¼',
    'transaction_failed': 'äº¤æ˜“å¤±è´¥',
    'confirm_transfer': 'ç¡®è®¤è½¬è´¦',
    'gas_fee': 'Gas è´¹ç”¨',
    'transaction_details': 'äº¤æ˜“è¯¦æƒ…',
    'transfer_warning_message':
        'è¯·ä»”ç»†æ ¸å¯¹æ”¶æ¬¾åœ°å€ã€‚äº¤æ˜“æ˜¯æ°¸ä¹…æ€§çš„ï¼Œæ— æ³•æ’¤é”€ã€‚',
    'max_total': 'æœ€å¤§æ€»é¢',
    'amount': 'é‡‘é¢',
    'network_error': 'ç½‘ç»œé”™è¯¯',

    'connection_failed': 'è¿žæŽ¥å¤±è´¥ï¼Œè¯·æ£€æŸ¥ç½‘ç»œã€‚',
    'try_again': 'é‡è¯•',
    'coming_soon': 'å³å°†æŽ¨å‡º',
    'congratulations': 'æ­å–œï¼',
    'wallet_created': 'æ‚¨çš„é’±åŒ…å·²æˆåŠŸåˆ›å»º',
    'wallet_imported': 'æ‚¨çš„é’±åŒ…å·²æˆåŠŸå¯¼å…¥',
    'go_to_wallet': 'å‰å¾€é’±åŒ…',
  };

  static const Map<String, String> _arabicStrings = {
    'app_name': 'Owllet',
    'welcome_title': 'Ù…Ø±Ø­Ø¨Ø§Ù‹ ÙŠØ§ Owlian',
    'welcome_subtitle':
        'Ø£Ù†Ø´Ø¦ Ù…Ø­ÙØ¸ØªÙƒ Ø§Ù„Ø¢Ù…Ù†Ø©ØŒ Ù‚Ù… Ø¨Ù†Ø³Ø®Ù‡Ø§ Ø§Ø­ØªÙŠØ§Ø·ÙŠØ§Ù‹ ÙˆØ§Ù†Ø·Ù„Ù‚ ÙÙŠ Ù†Ø¸Ø§Ù… Owllet Ø§Ù„Ø¨ÙŠØ¦ÙŠ',
    'create_wallet': 'Ø¥Ù†Ø´Ø§Ø¡ Ù…Ø­ÙØ¸Ø©',
    'import_wallet': 'Ø§Ø³ØªÙŠØ±Ø§Ø¯ Ù…Ø­ÙØ¸Ø©',
    'choose_language': 'Ø§Ø®ØªØ± Ù„ØºØªÙƒ',
    'choose_desired_language': 'Ø§Ø®ØªØ± Ø§Ù„Ù„ØºØ© Ø§Ù„Ù…Ø·Ù„ÙˆØ¨Ø©',
    'trade_instantly': 'ØªØ¯Ø§ÙˆÙ„ ÙÙˆØ±ÙŠ.',
    'spend_effortlessly': 'Ø¥Ù†ÙØ§Ù‚ Ø³Ù‡Ù„.',
    'get_started': 'Ø§Ø¨Ø¯Ø£ Ø§Ù„Ø¢Ù†',
    'already_have_wallet': 'Ù‡Ù„ Ù„Ø¯ÙŠÙƒ Ù…Ø­ÙØ¸Ø© Ø¨Ø§Ù„ÙØ¹Ù„ØŸ',
    'import_existing_wallet': 'Ø§Ø³ØªÙŠØ±Ø§Ø¯ Ù…Ø­ÙØ¸Ø© Ù…ÙˆØ¬ÙˆØ¯Ø©',
    'secret_phrase': 'Ø§Ù„Ø¹Ø¨Ø§Ø±Ø© Ø§Ù„Ø³Ø±ÙŠØ©',
    'private_key': 'Ø§Ù„Ù…ÙØªØ§Ø­ Ø§Ù„Ø®Ø§Øµ',
    'enter_passcode': 'Ø£Ø¯Ø®Ù„ Ø§Ù„Ø±Ù…Ø²',
    'confirm_passcode': 'ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø±Ù…Ø²',
    'setup_biometric': 'Ø¥Ø¹Ø¯Ø§Ø¯ Ø§Ù„Ø¨ÙŠÙˆÙ…ØªØ±ÙŠØ©',
    'enable_face_id': 'ØªÙØ¹ÙŠÙ„ Face ID',
    'enable_fingerprint': 'ØªÙØ¹ÙŠÙ„ Ø§Ù„Ø¨ØµÙ…Ø©',
    'skip': 'ØªØ®Ø·ÙŠ',
    'continue': 'Ù…ØªØ§Ø¨Ø¹Ø©',
    'home': 'Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠØ©',
    'wallet': 'Ø§Ù„Ù…Ø­ÙØ¸Ø©',
    'swap': 'ØªØ¨Ø¯ÙŠÙ„',
    'earn': 'ÙƒØ³Ø¨',
    'payment': 'Ø¯ÙØ¹',
    'me': 'Ø£Ù†Ø§',
    'settings': 'Ø§Ù„Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª',
    'balance': 'Ø§Ù„Ø±ØµÙŠØ¯',
    'tokens': 'Ø§Ù„Ø±Ù…ÙˆØ²',
    'nfts': 'NFTs',
    'loading_balances': 'Ø¬Ø§Ø±ÙŠ ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ø£Ø±ØµØ¯Ø©...',
    'no_tokens_yet': 'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø±Ù…ÙˆØ² Ø¨Ø¹Ø¯',
    'deposit_tokens': 'Ù‚Ù… Ø¨Ø¥ÙŠØ¯Ø§Ø¹ Ø§Ù„Ø±Ù…ÙˆØ² Ù„Ù„Ø¨Ø¯Ø¡',
    'total_balance': 'Ø§Ù„Ø±ØµÙŠØ¯ Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ',
    'nft_preview': 'Ù…Ø¹Ø§ÙŠÙ†Ø© NFT',
    'view_all': 'Ø¹Ø±Ø¶ Ø§Ù„ÙƒÙ„',
    'no_nfts_found': 'Ù„Ù… ÙŠØªÙ… Ø§Ù„Ø¹Ø«ÙˆØ± Ø¹Ù„Ù‰ NFTs',
    'nft_preview_description':
        'Ø³ØªØ¸Ù‡Ø± Ù…Ø¹Ø§ÙŠÙ†Ø© NFT Ø§Ù„Ø®Ø§ØµØ© Ø¨Ùƒ Ù‡Ù†Ø§ Ø¹Ù„Ù‰ Ø§Ù„Ø´Ø¨ÙƒØ§Øª Ø§Ù„Ù…Ø¯Ø¹ÙˆÙ…Ø©.',
    'send': 'Ø¥Ø±Ø³Ø§Ù„',
    'receive': 'Ø§Ø³ØªÙ‚Ø¨Ø§Ù„',
    'buy': 'Ø´Ø±Ø§Ø¡',
    'sell': 'Ø¨ÙŠØ¹',
    'wallets': 'Ø§Ù„Ù…Ø­Ø§ÙØ¸',
    'active_wallet': 'Ø§Ù„Ù…Ø­ÙØ¸Ø© Ø§Ù„Ù†Ø´Ø·Ø©',
    'add_wallet': 'Ø¥Ø¶Ø§ÙØ© Ù…Ø­ÙØ¸Ø©',
    'create_new_wallet': 'Ø¥Ù†Ø´Ø§Ø¡ Ù…Ø­ÙØ¸Ø© Ø¬Ø¯ÙŠØ¯Ø©',
    'import_seed_phrase': 'Ø§Ø³ØªÙŠØ±Ø§Ø¯ Ø¹Ø¨Ø§Ø±Ø© Ø³Ø±ÙŠØ©',
    'import_private_key': 'Ø§Ø³ØªÙŠØ±Ø§Ø¯ Ù…ÙØªØ§Ø­ Ø®Ø§Øµ',
    'main_wallet': 'Ø§Ù„Ù…Ø­ÙØ¸Ø© Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠØ©',
    'address_copied': 'ØªÙ… Ù†Ø³Ø® Ø§Ù„Ø¹Ù†ÙˆØ§Ù†!',
    'profile': 'Ø§Ù„Ù…Ù„Ù Ø§Ù„Ø´Ø®ØµÙŠ',
    'general': 'Ø¹Ø§Ù…',
    'manage_wallets': 'Ø¥Ø¯Ø§Ø±Ø© Ø§Ù„Ù…Ø­Ø§ÙØ¸',
    'switch_network': 'ØªØ¨Ø¯ÙŠÙ„ Ø§Ù„Ø´Ø¨ÙƒØ©',
    'currency': 'Ø§Ù„Ø¹Ù…Ù„Ø©',
    'choose_your_language': 'Ø§Ø®ØªØ± Ù„ØºØªÙƒ',
    'referrals': 'Ø§Ù„Ø¥Ø­Ø§Ù„Ø§Øª',
    'security': 'Ø§Ù„Ø£Ù…Ø§Ù†',
    'others': 'Ø£Ø®Ø±Ù‰',
    'password_security': 'ÙƒÙ„Ù…Ø© Ø§Ù„Ù…Ø±ÙˆØ± ÙˆØ§Ù„Ø£Ù…Ø§Ù†',
    'network': 'Ø§Ù„Ø´Ø¨ÙƒØ©',
    'select_network': 'Ø§Ø®ØªØ± Ø§Ù„Ø´Ø¨ÙƒØ©',
    'add_custom_network': 'Ø¥Ø¶Ø§ÙØ© Ø´Ø¨ÙƒØ© Ù…Ø®ØµØµØ©',
    'seed_phrase_backup': 'Ù†Ø³Ø® Ø§Ù„Ø¹Ø¨Ø§Ø±Ø© Ø§Ù„Ø³Ø±ÙŠØ©',
    'reset_wallet': 'Ø¥Ø¹Ø§Ø¯Ø© ØªØ¹ÙŠÙŠÙ† Ø§Ù„Ù…Ø­ÙØ¸Ø©',
    'privacy_policy': 'Ø³ÙŠØ§Ø³Ø© Ø§Ù„Ø®ØµÙˆØµÙŠØ©',
    'terms_of_service': 'Ø´Ø±ÙˆØ· Ø§Ù„Ø®Ø¯Ù…Ø©',
    'feedback': 'Ù…Ù„Ø§Ø­Ø¸Ø§Øª',
    'join_our_community': 'Ø§Ù†Ø¶Ù… Ø¥Ù„Ù‰ Ù…Ø¬ØªÙ…Ø¹Ù†Ø§',
    'reset_app': 'Ø¥Ø¹Ø§Ø¯Ø© ØªØ¹ÙŠÙŠÙ† Ø§Ù„ØªØ·Ø¨ÙŠÙ‚',
    'no_nfts_yet': 'Ù„Ø§ ÙŠÙˆØ¬Ø¯ NFTs Ø¨Ø¹Ø¯',
    'nft_collection': 'Ù…Ø¬Ù…ÙˆØ¹Ø© NFT',
    'transaction_history': 'Ø³Ø¬Ù„ Ø§Ù„Ù…Ø¹Ø§Ù…Ù„Ø§Øª',
    'notifications': 'Ø§Ù„Ø¥Ø´Ø¹Ø§Ø±Ø§Øª',
    'transaction_broadcast': 'ØªÙ… Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ù…Ø¹Ø§Ù…Ù„Ø©!',
    'transaction_failed': 'ÙØ´Ù„Øª Ø§Ù„Ù…Ø¹Ø§Ù…Ù„Ø©',
    'confirm_transfer': 'ØªØ£ÙƒÙŠØ¯ Ø§Ù„ØªØ­ÙˆÙŠÙ„',
    'gas_fee': 'Ø±Ø³ÙˆÙ… Ø§Ù„ØºØ§Ø²',
    'transaction_details': 'ØªÙØ§ØµÙŠÙ„ Ø§Ù„Ù…Ø¹Ø§Ù…Ù„Ø©',
    'transfer_warning_message':
        'ØªØ­Ù‚Ù‚ Ù…Ù† Ø¹Ù†ÙˆØ§Ù† Ø§Ù„Ù…Ø³ØªÙ„Ù… Ø¨Ø¹Ù†Ø§ÙŠØ©. Ø§Ù„Ù…Ø¹Ø§Ù…Ù„Ø§Øª Ø¯Ø§Ø¦Ù…Ø© ÙˆÙ„Ø§ ÙŠÙ…ÙƒÙ† Ø§Ù„ØªØ±Ø§Ø¬Ø¹ Ø¹Ù†Ù‡Ø§.',
    'max_total': 'Ø§Ù„Ù…Ø¬Ù…ÙˆØ¹ Ø§Ù„Ø£Ù‚ØµÙ‰',
    'amount': 'Ø§Ù„Ù…Ø¨Ù„Øº',
    'network_error': 'Ø®Ø·Ø£ ÙÙŠ Ø§Ù„Ø´Ø¨ÙƒØ©',
    'connection_failed':
        'ÙØ´Ù„ Ø§Ù„Ø§ØªØµØ§Ù„. ÙŠØ±Ø¬Ù‰ Ø§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„Ø¥Ù†ØªØ±Ù†Øª.',
    'try_again': 'Ø­Ø§ÙˆÙ„ Ù…Ø¬Ø¯Ø¯Ø§Ù‹',
    'coming_soon': 'Ù‚Ø±ÙŠØ¨Ø§Ù‹',
    'congratulations': 'ØªÙ‡Ø§Ù†ÙŠÙ†Ø§!',
    'wallet_created': 'ØªÙ… Ø¥Ù†Ø´Ø§Ø¡ Ù…Ø­ÙØ¸ØªÙƒ Ø¨Ù†Ø¬Ø§Ø­',
    'wallet_imported': 'ØªÙ… Ø§Ø³ØªÙŠØ±Ø§Ø¯ Ù…Ø­ÙØ¸ØªÙƒ Ø¨Ù†Ø¬Ø§Ø­',
    'go_to_wallet': 'Ø§Ù„Ø°Ù‡Ø§Ø¨ Ø¥Ù„Ù‰ Ø§Ù„Ù…Ø­ÙØ¸Ø©',
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
