import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ha.dart';
import 'app_localizations_ig.dart';
import 'app_localizations_yo.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ha'),
    Locale('ig'),
    Locale('yo'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Owllet'**
  String get appName;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Hi, Welcome Owlian'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your secured wallet, back it up and jump right into the Owllet ecosystem'**
  String get welcomeSubtitle;

  /// No description provided for @createWallet.
  ///
  /// In en, this message translates to:
  /// **'Create Wallet'**
  String get createWallet;

  /// No description provided for @importWallet.
  ///
  /// In en, this message translates to:
  /// **'Import Wallet'**
  String get importWallet;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @chooseDesiredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your desired language'**
  String get chooseDesiredLanguage;

  /// No description provided for @tradeInstantly.
  ///
  /// In en, this message translates to:
  /// **'Trade Instantly.'**
  String get tradeInstantly;

  /// No description provided for @spendEffortlessly.
  ///
  /// In en, this message translates to:
  /// **'Spend Effortlessly.'**
  String get spendEffortlessly;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @alreadyHaveWallet.
  ///
  /// In en, this message translates to:
  /// **'Already have a wallet?'**
  String get alreadyHaveWallet;

  /// No description provided for @importExistingWallet.
  ///
  /// In en, this message translates to:
  /// **'Import existing wallet'**
  String get importExistingWallet;

  /// No description provided for @secretPhrase.
  ///
  /// In en, this message translates to:
  /// **'Secret Phrase'**
  String get secretPhrase;

  /// No description provided for @privateKey.
  ///
  /// In en, this message translates to:
  /// **'Private Key'**
  String get privateKey;

  /// No description provided for @enterPasscode.
  ///
  /// In en, this message translates to:
  /// **'Enter Passcode'**
  String get enterPasscode;

  /// No description provided for @confirmPasscode.
  ///
  /// In en, this message translates to:
  /// **'Confirm Passcode'**
  String get confirmPasscode;

  /// No description provided for @setupBiometric.
  ///
  /// In en, this message translates to:
  /// **'Setup Biometric'**
  String get setupBiometric;

  /// No description provided for @enableFaceId.
  ///
  /// In en, this message translates to:
  /// **'Enable Face ID'**
  String get enableFaceId;

  /// No description provided for @enableFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Enable Fingerprint'**
  String get enableFingerprint;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @continue_.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continue_;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @swap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swap;

  /// No description provided for @earn.
  ///
  /// In en, this message translates to:
  /// **'Earn'**
  String get earn;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @tokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get tokens;

  /// No description provided for @nfts.
  ///
  /// In en, this message translates to:
  /// **'NFTs'**
  String get nfts;

  /// No description provided for @loadingBalances.
  ///
  /// In en, this message translates to:
  /// **'Loading balances...'**
  String get loadingBalances;

  /// No description provided for @noTokensYet.
  ///
  /// In en, this message translates to:
  /// **'No tokens yet'**
  String get noTokensYet;

  /// No description provided for @depositTokens.
  ///
  /// In en, this message translates to:
  /// **'Deposit tokens to get started'**
  String get depositTokens;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get totalBalance;

  /// No description provided for @nftPreview.
  ///
  /// In en, this message translates to:
  /// **'NFT Preview'**
  String get nftPreview;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @noNftsFound.
  ///
  /// In en, this message translates to:
  /// **'No NFTs found'**
  String get noNftsFound;

  /// No description provided for @nftPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Your NFT preview will appear here on supported networks.'**
  String get nftPreviewDescription;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @addFunds.
  ///
  /// In en, this message translates to:
  /// **'Buy Crypto'**
  String get addFunds;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sell;

  /// No description provided for @wallets.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get wallets;

  /// No description provided for @activeWallet.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE WALLET'**
  String get activeWallet;

  /// No description provided for @addWallet.
  ///
  /// In en, this message translates to:
  /// **'Add Wallet'**
  String get addWallet;

  /// No description provided for @createNewWallet.
  ///
  /// In en, this message translates to:
  /// **'Create New Wallet'**
  String get createNewWallet;

  /// No description provided for @importSeedPhrase.
  ///
  /// In en, this message translates to:
  /// **'Import Seed Phrase'**
  String get importSeedPhrase;

  /// No description provided for @importPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Import Private Key'**
  String get importPrivateKey;

  /// No description provided for @mainWallet.
  ///
  /// In en, this message translates to:
  /// **'Main Wallet'**
  String get mainWallet;

  /// No description provided for @addressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied!'**
  String get addressCopied;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @manageWallets.
  ///
  /// In en, this message translates to:
  /// **'Manage Wallets'**
  String get manageWallets;

  /// No description provided for @switchNetwork.
  ///
  /// In en, this message translates to:
  /// **'Switch Network'**
  String get switchNetwork;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @chooseYourLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Language'**
  String get chooseYourLanguage;

  /// No description provided for @referrals.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get referrals;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @others.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get others;

  /// No description provided for @passwordSecurity.
  ///
  /// In en, this message translates to:
  /// **'Password & Security'**
  String get passwordSecurity;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// No description provided for @selectNetwork.
  ///
  /// In en, this message translates to:
  /// **'Select Network'**
  String get selectNetwork;

  /// No description provided for @addCustomNetwork.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Network'**
  String get addCustomNetwork;

  /// No description provided for @seedPhraseBackup.
  ///
  /// In en, this message translates to:
  /// **'Seed Phrase Backup'**
  String get seedPhraseBackup;

  /// No description provided for @resetWallet.
  ///
  /// In en, this message translates to:
  /// **'Reset Wallet'**
  String get resetWallet;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover DApps'**
  String get discoverTitle;

  /// No description provided for @discoverProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'FOMOWL Products'**
  String get discoverProductsTitle;

  /// No description provided for @discoverExploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get discoverExploreTitle;

  /// No description provided for @discoverSearchResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get discoverSearchResultsTitle;

  /// No description provided for @discoverOpenOwlletPay.
  ///
  /// In en, this message translates to:
  /// **'Open OwlletPay'**
  String get discoverOpenOwlletPay;

  /// No description provided for @discoverProductsEmpty.
  ///
  /// In en, this message translates to:
  /// **'New FOMOWL products will appear here.'**
  String get discoverProductsEmpty;

  /// No description provided for @discoverOwlletPayPromoDescription.
  ///
  /// In en, this message translates to:
  /// **'Fund, shop, pay bills and withdraw in one place.'**
  String get discoverOwlletPayPromoDescription;

  /// No description provided for @discoverSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search DApps or the web'**
  String get discoverSearchHint;

  /// No description provided for @discoverWebSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'DuckDuckGo search'**
  String get discoverWebSearchTitle;

  /// No description provided for @discoverBrowserFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discoverBrowserFallbackTitle;

  /// No description provided for @discoverCatalogLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load Discover right now.'**
  String get discoverCatalogLoadError;

  /// No description provided for @discoverTrendingTokensLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load trending tokens right now.'**
  String get discoverTrendingTokensLoadError;

  /// No description provided for @discoverBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked in Owllet'**
  String get discoverBlockedTitle;

  /// No description provided for @discoverRequestSupport.
  ///
  /// In en, this message translates to:
  /// **'Request support'**
  String get discoverRequestSupport;

  /// No description provided for @discoverOpenExternalBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open external browser'**
  String get discoverOpenExternalBrowser;

  /// No description provided for @discoverCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get discoverCancel;

  /// No description provided for @discoverTrendingTokensTitle.
  ///
  /// In en, this message translates to:
  /// **'Trending Tokens'**
  String get discoverTrendingTokensTitle;

  /// No description provided for @discoverTrendingTokensSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live market movers pulled from Owllet pricing.'**
  String get discoverTrendingTokensSubtitle;

  /// No description provided for @discoverFeaturedDappsTitle.
  ///
  /// In en, this message translates to:
  /// **'Featured DApps'**
  String get discoverFeaturedDappsTitle;

  /// No description provided for @discoverFeaturedDappsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Curated DApps approved for Owllet wallet access.'**
  String get discoverFeaturedDappsSubtitle;

  /// No description provided for @discoverTrendingDappsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get discoverTrendingDappsTitle;

  /// No description provided for @discoverTrendingDappsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Popular trusted destinations.'**
  String get discoverTrendingDappsSubtitle;

  /// No description provided for @discoverCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get discoverCategoriesTitle;

  /// No description provided for @discoverCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Curated categories for approved wallet-enabled DApps.'**
  String get discoverCategoriesSubtitle;

  /// No description provided for @discoverAllApprovedDappsTitle.
  ///
  /// In en, this message translates to:
  /// **'All approved DApps'**
  String get discoverAllApprovedDappsTitle;

  /// No description provided for @discoverAllApprovedDappsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No DApps matched your search.'**
  String get discoverAllApprovedDappsNoMatches;

  /// No description provided for @discoverAllApprovedDappsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} trusted destinations.'**
  String discoverAllApprovedDappsCount(Object count);

  /// No description provided for @discoverCashInBadge.
  ///
  /// In en, this message translates to:
  /// **'ONE-TIME KYC'**
  String get discoverCashInBadge;

  /// No description provided for @discoverCashInTitle.
  ///
  /// In en, this message translates to:
  /// **'OwlletPay'**
  String get discoverCashInTitle;

  /// No description provided for @discoverCashInDescription.
  ///
  /// In en, this message translates to:
  /// **'Buy crypto or move funds in once the deposit flow is ready.'**
  String get discoverCashInDescription;

  /// No description provided for @discoverGoLabel.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get discoverGoLabel;

  /// No description provided for @discoverNoTrendingTokens.
  ///
  /// In en, this message translates to:
  /// **'No trending tokens are available right now.'**
  String get discoverNoTrendingTokens;

  /// No description provided for @discoverManualInputInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid website or search term.'**
  String get discoverManualInputInvalid;

  /// No description provided for @discoverInvalidLaunchUrl.
  ///
  /// In en, this message translates to:
  /// **'The DApp launch URL is invalid.'**
  String get discoverInvalidLaunchUrl;

  /// No description provided for @discoverUnsupportedScheme.
  ///
  /// In en, this message translates to:
  /// **'This website scheme is not supported in the in-app browser.'**
  String get discoverUnsupportedScheme;

  /// No description provided for @discoverBlockedReason.
  ///
  /// In en, this message translates to:
  /// **'This site attempted to access Owllet wallet APIs through {trigger}, but the origin is not approved for in-app wallet access.'**
  String discoverBlockedReason(Object trigger);

  /// No description provided for @discoverWalletApiAccessTrigger.
  ///
  /// In en, this message translates to:
  /// **'wallet provider access'**
  String get discoverWalletApiAccessTrigger;

  /// No description provided for @discoverSupportSubject.
  ///
  /// In en, this message translates to:
  /// **'Discover access request'**
  String get discoverSupportSubject;

  /// No description provided for @discoverSupportMessage.
  ///
  /// In en, this message translates to:
  /// **'Please review this DApp for Owllet Discover.\n\nOrigin: {origin}\nURL: {url}\nReason shown: {reason}'**
  String discoverSupportMessage(Object origin, Object url, Object reason);

  /// No description provided for @discoverCategoryDex.
  ///
  /// In en, this message translates to:
  /// **'Exchanges'**
  String get discoverCategoryDex;

  /// No description provided for @discoverCategoryDefi.
  ///
  /// In en, this message translates to:
  /// **'DeFi'**
  String get discoverCategoryDefi;

  /// No description provided for @discoverCategorySwap.
  ///
  /// In en, this message translates to:
  /// **'Swaps'**
  String get discoverCategorySwap;

  /// No description provided for @discoverCategoryLending.
  ///
  /// In en, this message translates to:
  /// **'Lending'**
  String get discoverCategoryLending;

  /// No description provided for @discoverCategoryNft.
  ///
  /// In en, this message translates to:
  /// **'NFT'**
  String get discoverCategoryNft;

  /// No description provided for @discoverCategoryMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get discoverCategoryMarketplace;

  /// No description provided for @discoverCategoryCollectibles.
  ///
  /// In en, this message translates to:
  /// **'Collectibles'**
  String get discoverCategoryCollectibles;

  /// No description provided for @joinOurCommunity.
  ///
  /// In en, this message translates to:
  /// **'Join Our Community'**
  String get joinOurCommunity;

  /// No description provided for @resetApp.
  ///
  /// In en, this message translates to:
  /// **'Reset App'**
  String get resetApp;

  /// No description provided for @noNftsYet.
  ///
  /// In en, this message translates to:
  /// **'No NFTs yet'**
  String get noNftsYet;

  /// No description provided for @nftCollection.
  ///
  /// In en, this message translates to:
  /// **'NFT Collection'**
  String get nftCollection;

  /// No description provided for @nftGalleryScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning for NFTs...'**
  String get nftGalleryScanning;

  /// No description provided for @nftGalleryEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Your NFT collection will appear here.\nBuy or receive NFTs on any supported chain.'**
  String get nftGalleryEmptyDescription;

  /// No description provided for @nftGalleryUnsupportedChain.
  ///
  /// In en, this message translates to:
  /// **'NFT gallery is not supported on {chain} yet.\nSwitch to Ethereum, BNB Smart Chain, Polygon, Arbitrum, Optimism, or Base.'**
  String nftGalleryUnsupportedChain(Object chain);

  /// No description provided for @failedToLoadNftsTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load NFTs'**
  String get failedToLoadNftsTitle;

  /// No description provided for @failedToLoadNftsWithError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load NFTs: {error}'**
  String failedToLoadNftsWithError(Object error);

  /// No description provided for @officialProjectNft.
  ///
  /// In en, this message translates to:
  /// **'Official Project NFT'**
  String get officialProjectNft;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @allLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allLabel;

  /// No description provided for @allChains.
  ///
  /// In en, this message translates to:
  /// **'All Chains'**
  String get allChains;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationsSettings;

  /// No description provided for @enablePushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Push Notifications'**
  String get enablePushNotifications;

  /// No description provided for @pushNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Receive alerts for deposits, transfers, and security updates.'**
  String get pushNotificationsDesc;

  /// No description provided for @transactionBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Transaction Broadcast!'**
  String get transactionBroadcast;

  /// No description provided for @transactionFailed.
  ///
  /// In en, this message translates to:
  /// **'Transaction failed'**
  String get transactionFailed;

  /// No description provided for @confirmTransfer.
  ///
  /// In en, this message translates to:
  /// **'Confirm Transfer'**
  String get confirmTransfer;

  /// No description provided for @gasFee.
  ///
  /// In en, this message translates to:
  /// **'Gas Fee'**
  String get gasFee;

  /// No description provided for @transactionDetails.
  ///
  /// In en, this message translates to:
  /// **'TRANSACTION DETAILS'**
  String get transactionDetails;

  /// No description provided for @closeLabel.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeLabel;

  /// No description provided for @viewOnExplorer.
  ///
  /// In en, this message translates to:
  /// **'View on Explorer'**
  String get viewOnExplorer;

  /// No description provided for @unknownNetwork.
  ///
  /// In en, this message translates to:
  /// **'Unknown network'**
  String get unknownNetwork;

  /// No description provided for @walletHistoryFallbackWarning.
  ///
  /// In en, this message translates to:
  /// **'Showing explorer history for the active chain while wallet history is unavailable.'**
  String get walletHistoryFallbackWarning;

  /// No description provided for @walletHistoryLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load wallet history right now.'**
  String get walletHistoryLoadError;

  /// No description provided for @walletHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No wallet history yet'**
  String get walletHistoryEmpty;

  /// No description provided for @historyTransferReceived.
  ///
  /// In en, this message translates to:
  /// **'Transfer received'**
  String get historyTransferReceived;

  /// No description provided for @historyTransferSent.
  ///
  /// In en, this message translates to:
  /// **'Transfer sent'**
  String get historyTransferSent;

  /// No description provided for @historyReceivedAmountOnNetwork.
  ///
  /// In en, this message translates to:
  /// **'Received {amount} on {network}.'**
  String historyReceivedAmountOnNetwork(Object amount, Object network);

  /// No description provided for @historySentAmountOnNetwork.
  ///
  /// In en, this message translates to:
  /// **'Sent {amount} on {network}.'**
  String historySentAmountOnNetwork(Object amount, Object network);

  /// No description provided for @historySwapOnNetwork.
  ///
  /// In en, this message translates to:
  /// **'Swap activity on {network}.'**
  String historySwapOnNetwork(Object network);

  /// No description provided for @historyActivityOnNetwork.
  ///
  /// In en, this message translates to:
  /// **'Activity on {network}.'**
  String historyActivityOnNetwork(Object network);

  /// No description provided for @historyTimestampLabel.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get historyTimestampLabel;

  /// No description provided for @historyTransactionHashLabel.
  ///
  /// In en, this message translates to:
  /// **'Transaction Hash'**
  String get historyTransactionHashLabel;

  /// No description provided for @historyReceiptUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Receipt details are not available for this history item yet.'**
  String get historyReceiptUnavailable;

  /// No description provided for @historyLoadingReceipt.
  ///
  /// In en, this message translates to:
  /// **'Loading receipt details...'**
  String get historyLoadingReceipt;

  /// No description provided for @historyReceiptLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load receipt details right now.'**
  String get historyReceiptLoadError;

  /// No description provided for @historyReceiptPending.
  ///
  /// In en, this message translates to:
  /// **'Receipt not available yet. The transaction may still be pending or unavailable from this RPC.'**
  String get historyReceiptPending;

  /// No description provided for @historyStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get historyStatusLabel;

  /// No description provided for @historyBlockNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Block Number'**
  String get historyBlockNumberLabel;

  /// No description provided for @historyFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get historyFromLabel;

  /// No description provided for @historyToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get historyToLabel;

  /// No description provided for @historyGasUsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Gas Used'**
  String get historyGasUsedLabel;

  /// No description provided for @historyGasPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Gas Price'**
  String get historyGasPriceLabel;

  /// No description provided for @historyContractAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Contract Address'**
  String get historyContractAddressLabel;

  /// No description provided for @historyLogCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get historyLogCountLabel;

  /// No description provided for @tokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get tokenLabel;

  /// No description provided for @confirmedLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmedLabel;

  /// No description provided for @failedLabel.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failedLabel;

  /// No description provided for @pendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingLabel;

  /// No description provided for @swapPreparingTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing swap...'**
  String get swapPreparingTitle;

  /// No description provided for @swapPreparingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We are preparing your swap request.'**
  String get swapPreparingSubtitle;

  /// No description provided for @swapApprovalProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Approval is processing...'**
  String get swapApprovalProcessingTitle;

  /// No description provided for @swapApprovalProcessingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Approve the token spend and wait for blockchain confirmation.'**
  String get swapApprovalProcessingSubtitle;

  /// No description provided for @swapSubmittingTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitting swap...'**
  String get swapSubmittingTitle;

  /// No description provided for @swapSubmittingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your swap transaction is being submitted to the network.'**
  String get swapSubmittingSubtitle;

  /// No description provided for @swapGaslessSubmittingTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitting gasless order...'**
  String get swapGaslessSubmittingTitle;

  /// No description provided for @swapGaslessSubmittingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Owllet is submitting your gasless order to the relayer.'**
  String get swapGaslessSubmittingSubtitle;

  /// No description provided for @swapProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction is Processing...'**
  String get swapProcessingTitle;

  /// No description provided for @swapProcessingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This may take a few minutes, blockchain validation is undergoing.'**
  String get swapProcessingSubtitle;

  /// No description provided for @swapGaslessProcessingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Owllet is relaying your order and waiting for blockchain confirmation.'**
  String get swapGaslessProcessingSubtitle;

  /// No description provided for @swapCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Swap completed'**
  String get swapCompletedTitle;

  /// No description provided for @swapCompletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your transaction has been confirmed successfully.'**
  String get swapCompletedSubtitle;

  /// No description provided for @swapFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Swap failed'**
  String get swapFailedTitle;

  /// No description provided for @noQuoteAvailable.
  ///
  /// In en, this message translates to:
  /// **'No quote available'**
  String get noQuoteAvailable;

  /// No description provided for @noRouterQuoteAvailable.
  ///
  /// In en, this message translates to:
  /// **'No router quote available'**
  String get noRouterQuoteAvailable;

  /// No description provided for @approvalPendingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Approval is still pending confirmation. Please check later.'**
  String get approvalPendingConfirmation;

  /// No description provided for @transactionPendingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Transaction pending confirmation. Please check later.'**
  String get transactionPendingConfirmation;

  /// No description provided for @gaslessOrderFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Gasless order failed. Please try again.'**
  String get gaslessOrderFailedRetry;

  /// No description provided for @swapMissingHash.
  ///
  /// In en, this message translates to:
  /// **'Swap submitted but transaction hash was not returned. Please check activity later.'**
  String get swapMissingHash;

  /// No description provided for @transferPreparingTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing transfer...'**
  String get transferPreparingTitle;

  /// No description provided for @transferApprovalPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer approval pending'**
  String get transferApprovalPendingTitle;

  /// No description provided for @transferSubmittingTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitting transfer...'**
  String get transferSubmittingTitle;

  /// No description provided for @transferInProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer in progress'**
  String get transferInProgressTitle;

  /// No description provided for @transferCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer completed'**
  String get transferCompletedTitle;

  /// No description provided for @transferFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer failed'**
  String get transferFailedTitle;

  /// No description provided for @transferPreparingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your transfer is being prepared for submission.'**
  String get transferPreparingSubtitle;

  /// No description provided for @transferApprovalPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please wait while the network processes the approval.'**
  String get transferApprovalPendingSubtitle;

  /// No description provided for @transferSubmittingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your transfer is being broadcast to the network.'**
  String get transferSubmittingSubtitle;

  /// No description provided for @transferInProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the network to confirm your transfer.'**
  String get transferInProgressSubtitle;

  /// No description provided for @transferCompletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your transfer has been confirmed successfully.'**
  String get transferCompletedSubtitle;

  /// No description provided for @genericTransactionPreparingTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing transaction...'**
  String get genericTransactionPreparingTitle;

  /// No description provided for @genericTransactionApprovalPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Approval pending'**
  String get genericTransactionApprovalPendingTitle;

  /// No description provided for @genericTransactionSubmittingTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitting transaction...'**
  String get genericTransactionSubmittingTitle;

  /// No description provided for @genericTransactionInProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction in progress'**
  String get genericTransactionInProgressTitle;

  /// No description provided for @genericTransactionCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction completed'**
  String get genericTransactionCompletedTitle;

  /// No description provided for @genericTransactionPreparingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your transaction is being prepared.'**
  String get genericTransactionPreparingSubtitle;

  /// No description provided for @genericTransactionApprovalPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please wait while the network processes the approval.'**
  String get genericTransactionApprovalPendingSubtitle;

  /// No description provided for @genericTransactionSubmittingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your transaction is being broadcast to the network.'**
  String get genericTransactionSubmittingSubtitle;

  /// No description provided for @genericTransactionInProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the network to confirm your transaction.'**
  String get genericTransactionInProgressSubtitle;

  /// No description provided for @genericTransactionCompletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your transaction has been confirmed successfully.'**
  String get genericTransactionCompletedSubtitle;

  /// No description provided for @transferWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Verify the recipient address carefully. Transactions are permanent and cannot be reversed.'**
  String get transferWarningMessage;

  /// No description provided for @maxTotal.
  ///
  /// In en, this message translates to:
  /// **'MAX TOTAL'**
  String get maxTotal;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'AMOUNT'**
  String get amount;

  /// No description provided for @estimationFailed.
  ///
  /// In en, this message translates to:
  /// **'Estimation Failed'**
  String get estimationFailed;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get networkError;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Please check your internet.'**
  String get connectionFailed;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @congratulations.
  ///
  /// In en, this message translates to:
  /// **'Congratulations!'**
  String get congratulations;

  /// No description provided for @walletCreated.
  ///
  /// In en, this message translates to:
  /// **'Your wallet has been created successfully'**
  String get walletCreated;

  /// No description provided for @walletImported.
  ///
  /// In en, this message translates to:
  /// **'Your wallet has been imported successfully'**
  String get walletImported;

  /// No description provided for @goToWallet.
  ///
  /// In en, this message translates to:
  /// **'Go to Wallet'**
  String get goToWallet;

  /// No description provided for @resetFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to reset app data. Please try again.'**
  String get resetFailed;

  /// No description provided for @confirmClearLocalData.
  ///
  /// In en, this message translates to:
  /// **'This clears local wallet data on this device. Ensure your seed phrase is backed up.'**
  String get confirmClearLocalData;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @actionRequired.
  ///
  /// In en, this message translates to:
  /// **'Action Required'**
  String get actionRequired;

  /// No description provided for @sendToken.
  ///
  /// In en, this message translates to:
  /// **'Send Token'**
  String get sendToken;

  /// No description provided for @enterReceivingAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter a receiving address'**
  String get enterReceivingAddress;

  /// No description provided for @invalidEthereumAddress.
  ///
  /// In en, this message translates to:
  /// **'Invalid Ethereum address'**
  String get invalidEthereumAddress;

  /// No description provided for @enterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get enterValidAmount;

  /// No description provided for @insufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get insufficientBalance;

  /// No description provided for @createPasscodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Passcode'**
  String get createPasscodeTitle;

  /// No description provided for @createPasscodeDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6 digit code that only you can remember'**
  String get createPasscodeDescription;

  /// No description provided for @confirmPasscodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Passcode'**
  String get confirmPasscodeTitle;

  /// No description provided for @confirmPasscodeDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm the digits you entered if they are correct'**
  String get confirmPasscodeDescription;

  /// No description provided for @failedToSavePasscode.
  ///
  /// In en, this message translates to:
  /// **'Failed to save passcode'**
  String get failedToSavePasscode;

  /// No description provided for @passcodesDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passcodes do not match. Please try again.'**
  String get passcodesDoNotMatch;

  /// No description provided for @unlockWalletReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock your wallet'**
  String get unlockWalletReason;

  /// No description provided for @unlockEnterPasscode.
  ///
  /// In en, this message translates to:
  /// **'Enter your passcode'**
  String get unlockEnterPasscode;

  /// No description provided for @lockedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Locked out'**
  String get lockedOutTitle;

  /// No description provided for @unlockTryAgainIn.
  ///
  /// In en, this message translates to:
  /// **'Try again in {seconds}s'**
  String unlockTryAgainIn(Object seconds);

  /// No description provided for @attemptsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} attempts remaining'**
  String attemptsRemaining(Object count);

  /// No description provided for @incorrectPasscodeRemaining.
  ///
  /// In en, this message translates to:
  /// **'Incorrect passcode. {count} attempts remaining.'**
  String incorrectPasscodeRemaining(Object count);

  /// No description provided for @tooManyAttemptsLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Locked for {seconds} seconds.'**
  String tooManyAttemptsLocked(Object seconds);

  /// No description provided for @enterPasscodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Passcode'**
  String get enterPasscodeTitle;

  /// No description provided for @passcodeHint.
  ///
  /// In en, this message translates to:
  /// **'Passcode'**
  String get passcodeHint;

  /// No description provided for @walletNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet name'**
  String get walletNameLabel;

  /// No description provided for @enterWalletNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter wallet name'**
  String get enterWalletNameHint;

  /// No description provided for @enterSecretPhraseHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your 12 or 24-word secret phrase'**
  String get enterSecretPhraseHint;

  /// No description provided for @secretPhraseHelperText.
  ///
  /// In en, this message translates to:
  /// **'Your secret phrase is 12 or 24 words separated by single spaces'**
  String get secretPhraseHelperText;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @walletImportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Wallet imported successfully!'**
  String get walletImportedSuccessfully;

  /// No description provided for @enterSecretPhrasePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter your secret phrase'**
  String get enterSecretPhrasePrompt;

  /// No description provided for @enterWalletNamePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter a wallet name'**
  String get enterWalletNamePrompt;

  /// No description provided for @invalidSecretPhrasePrompt.
  ///
  /// In en, this message translates to:
  /// **'Invalid secret phrase. Please check and try again.'**
  String get invalidSecretPhrasePrompt;

  /// No description provided for @importWalletFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import wallet: {error}'**
  String importWalletFailed(Object error);

  /// No description provided for @enterPrivateKeyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter your private key'**
  String get enterPrivateKeyPrompt;

  /// No description provided for @invalidPrivateKeyLength.
  ///
  /// In en, this message translates to:
  /// **'Invalid private key. Must be 64 hexadecimal characters.'**
  String get invalidPrivateKeyLength;

  /// No description provided for @invalidPrivateKeyCharacters.
  ///
  /// In en, this message translates to:
  /// **'Invalid private key. Must contain only hexadecimal characters (0-9, a-f).'**
  String get invalidPrivateKeyCharacters;

  /// No description provided for @enterPrivateKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your private key'**
  String get enterPrivateKeyHint;

  /// No description provided for @privateKeyHelperText.
  ///
  /// In en, this message translates to:
  /// **'Your private key comprises of 64 alphanumeric characters'**
  String get privateKeyHelperText;

  /// No description provided for @incorrectPasscode.
  ///
  /// In en, this message translates to:
  /// **'Incorrect passcode'**
  String get incorrectPasscode;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @feedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedbackTitle;

  /// No description provided for @feedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us improve Owllet by sharing your thoughts.'**
  String get feedbackSubtitle;

  /// No description provided for @feedbackCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get feedbackCategory;

  /// No description provided for @feedbackSubjectOptional.
  ///
  /// In en, this message translates to:
  /// **'Subject (Optional)'**
  String get feedbackSubjectOptional;

  /// No description provided for @feedbackMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get feedbackMessage;

  /// No description provided for @feedbackContactEmailOptional.
  ///
  /// In en, this message translates to:
  /// **'Contact Email (Optional)'**
  String get feedbackContactEmailOptional;

  /// No description provided for @feedbackCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get feedbackCategoryGeneral;

  /// No description provided for @feedbackCategoryBug.
  ///
  /// In en, this message translates to:
  /// **'Bug Report'**
  String get feedbackCategoryBug;

  /// No description provided for @feedbackCategoryFeature.
  ///
  /// In en, this message translates to:
  /// **'Feature Request'**
  String get feedbackCategoryFeature;

  /// No description provided for @feedbackCategoryDesign.
  ///
  /// In en, this message translates to:
  /// **'Design Feedback'**
  String get feedbackCategoryDesign;

  /// No description provided for @feedbackCategoryDappRequest.
  ///
  /// In en, this message translates to:
  /// **'DApp request'**
  String get feedbackCategoryDappRequest;

  /// No description provided for @feedbackSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'Short summary'**
  String get feedbackSubjectHint;

  /// No description provided for @feedbackMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what happened or what you need'**
  String get feedbackMessageHint;

  /// No description provided for @feedbackEmailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get feedbackEmailHint;

  /// No description provided for @submitFeedback.
  ///
  /// In en, this message translates to:
  /// **'Submit Feedback'**
  String get submitFeedback;

  /// No description provided for @enterFeedbackMessage.
  ///
  /// In en, this message translates to:
  /// **'Please enter your feedback message'**
  String get enterFeedbackMessage;

  /// No description provided for @noActiveWalletFound.
  ///
  /// In en, this message translates to:
  /// **'No active wallet found'**
  String get noActiveWalletFound;

  /// No description provided for @feedbackSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Feedback submitted. Thank you.'**
  String get feedbackSubmitted;

  /// No description provided for @feedbackSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to submit feedback. Please try again.'**
  String get feedbackSubmitFailed;

  /// No description provided for @manageWalletsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Wallets'**
  String get manageWalletsTitle;

  /// No description provided for @createAddWallet.
  ///
  /// In en, this message translates to:
  /// **'Create / Add Wallet'**
  String get createAddWallet;

  /// No description provided for @renameWallet.
  ///
  /// In en, this message translates to:
  /// **'Rename Wallet'**
  String get renameWallet;

  /// No description provided for @viewPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'View Private Key'**
  String get viewPrivateKey;

  /// No description provided for @removeWallet.
  ///
  /// In en, this message translates to:
  /// **'Remove Wallet'**
  String get removeWallet;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @walletRenamed.
  ///
  /// In en, this message translates to:
  /// **'Wallet renamed'**
  String get walletRenamed;

  /// No description provided for @walletRemoved.
  ///
  /// In en, this message translates to:
  /// **'Wallet removed'**
  String get walletRemoved;

  /// No description provided for @unableToLoadWallets.
  ///
  /// In en, this message translates to:
  /// **'Unable to load wallets'**
  String get unableToLoadWallets;

  /// No description provided for @newWalletCreated.
  ///
  /// In en, this message translates to:
  /// **'New wallet created'**
  String get newWalletCreated;

  /// No description provided for @unableToCreateWallet.
  ///
  /// In en, this message translates to:
  /// **'Unable to create wallet: {error}'**
  String unableToCreateWallet(Object error);

  /// No description provided for @walletSetAsActive.
  ///
  /// In en, this message translates to:
  /// **'{name} set as active'**
  String walletSetAsActive(Object name);

  /// No description provided for @unableToSwitchWallet.
  ///
  /// In en, this message translates to:
  /// **'Unable to switch wallet: {error}'**
  String unableToSwitchWallet(Object error);

  /// No description provided for @unableToRenameWallet.
  ///
  /// In en, this message translates to:
  /// **'Unable to rename wallet: {error}'**
  String unableToRenameWallet(Object error);

  /// No description provided for @unableToRemoveWallet.
  ///
  /// In en, this message translates to:
  /// **'Unable to remove wallet: {error}'**
  String unableToRemoveWallet(Object error);

  /// No description provided for @mustKeepOneWallet.
  ///
  /// In en, this message translates to:
  /// **'You must keep at least one wallet'**
  String get mustKeepOneWallet;

  /// No description provided for @removeWalletWarning.
  ///
  /// In en, this message translates to:
  /// **'Remove this wallet from this device? This does not delete the wallet onchain.'**
  String get removeWalletWarning;

  /// No description provided for @authenticationRequired.
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get authenticationRequired;

  /// No description provided for @noPrivateKeyFound.
  ///
  /// In en, this message translates to:
  /// **'No private key found'**
  String get noPrivateKeyFound;

  /// No description provided for @privateKeySecurityWarning.
  ///
  /// In en, this message translates to:
  /// **'Never share this with anyone. Anyone with this key can access your funds.'**
  String get privateKeySecurityWarning;

  /// No description provided for @activeWalletLabel.
  ///
  /// In en, this message translates to:
  /// **'Active wallet'**
  String get activeWalletLabel;

  /// No description provided for @addToken.
  ///
  /// In en, this message translates to:
  /// **'Add Token'**
  String get addToken;

  /// No description provided for @authenticateToViewPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to view your private key'**
  String get authenticateToViewPrivateKey;

  /// No description provided for @unableToLoadPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Unable to load private key: {error}'**
  String unableToLoadPrivateKey(Object error);

  /// No description provided for @manageTokens.
  ///
  /// In en, this message translates to:
  /// **'Manage Tokens'**
  String get manageTokens;

  /// No description provided for @visibleTokens.
  ///
  /// In en, this message translates to:
  /// **'Visible Tokens'**
  String get visibleTokens;

  /// No description provided for @addedTokens.
  ///
  /// In en, this message translates to:
  /// **'Added Tokens'**
  String get addedTokens;

  /// No description provided for @suggestedTokens.
  ///
  /// In en, this message translates to:
  /// **'Suggested Tokens'**
  String get suggestedTokens;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get searchResults;

  /// No description provided for @noTokensDetectedYet.
  ///
  /// In en, this message translates to:
  /// **'No tokens detected for this wallet yet.'**
  String get noTokensDetectedYet;

  /// No description provided for @noMatchingTokensFound.
  ///
  /// In en, this message translates to:
  /// **'No matching tokens found.'**
  String get noMatchingTokensFound;

  /// No description provided for @pasteContractToAddToken.
  ///
  /// In en, this message translates to:
  /// **'Paste a contract address above to add a token instantly.'**
  String get pasteContractToAddToken;

  /// No description provided for @noSuggestedTokensYet.
  ///
  /// In en, this message translates to:
  /// **'No suggested tokens available yet.'**
  String get noSuggestedTokensYet;

  /// No description provided for @noRemoteTokensFound.
  ///
  /// In en, this message translates to:
  /// **'No remote tokens found.'**
  String get noRemoteTokensFound;

  /// No description provided for @tokenRemoved.
  ///
  /// In en, this message translates to:
  /// **'Token removed'**
  String get tokenRemoved;

  /// No description provided for @tokenAlreadyAvailable.
  ///
  /// In en, this message translates to:
  /// **'Token already available in your list'**
  String get tokenAlreadyAvailable;

  /// No description provided for @tokenAlreadyExistsOnNetwork.
  ///
  /// In en, this message translates to:
  /// **'Token already exists on this network'**
  String get tokenAlreadyExistsOnNetwork;

  /// No description provided for @tokenAdded.
  ///
  /// In en, this message translates to:
  /// **'{symbol} added'**
  String tokenAdded(Object symbol);

  /// No description provided for @tokenAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add token: {error}'**
  String tokenAddFailed(Object error);

  /// No description provided for @missingTokenContractAddress.
  ///
  /// In en, this message translates to:
  /// **'Missing token contract address'**
  String get missingTokenContractAddress;

  /// No description provided for @tokenDetected.
  ///
  /// In en, this message translates to:
  /// **'Token Detected'**
  String get tokenDetected;

  /// No description provided for @contractAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Contract Address'**
  String get contractAddressLabel;

  /// No description provided for @ignore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignore;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get added;

  /// No description provided for @couldNotDetectTokenMetadata.
  ///
  /// In en, this message translates to:
  /// **'Could not detect token metadata from this contract on the selected network'**
  String get couldNotDetectTokenMetadata;

  /// No description provided for @myBalance.
  ///
  /// In en, this message translates to:
  /// **'MY BALANCE'**
  String get myBalance;

  /// No description provided for @tokenNotFound.
  ///
  /// In en, this message translates to:
  /// **'Token not found'**
  String get tokenNotFound;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @passwordSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Password & Security'**
  String get passwordSecurityTitle;

  /// No description provided for @accessControl.
  ///
  /// In en, this message translates to:
  /// **'Access Control'**
  String get accessControl;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @passcodeUnlock.
  ///
  /// In en, this message translates to:
  /// **'Passcode unlock'**
  String get passcodeUnlock;

  /// No description provided for @biometricsFaceId.
  ///
  /// In en, this message translates to:
  /// **'Biometrics / Face ID'**
  String get biometricsFaceId;

  /// No description provided for @advancedSecurity.
  ///
  /// In en, this message translates to:
  /// **'Advanced Security'**
  String get advancedSecurity;

  /// No description provided for @twoFactorAuth.
  ///
  /// In en, this message translates to:
  /// **'Two-Factor Authentication (2FA)'**
  String get twoFactorAuth;

  /// No description provided for @onLabel.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get onLabel;

  /// No description provided for @offLabel.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get offLabel;

  /// No description provided for @autoLockTimer.
  ///
  /// In en, this message translates to:
  /// **'Auto-Lock Timer'**
  String get autoLockTimer;

  /// No description provided for @foregroundAutoLockTimer.
  ///
  /// In en, this message translates to:
  /// **'Foreground Auto-Lock Timer'**
  String get foregroundAutoLockTimer;

  /// No description provided for @autoLockMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minute(s)'**
  String autoLockMinutesLabel(Object minutes);

  /// No description provided for @lockOnBackground.
  ///
  /// In en, this message translates to:
  /// **'Lock on Background'**
  String get lockOnBackground;

  /// No description provided for @immediateWhenAppIsHidden.
  ///
  /// In en, this message translates to:
  /// **'Immediate when app is hidden'**
  String get immediateWhenAppIsHidden;

  /// No description provided for @securityPreferencesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load security preferences'**
  String get securityPreferencesLoadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @unableToUpdateBiometric.
  ///
  /// In en, this message translates to:
  /// **'Unable to update biometric setting'**
  String get unableToUpdateBiometric;

  /// No description provided for @unableToUpdateTwoFactor.
  ///
  /// In en, this message translates to:
  /// **'Unable to update 2FA setting'**
  String get unableToUpdateTwoFactor;

  /// No description provided for @unableToUpdateAutoLock.
  ///
  /// In en, this message translates to:
  /// **'Unable to update auto-lock setting'**
  String get unableToUpdateAutoLock;

  /// No description provided for @unableToUpdateBackgroundLock.
  ///
  /// In en, this message translates to:
  /// **'Unable to update background lock setting'**
  String get unableToUpdateBackgroundLock;

  /// No description provided for @securitySummary.
  ///
  /// In en, this message translates to:
  /// **'Enable additional security measures to protect your digital assets from unauthorized access.'**
  String get securitySummary;

  /// No description provided for @searchTokenOrPasteContract.
  ///
  /// In en, this message translates to:
  /// **'Search token or paste contract address'**
  String get searchTokenOrPasteContract;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @createWalletCopiedSeed.
  ///
  /// In en, this message translates to:
  /// **'Secret phrase copied to clipboard'**
  String get createWalletCopiedSeed;

  /// No description provided for @secretRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Secret recovery phrase'**
  String get secretRecoveryPhrase;

  /// No description provided for @seedPhraseShareWarning.
  ///
  /// In en, this message translates to:
  /// **'Never share your seed phrase with anybody even your family members.'**
  String get seedPhraseShareWarning;

  /// No description provided for @tapToReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal'**
  String get tapToReveal;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get copyToClipboard;

  /// No description provided for @beSureNoOneWatching.
  ///
  /// In en, this message translates to:
  /// **'Be sure no one is watching'**
  String get beSureNoOneWatching;

  /// No description provided for @verifyAllWords.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all 12 words'**
  String get verifyAllWords;

  /// No description provided for @seedPhraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'The seed phrase does not match. Please try again.'**
  String get seedPhraseMismatch;

  /// No description provided for @walletCreationError.
  ///
  /// In en, this message translates to:
  /// **'Error creating wallet: {error}'**
  String walletCreationError(Object error);

  /// No description provided for @referralsHeadline.
  ///
  /// In en, this message translates to:
  /// **'Invite Friends and Earn Rewards Together'**
  String get referralsHeadline;

  /// No description provided for @referralsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Earn up to \$0.5 when a referred user completes their first qualifying \$10+ swap.'**
  String get referralsSubtitle;

  /// No description provided for @yourReferralCode.
  ///
  /// In en, this message translates to:
  /// **'YOUR REFERRAL CODE'**
  String get yourReferralCode;

  /// No description provided for @myCode.
  ///
  /// In en, this message translates to:
  /// **'My Code'**
  String get myCode;

  /// No description provided for @myReferral.
  ///
  /// In en, this message translates to:
  /// **'My Referral'**
  String get myReferral;

  /// No description provided for @noReferral.
  ///
  /// In en, this message translates to:
  /// **'No referral'**
  String get noReferral;

  /// No description provided for @rewardsEarned.
  ///
  /// In en, this message translates to:
  /// **'Rewards Earned'**
  String get rewardsEarned;

  /// No description provided for @claimableRewards.
  ///
  /// In en, this message translates to:
  /// **'Claimable Rewards'**
  String get claimableRewards;

  /// No description provided for @referredUsers.
  ///
  /// In en, this message translates to:
  /// **'Referred Users'**
  String get referredUsers;

  /// No description provided for @referredUsersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} users'**
  String referredUsersCount(Object count);

  /// No description provided for @claimReferralRewards.
  ///
  /// In en, this message translates to:
  /// **'Claim Referral Rewards'**
  String get claimReferralRewards;

  /// No description provided for @referralPayoutsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Referral payouts are not available yet.'**
  String get referralPayoutsUnavailable;

  /// No description provided for @referralClaimThreshold.
  ///
  /// In en, this message translates to:
  /// **'Minimum payout: \${amount}'**
  String referralClaimThreshold(Object amount);

  /// No description provided for @referralClaimSuccess.
  ///
  /// In en, this message translates to:
  /// **'Referral payout of \${amount} sent to your wallet'**
  String referralClaimSuccess(Object amount);

  /// No description provided for @addReferral.
  ///
  /// In en, this message translates to:
  /// **'Add Referral'**
  String get addReferral;

  /// No description provided for @enterReferralCode.
  ///
  /// In en, this message translates to:
  /// **'Enter referral code'**
  String get enterReferralCode;

  /// No description provided for @unableToLoadReferrals.
  ///
  /// In en, this message translates to:
  /// **'Unable to load referrals'**
  String get unableToLoadReferrals;

  /// No description provided for @unableToClaimReferralRewards.
  ///
  /// In en, this message translates to:
  /// **'Unable to claim referral rewards'**
  String get unableToClaimReferralRewards;

  /// No description provided for @enterReferralCodePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter a referral code'**
  String get enterReferralCodePrompt;

  /// No description provided for @ownReferralCodeError.
  ///
  /// In en, this message translates to:
  /// **'You cannot use your own referral code'**
  String get ownReferralCodeError;

  /// No description provided for @referralAdded.
  ///
  /// In en, this message translates to:
  /// **'Referral added'**
  String get referralAdded;

  /// No description provided for @unableToAddReferral.
  ///
  /// In en, this message translates to:
  /// **'Unable to add referral'**
  String get unableToAddReferral;

  /// No description provided for @referralCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Referral code copied'**
  String get referralCodeCopied;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @backupSeedPhraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup Seed Phrase'**
  String get backupSeedPhraseTitle;

  /// No description provided for @authenticateToViewSeedPhrase.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to view your seed phrase'**
  String get authenticateToViewSeedPhrase;

  /// No description provided for @authenticationRequiredSeedPhrase.
  ///
  /// In en, this message translates to:
  /// **'Authentication required to view seed phrase'**
  String get authenticationRequiredSeedPhrase;

  /// No description provided for @securityWarning.
  ///
  /// In en, this message translates to:
  /// **'Security Warning'**
  String get securityWarning;

  /// No description provided for @seedPhraseMasterKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'Your seed phrase is the master key to your wallet. Anyone with it can move all your funds.'**
  String get seedPhraseMasterKeyWarning;

  /// No description provided for @seedPhraseSafetyBullets.
  ///
  /// In en, this message translates to:
  /// **'• Never share it with anyone\n• Never enter it on websites\n• Write it down and store it offline'**
  String get seedPhraseSafetyBullets;

  /// No description provided for @iUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I Understand'**
  String get iUnderstand;

  /// No description provided for @noSeedPhraseStored.
  ///
  /// In en, this message translates to:
  /// **'No seed phrase stored for this wallet'**
  String get noSeedPhraseStored;

  /// No description provided for @seedPhraseCopied.
  ///
  /// In en, this message translates to:
  /// **'Seed phrase copied to clipboard'**
  String get seedPhraseCopied;

  /// No description provided for @backupSeedPhraseIntro.
  ///
  /// In en, this message translates to:
  /// **'Your 12-word recovery phrase is the only way to recover your wallet if you lose your phone or forget your password.'**
  String get backupSeedPhraseIntro;

  /// No description provided for @unableToOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Unable to open {value}'**
  String unableToOpenLink(Object value);

  /// No description provided for @searchReceivingToken.
  ///
  /// In en, this message translates to:
  /// **'Search receiving token'**
  String get searchReceivingToken;

  /// No description provided for @selectTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Token'**
  String get selectTokenTitle;

  /// No description provided for @checkingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get checkingStatus;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get noConnection;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get noInternetConnection;

  /// No description provided for @tokenAddedFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'{symbol} added from clipboard'**
  String tokenAddedFromClipboard(Object symbol);

  /// No description provided for @networkAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'{name} added successfully!'**
  String networkAddedSuccessfully(Object name);

  /// No description provided for @networkChainIdExists.
  ///
  /// In en, this message translates to:
  /// **'A network with Chain ID {chainId} already exists.'**
  String networkChainIdExists(Object chainId);

  /// No description provided for @networkNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Network Name *'**
  String get networkNameLabel;

  /// No description provided for @networkNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Cronos, zkSync Era'**
  String get networkNameHint;

  /// No description provided for @currencySymbolLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency Symbol *'**
  String get currencySymbolLabel;

  /// No description provided for @currencySymbolHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. CRO, ETH'**
  String get currencySymbolHint;

  /// No description provided for @chainIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Chain ID *'**
  String get chainIdLabel;

  /// No description provided for @chainIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 25, 324'**
  String get chainIdHint;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @mustBeNumber.
  ///
  /// In en, this message translates to:
  /// **'Must be a number'**
  String get mustBeNumber;

  /// No description provided for @autoFillFromChainId.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill from chain ID'**
  String get autoFillFromChainId;

  /// No description provided for @enterChainIdHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter Chain ID to auto-fill network details when available.'**
  String get enterChainIdHelp;

  /// No description provided for @rpcUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'RPC URL *'**
  String get rpcUrlLabel;

  /// No description provided for @rpcUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://rpc.example.com'**
  String get rpcUrlHint;

  /// No description provided for @mustBeSecureHttps.
  ///
  /// In en, this message translates to:
  /// **'Must be a secure (https) URL'**
  String get mustBeSecureHttps;

  /// No description provided for @rpcReachable.
  ///
  /// In en, this message translates to:
  /// **'RPC is reachable'**
  String get rpcReachable;

  /// No description provided for @rpcUnreachable.
  ///
  /// In en, this message translates to:
  /// **'RPC unreachable, check URL'**
  String get rpcUnreachable;

  /// No description provided for @blockExplorerOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Block Explorer URL (optional)'**
  String get blockExplorerOptionalLabel;

  /// No description provided for @blockExplorerHint.
  ///
  /// In en, this message translates to:
  /// **'https://explorer.example.com'**
  String get blockExplorerHint;

  /// No description provided for @trustedNetworkWarning.
  ///
  /// In en, this message translates to:
  /// **'Your wallet address works on all EVM chains. Only add networks you trust because malicious RPCs can show fake data.'**
  String get trustedNetworkWarning;

  /// No description provided for @addNetworkAction.
  ///
  /// In en, this message translates to:
  /// **'Add Network'**
  String get addNetworkAction;

  /// No description provided for @autoHidesInSeconds.
  ///
  /// In en, this message translates to:
  /// **'Auto-hides in {seconds}s'**
  String autoHidesInSeconds(Object seconds);

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @noSeedPhraseAvailablePrivateKey.
  ///
  /// In en, this message translates to:
  /// **'No seed phrase available.\nThis wallet was imported via private key.'**
  String get noSeedPhraseAvailablePrivateKey;

  /// No description provided for @communityDiscordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join server'**
  String get communityDiscordSubtitle;

  /// No description provided for @communityTelegramSubtitle.
  ///
  /// In en, this message translates to:
  /// **'FOMOWL channel'**
  String get communityTelegramSubtitle;

  /// No description provided for @noNftsToDisplay.
  ///
  /// In en, this message translates to:
  /// **'No NFTs to display'**
  String get noNftsToDisplay;

  /// No description provided for @moreNftsAvailable.
  ///
  /// In en, this message translates to:
  /// **'NFTs are already shown on home'**
  String get moreNftsAvailable;

  /// No description provided for @seedPhraseSecureScreenNotice.
  ///
  /// In en, this message translates to:
  /// **'Screen capture is blocked while this recovery phrase is visible where supported.'**
  String get seedPhraseSecureScreenNotice;

  /// No description provided for @iBackedItUp.
  ///
  /// In en, this message translates to:
  /// **'I backed it up'**
  String get iBackedItUp;

  /// No description provided for @seedPhraseVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your backup'**
  String get seedPhraseVerificationTitle;

  /// No description provided for @seedPhraseVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write the requested words to confirm you stored the phrase offline.'**
  String get seedPhraseVerificationSubtitle;

  /// No description provided for @selectSeedPhraseWord.
  ///
  /// In en, this message translates to:
  /// **'Select word #{index}'**
  String selectSeedPhraseWord(Object index);

  /// No description provided for @verifyBackup.
  ///
  /// In en, this message translates to:
  /// **'Verify backup'**
  String get verifyBackup;

  /// No description provided for @seedPhraseVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'That backup check did not match. Try again.'**
  String get seedPhraseVerificationFailed;

  /// No description provided for @seedPhraseBackupVerified.
  ///
  /// In en, this message translates to:
  /// **'Seed phrase backup verified'**
  String get seedPhraseBackupVerified;

  /// No description provided for @seedPhraseBackupVerificationComplete.
  ///
  /// In en, this message translates to:
  /// **'Your recovery phrase backup has been confirmed.'**
  String get seedPhraseBackupVerificationComplete;

  /// No description provided for @confirmSecretPhraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your secret phrase'**
  String get confirmSecretPhraseTitle;

  /// No description provided for @confirmSecretPhraseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please acknowledge the following security measures to ensure the safety of your digital vault.'**
  String get confirmSecretPhraseSubtitle;

  /// No description provided for @confirmSecretPhraseCheckOne.
  ///
  /// In en, this message translates to:
  /// **'I am the only one that knows it.'**
  String get confirmSecretPhraseCheckOne;

  /// No description provided for @confirmSecretPhraseCheckTwo.
  ///
  /// In en, this message translates to:
  /// **'The secret phrase is not accessible to third parties.'**
  String get confirmSecretPhraseCheckTwo;

  /// No description provided for @confirmSecretPhraseCheckThree.
  ///
  /// In en, this message translates to:
  /// **'My funds can be stolen if someone else sees my recovery phrase.'**
  String get confirmSecretPhraseCheckThree;

  /// No description provided for @adminControlCenter.
  ///
  /// In en, this message translates to:
  /// **'Owllet Control Center'**
  String get adminControlCenter;

  /// No description provided for @adminSystemStatus.
  ///
  /// In en, this message translates to:
  /// **'System Status'**
  String get adminSystemStatus;

  /// No description provided for @adminBackendLatency.
  ///
  /// In en, this message translates to:
  /// **'Backend Latency'**
  String get adminBackendLatency;

  /// No description provided for @adminAppPerformance.
  ///
  /// In en, this message translates to:
  /// **'App Performance'**
  String get adminAppPerformance;

  /// No description provided for @adminRegistryTokens.
  ///
  /// In en, this message translates to:
  /// **'Registry Tokens'**
  String get adminRegistryTokens;

  /// No description provided for @adminTotalUsers.
  ///
  /// In en, this message translates to:
  /// **'Total Users'**
  String get adminTotalUsers;

  /// No description provided for @adminTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get adminTransactions;

  /// No description provided for @adminMaintainers.
  ///
  /// In en, this message translates to:
  /// **'Maintainers'**
  String get adminMaintainers;

  /// No description provided for @adminGlobalBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Global Broadcast'**
  String get adminGlobalBroadcast;

  /// No description provided for @adminNotificationTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Notification title'**
  String get adminNotificationTitleHint;

  /// No description provided for @adminMessageBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Message body'**
  String get adminMessageBodyHint;

  /// No description provided for @adminSendToAllUsers.
  ///
  /// In en, this message translates to:
  /// **'Send to All Users'**
  String get adminSendToAllUsers;

  /// No description provided for @adminWalletAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Wallet address'**
  String get adminWalletAddressHint;

  /// No description provided for @adminNameOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get adminNameOptionalHint;

  /// No description provided for @adminAddMaintainer.
  ///
  /// In en, this message translates to:
  /// **'Add Maintainer'**
  String get adminAddMaintainer;

  /// No description provided for @adminMaintainerAdded.
  ///
  /// In en, this message translates to:
  /// **'Maintainer added'**
  String get adminMaintainerAdded;

  /// No description provided for @adminMaintainerAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add maintainer'**
  String get adminMaintainerAddFailed;

  /// No description provided for @adminTokenRegistry.
  ///
  /// In en, this message translates to:
  /// **'Token Registry'**
  String get adminTokenRegistry;

  /// No description provided for @adminSearchRegistryHint.
  ///
  /// In en, this message translates to:
  /// **'Search registry...'**
  String get adminSearchRegistryHint;

  /// No description provided for @adminTokenVerified.
  ///
  /// In en, this message translates to:
  /// **'Token verified'**
  String get adminTokenVerified;

  /// No description provided for @adminTokenUnverified.
  ///
  /// In en, this message translates to:
  /// **'Token unverified'**
  String get adminTokenUnverified;

  /// No description provided for @adminRegistryUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update registry'**
  String get adminRegistryUpdateFailed;

  /// No description provided for @adminBroadcastSent.
  ///
  /// In en, this message translates to:
  /// **'Broadcast sent successfully'**
  String get adminBroadcastSent;

  /// No description provided for @adminBroadcastSentToDevices.
  ///
  /// In en, this message translates to:
  /// **'Broadcast sent to ~{count} devices'**
  String adminBroadcastSentToDevices(Object count);

  /// No description provided for @adminBroadcastFailed.
  ///
  /// In en, this message translates to:
  /// **'Broadcast failed'**
  String get adminBroadcastFailed;

  /// No description provided for @adminSecretRequired.
  ///
  /// In en, this message translates to:
  /// **'Admin secret is required'**
  String get adminSecretRequired;

  /// No description provided for @continueAgreementPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get continueAgreementPrefix;

  /// No description provided for @continueAgreementSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get continueAgreementSuffix;

  /// No description provided for @termsOfUseLabel.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUseLabel;

  /// No description provided for @andLabel.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get andLabel;

  /// No description provided for @privacyPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyLabel;

  /// No description provided for @termsServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsServiceTitle;

  /// No description provided for @termsSection1Title.
  ///
  /// In en, this message translates to:
  /// **'1. Acceptance of Terms'**
  String get termsSection1Title;

  /// No description provided for @termsSection1Body.
  ///
  /// In en, this message translates to:
  /// **'By installing or using Owllet you confirm that you are legally allowed to hold digital assets and that you accept these terms. If you disagree, uninstall the application immediately.'**
  String get termsSection1Body;

  /// No description provided for @termsSection2Title.
  ///
  /// In en, this message translates to:
  /// **'2. Self-Custody Responsibilities'**
  String get termsSection2Title;

  /// No description provided for @termsSection2Body.
  ///
  /// In en, this message translates to:
  /// **'Owllet only generates keys and signs transactions locally. You control the mnemonic, derived wallets, approvals, and transactions. We cannot recover a forgotten passcode, seed phrase, or private key.'**
  String get termsSection2Body;

  /// No description provided for @termsSection3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Blockchain Transactions & Fees'**
  String get termsSection3Title;

  /// No description provided for @termsSection3Body.
  ///
  /// In en, this message translates to:
  /// **'Every transfer, approval, or swap you send is broadcast to the EVM network you selected. Gas estimates are best-effort and the final cost is determined by the network. You are responsible for verifying recipient addresses and paying all network fees.'**
  String get termsSection3Body;

  /// No description provided for @termsSection4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Third-Party Services & Swaps'**
  String get termsSection4Title;

  /// No description provided for @termsSection4Body.
  ///
  /// In en, this message translates to:
  /// **'The app relies on RPC providers (e.g., Alchemy and any custom RPC you add), CoinGecko, and public AMM routers such as Uniswap, QuickSwap, PancakeSwap, and SushiSwap. Service interruptions, inaccurate market data, or smart-contract bugs can cause losses or failed transactions. We do not audit tokens, pools, or smart contracts.'**
  String get termsSection4Body;

  /// No description provided for @termsSection5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Compliance & Taxes'**
  String get termsSection5Title;

  /// No description provided for @termsSection5Body.
  ///
  /// In en, this message translates to:
  /// **'You are solely responsible for determining whether your use of Owllet is legal in your jurisdiction and for paying any taxes or reporting obligations related to your digital-asset activity.'**
  String get termsSection5Body;

  /// No description provided for @termsSection6Title.
  ///
  /// In en, this message translates to:
  /// **'6. Prohibited Use'**
  String get termsSection6Title;

  /// No description provided for @termsSection6Body.
  ///
  /// In en, this message translates to:
  /// **'You may not use the app for illicit activity, sanctions evasion, malware distribution, or to violate the terms of any blockchain, RPC provider, or applicable law. We reserve the right to disable access to network features that are abused.'**
  String get termsSection6Body;

  /// No description provided for @termsSection7Title.
  ///
  /// In en, this message translates to:
  /// **'7. Disclaimer of Warranties'**
  String get termsSection7Title;

  /// No description provided for @termsSection7Body.
  ///
  /// In en, this message translates to:
  /// **'The app is provided \"as is\" and \"as available\" without warranties of any kind, express or implied. We do not guarantee that price data is accurate, that transactions will succeed, or that the software is error-free.'**
  String get termsSection7Body;

  /// No description provided for @termsSection8Title.
  ///
  /// In en, this message translates to:
  /// **'8. Limitation of Liability'**
  String get termsSection8Title;

  /// No description provided for @termsSection8Body.
  ///
  /// In en, this message translates to:
  /// **'To the maximum extent permitted by law, we are not liable for lost funds, lost seed phrases, market losses, smart-contract exploits, indirect, incidental, or consequential damages arising out of your use of the app.'**
  String get termsSection8Body;

  /// No description provided for @termsSection9Title.
  ///
  /// In en, this message translates to:
  /// **'9. Changes & Contact'**
  String get termsSection9Title;

  /// No description provided for @termsSection9Body.
  ///
  /// In en, this message translates to:
  /// **'We may update these terms as we launch new features or networks. Continued use after a change means you accept the new terms. Contact us on X (@fomowlhq) if you need clarification.'**
  String get termsSection9Body;

  /// No description provided for @termsEffectiveDate.
  ///
  /// In en, this message translates to:
  /// **'Effective date: February 2026'**
  String get termsEffectiveDate;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @privacySection1Title.
  ///
  /// In en, this message translates to:
  /// **'1. Overview'**
  String get privacySection1Title;

  /// No description provided for @privacySection1Body.
  ///
  /// In en, this message translates to:
  /// **'Owllet is an EVM-only, self-custody wallet. All key generation and signing happen on your device using battle-tested BIP-39/BIP-32 libraries. We never run a centralized ledger or take possession of your assets.'**
  String get privacySection1Body;

  /// No description provided for @privacySection2Title.
  ///
  /// In en, this message translates to:
  /// **'2. Data Stored Locally'**
  String get privacySection2Title;

  /// No description provided for @privacySection2Body.
  ///
  /// In en, this message translates to:
  /// **'We store the following items with Flutter Secure Storage or SharedPreferences on your device:\n• Wallet names, addresses, and derivation indexes\n• Encrypted private keys, seed phrase (if you save it), and your passcode hash\n• Biometric toggles plus language/UI preferences\nDeleting the app or clearing secure storage permanently removes this data. It never leaves your device.'**
  String get privacySection2Body;

  /// No description provided for @privacySection3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Third-Party Services'**
  String get privacySection3Title;

  /// No description provided for @privacySection3Body.
  ///
  /// In en, this message translates to:
  /// **'To display balances, price data, and execute swaps the app connects directly to:\n• RPC providers such as Alchemy and any custom RPC you add\n• CoinGecko for market data and charts\n• Public AMM routers (Uniswap, QuickSwap, PancakeSwap, SushiSwap, etc.) when you submit swaps or approvals\nThese providers may log IP addresses or wallet activity under their own policies.'**
  String get privacySection3Body;

  /// No description provided for @privacySection4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Device Permissions'**
  String get privacySection4Title;

  /// No description provided for @privacySection4Body.
  ///
  /// In en, this message translates to:
  /// **'Camera access is used only for QR scanning. Biometric prompts (Face/Touch ID, fingerprint) are handled by the operating system; we receive only success/failure. We do not access your photos, contacts, microphone, or location.'**
  String get privacySection4Body;

  /// No description provided for @privacySection5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Your Responsibilities'**
  String get privacySection5Title;

  /// No description provided for @privacySection5Body.
  ///
  /// In en, this message translates to:
  /// **'• Back up your 12-word seed phrase offline and never share it\n• Verify destination addresses and approvals before signing\n• Keep your device updated, set a strong passcode, and enable biometrics\n• Understand that blockchain transactions are irreversible'**
  String get privacySection5Body;

  /// No description provided for @privacySection6Title.
  ///
  /// In en, this message translates to:
  /// **'6. Updates & Contact'**
  String get privacySection6Title;

  /// No description provided for @privacySection6Body.
  ///
  /// In en, this message translates to:
  /// **'We may revise this notice as we add networks or features. The latest version is always available in the app. Reach us on X (@fomowlhq) if you have privacy questions.'**
  String get privacySection6Body;

  /// No description provided for @privacyLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: February 2026'**
  String get privacyLastUpdated;

  /// No description provided for @faceVerifyReason.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity with Face ID'**
  String get faceVerifyReason;

  /// No description provided for @faceVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Face verification failed. Please try again.'**
  String get faceVerificationFailed;

  /// No description provided for @biometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is not available on this device.'**
  String get biometricUnavailable;

  /// No description provided for @verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifying;

  /// No description provided for @faceVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Face Verification'**
  String get faceVerificationTitle;

  /// No description provided for @biometricPromptInstruction.
  ///
  /// In en, this message translates to:
  /// **'Place your face in the frame to verify'**
  String get biometricPromptInstruction;

  /// No description provided for @facePromptInstruction.
  ///
  /// In en, this message translates to:
  /// **'Position your face in the circle above'**
  String get facePromptInstruction;

  /// No description provided for @verifyFace.
  ///
  /// In en, this message translates to:
  /// **'Verify Face'**
  String get verifyFace;

  /// No description provided for @identityVerifyReason.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to continue'**
  String get identityVerifyReason;

  /// No description provided for @biometricVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric verification failed. Please try again.'**
  String get biometricVerificationFailed;

  /// No description provided for @biometricVerificationFailedWithPasscode.
  ///
  /// In en, this message translates to:
  /// **'Biometric verification failed. Please use your passcode instead.'**
  String get biometricVerificationFailedWithPasscode;

  /// No description provided for @biometricVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric Verification'**
  String get biometricVerificationTitle;

  /// No description provided for @tapBelowToVerify.
  ///
  /// In en, this message translates to:
  /// **'Tap below to verify'**
  String get tapBelowToVerify;

  /// No description provided for @startVerification.
  ///
  /// In en, this message translates to:
  /// **'Start Verification'**
  String get startVerification;

  /// No description provided for @fingerprintVerifyReason.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity with fingerprint'**
  String get fingerprintVerifyReason;

  /// No description provided for @fingerprintVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint verification failed. Please try again.'**
  String get fingerprintVerificationFailed;

  /// No description provided for @fingerprintVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint Verification'**
  String get fingerprintVerificationTitle;

  /// No description provided for @fingerprintPromptInstruction.
  ///
  /// In en, this message translates to:
  /// **'Place your finger on the sensor to verify'**
  String get fingerprintPromptInstruction;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @swapFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get swapFromLabel;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceLabel;

  /// No description provided for @platformFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Platform Fee'**
  String get platformFeeLabel;

  /// No description provided for @networkFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Network Fee'**
  String get networkFeeLabel;

  /// No description provided for @coveredByOwllet.
  ///
  /// In en, this message translates to:
  /// **'Covered by Owllet'**
  String get coveredByOwllet;

  /// No description provided for @toReceiveLabel.
  ///
  /// In en, this message translates to:
  /// **'To Receive'**
  String get toReceiveLabel;

  /// No description provided for @swapToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get swapToLabel;

  /// No description provided for @calculatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Calculating...'**
  String get calculatingLabel;

  /// No description provided for @receiveTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive Token'**
  String get receiveTokenTitle;

  /// No description provided for @receiveExternalWarning.
  ///
  /// In en, this message translates to:
  /// **'Only send tokens on the correct network. Sending tokens on the wrong network may result in permanent loss.'**
  String get receiveExternalWarning;

  /// No description provided for @currencyUsd.
  ///
  /// In en, this message translates to:
  /// **'US Dollar (USD)'**
  String get currencyUsd;

  /// No description provided for @currencyEur.
  ///
  /// In en, this message translates to:
  /// **'Euro (EUR)'**
  String get currencyEur;

  /// No description provided for @currencyGbp.
  ///
  /// In en, this message translates to:
  /// **'British Pound (GBP)'**
  String get currencyGbp;

  /// No description provided for @currencyNgn.
  ///
  /// In en, this message translates to:
  /// **'Nigerian Naira (NGN)'**
  String get currencyNgn;

  /// No description provided for @selectTokenAndNetwork.
  ///
  /// In en, this message translates to:
  /// **'SELECT TOKEN & NETWORK'**
  String get selectTokenAndNetwork;

  /// No description provided for @networkLabel.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkLabel;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @availableBalance.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE BALANCE'**
  String get availableBalance;

  /// No description provided for @totalNetWorth.
  ///
  /// In en, this message translates to:
  /// **'TOTAL NET WORTH'**
  String get totalNetWorth;

  /// No description provided for @portfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get portfolio;

  /// No description provided for @balanceSyncingStatus.
  ///
  /// In en, this message translates to:
  /// **'Syncing balances'**
  String get balanceSyncingStatus;

  /// No description provided for @balanceMayBeOutdatedStatus.
  ///
  /// In en, this message translates to:
  /// **'Balances may be outdated'**
  String get balanceMayBeOutdatedStatus;

  /// No description provided for @balanceUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String balanceUpdatedAt(Object time);

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @followSocialhq.
  ///
  /// In en, this message translates to:
  /// **'Follow @fomowlhq on X for live updates'**
  String get followSocialhq;

  /// No description provided for @socialhqHandle.
  ///
  /// In en, this message translates to:
  /// **'x.com/fomowlhq'**
  String get socialhqHandle;

  /// No description provided for @discoverTabsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tabs'**
  String get discoverTabsTitle;

  /// No description provided for @discoverNewTab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get discoverNewTab;

  /// No description provided for @discoverMaxTabsReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum 5 tabs reached'**
  String get discoverMaxTabsReached;

  /// No description provided for @discoverCloseTab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get discoverCloseTab;

  /// No description provided for @discoverHome.
  ///
  /// In en, this message translates to:
  /// **'Discover home'**
  String get discoverHome;

  /// No description provided for @doneLabel.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneLabel;

  /// No description provided for @bitcoinConfirmTransfer.
  ///
  /// In en, this message translates to:
  /// **'Confirm Bitcoin transfer'**
  String get bitcoinConfirmTransfer;

  /// No description provided for @bitcoinInvalidPlan.
  ///
  /// In en, this message translates to:
  /// **'This Bitcoin plan is invalid. Return to Send and prepare it again.'**
  String get bitcoinInvalidPlan;

  /// No description provided for @bitcoinTransferFailed.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin transfer could not be completed.'**
  String get bitcoinTransferFailed;

  /// No description provided for @bitcoinPreparingTransfer.
  ///
  /// In en, this message translates to:
  /// **'Preparing transfer…'**
  String get bitcoinPreparingTransfer;

  /// No description provided for @bitcoinAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get bitcoinAmount;

  /// No description provided for @bitcoinDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get bitcoinDestination;

  /// No description provided for @bitcoinFeeRate.
  ///
  /// In en, this message translates to:
  /// **'Fee rate'**
  String get bitcoinFeeRate;

  /// No description provided for @bitcoinNetworkFee.
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get bitcoinNetworkFee;

  /// No description provided for @bitcoinEstimatedVbytes.
  ///
  /// In en, this message translates to:
  /// **'Estimated vbytes'**
  String get bitcoinEstimatedVbytes;

  /// No description provided for @bitcoinTotalDebit.
  ///
  /// In en, this message translates to:
  /// **'Total debit'**
  String get bitcoinTotalDebit;

  /// No description provided for @bitcoinAddressType.
  ///
  /// In en, this message translates to:
  /// **'Address type'**
  String get bitcoinAddressType;

  /// No description provided for @bitcoinNativeSegwit.
  ///
  /// In en, this message translates to:
  /// **'Native SegWit'**
  String get bitcoinNativeSegwit;

  /// No description provided for @bitcoinTaproot.
  ///
  /// In en, this message translates to:
  /// **'Taproot'**
  String get bitcoinTaproot;

  /// No description provided for @bitcoinEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get bitcoinEnabled;

  /// No description provided for @bitcoinDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get bitcoinDisabled;

  /// No description provided for @bitcoinTransaction.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin transaction'**
  String get bitcoinTransaction;

  /// No description provided for @bitcoinStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get bitcoinStatus;

  /// No description provided for @bitcoinConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get bitcoinConfirmed;

  /// No description provided for @bitcoinPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get bitcoinPending;

  /// No description provided for @bitcoinConfirmations.
  ///
  /// In en, this message translates to:
  /// **'Confirmations'**
  String get bitcoinConfirmations;

  /// No description provided for @bitcoinBlockHeight.
  ///
  /// In en, this message translates to:
  /// **'Block height'**
  String get bitcoinBlockHeight;

  /// No description provided for @bitcoinTransactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get bitcoinTransactionId;

  /// No description provided for @bitcoinWalletChange.
  ///
  /// In en, this message translates to:
  /// **'Wallet change'**
  String get bitcoinWalletChange;

  /// No description provided for @bitcoinTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get bitcoinTimestamp;

  /// No description provided for @bitcoinStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Latest transaction status is unavailable.'**
  String get bitcoinStatusUnavailable;

  /// No description provided for @bitcoinViewExplorer.
  ///
  /// In en, this message translates to:
  /// **'View in explorer'**
  String get bitcoinViewExplorer;

  /// No description provided for @bitcoinReceiveWarning.
  ///
  /// In en, this message translates to:
  /// **'Send Bitcoin (BTC) only to this address.'**
  String get bitcoinReceiveWarning;

  /// No description provided for @bitcoinCapabilityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This feature is not available for Bitcoin yet.'**
  String get bitcoinCapabilityUnavailable;

  /// No description provided for @bitcoinEconomy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get bitcoinEconomy;

  /// No description provided for @bitcoinNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get bitcoinNormal;

  /// No description provided for @bitcoinPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get bitcoinPriority;

  /// No description provided for @bitcoinSplitFunds.
  ///
  /// In en, this message translates to:
  /// **'Funds are split across Native SegWit and Taproot. One address format must cover the amount and network fee.'**
  String get bitcoinSplitFunds;

  /// No description provided for @advancedTransactionDetails.
  ///
  /// In en, this message translates to:
  /// **'Advanced details'**
  String get advancedTransactionDetails;

  /// No description provided for @bitcoinNetworkSpeed.
  ///
  /// In en, this message translates to:
  /// **'NETWORK SPEED'**
  String get bitcoinNetworkSpeed;

  /// No description provided for @bitcoinEqualFeeTiers.
  ///
  /// In en, this message translates to:
  /// **'All speed options currently use the same fee.'**
  String get bitcoinEqualFeeTiers;

  /// No description provided for @bitcoinInputType.
  ///
  /// In en, this message translates to:
  /// **'Address / input type'**
  String get bitcoinInputType;

  /// No description provided for @bitcoinEstimatedSize.
  ///
  /// In en, this message translates to:
  /// **'Estimated transaction size'**
  String get bitcoinEstimatedSize;

  /// No description provided for @bitcoinReplaceByFee.
  ///
  /// In en, this message translates to:
  /// **'Replace-by-fee'**
  String get bitcoinReplaceByFee;

  /// No description provided for @bitcoinSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get bitcoinSpeed;

  /// No description provided for @transactionAmountToSend.
  ///
  /// In en, this message translates to:
  /// **'AMOUNT TO SEND'**
  String get transactionAmountToSend;

  /// No description provided for @transactionTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get transactionTotal;

  /// No description provided for @transactionSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get transactionSubmittedTitle;

  /// No description provided for @transactionSubmittedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The network accepted your transaction for relay. Waiting for its first confirmation.'**
  String get transactionSubmittedSubtitle;

  /// No description provided for @transactionSubmissionUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Submission uncertain'**
  String get transactionSubmissionUnknownTitle;

  /// No description provided for @transactionSubmissionUnknownSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm whether the network accepted this transaction. Check its status before sending again.'**
  String get transactionSubmissionUnknownSubtitle;

  /// No description provided for @transactionConfirmedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your transaction has been included in a block.'**
  String get transactionConfirmedSubtitle;

  /// No description provided for @bitcoinRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Review saved attempts'**
  String get bitcoinRecoveryTitle;

  /// No description provided for @bitcoinRecoveryWarning.
  ///
  /// In en, this message translates to:
  /// **'Only recover an attempt you know was rejected before broadcast. A missing transaction alone is not proof.'**
  String get bitcoinRecoveryWarning;

  /// No description provided for @bitcoinRecoveryAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'This attempt was rejected before broadcast.'**
  String get bitcoinRecoveryAcknowledge;

  /// No description provided for @bitcoinRecoveryAction.
  ///
  /// In en, this message translates to:
  /// **'Recover Testnet4 reservation'**
  String get bitcoinRecoveryAction;

  /// No description provided for @bitcoinRecoveryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Recovery is unavailable. This attempt remains reserved.'**
  String get bitcoinRecoveryUnavailable;

  /// No description provided for @bitcoinRecoveryError.
  ///
  /// In en, this message translates to:
  /// **'Could not verify recovery. No new transaction has been sent.'**
  String get bitcoinRecoveryError;

  /// No description provided for @bitcoinRecoveryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved attempts for this network.'**
  String get bitcoinRecoveryEmpty;

  /// No description provided for @bitcoinRecoverySuccess.
  ///
  /// In en, this message translates to:
  /// **'Reservation recovered. You can prepare a new transfer.'**
  String get bitcoinRecoverySuccess;

  /// No description provided for @bitcoinReservedInputs.
  ///
  /// In en, this message translates to:
  /// **'Reserved inputs'**
  String get bitcoinReservedInputs;

  /// No description provided for @bitcoinRecoveryCheck.
  ///
  /// In en, this message translates to:
  /// **'Check transaction status'**
  String get bitcoinRecoveryCheck;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'en',
    'es',
    'fr',
    'ha',
    'ig',
    'yo',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ha':
      return AppLocalizationsHa();
    case 'ig':
      return AppLocalizationsIg();
    case 'yo':
      return AppLocalizationsYo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
