// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hausa (`ha`).
class AppLocalizationsHa extends AppLocalizations {
  AppLocalizationsHa([String locale = 'ha']) : super(locale);

  @override
  String get appName => 'Owllet';

  @override
  String get welcomeTitle => 'Sannu, Barka da zuwa Owlian';

  @override
  String get welcomeSubtitle =>
      'Ƙirƙiri walat ɗinka mai tsaro, yi ajiyar sa sannan ka fara amfani da tsarin Owllet';

  @override
  String get createWallet => 'Ƙirƙiri Walat';

  @override
  String get importWallet => 'Shigo da Walat';

  @override
  String get chooseLanguage => 'Zaɓi yarenka';

  @override
  String get chooseDesiredLanguage => 'Zaɓi yaren da kake so';

  @override
  String get tradeInstantly => 'Yi ciniki nan take.';

  @override
  String get spendEffortlessly => 'Kashe kuɗi ba tare da wahala ba.';

  @override
  String get getStarted => 'Fara yanzu';

  @override
  String get alreadyHaveWallet => 'Kina da walat riga?';

  @override
  String get importExistingWallet => 'Shigo da walat ɗin da kake da shi';

  @override
  String get secretPhrase => 'Kalmomin Sirri';

  @override
  String get privateKey => 'Mabuɗin Sirri';

  @override
  String get enterPasscode => 'Saka lambar sirri';

  @override
  String get confirmPasscode => 'Tabbatar da lambar sirri';

  @override
  String get setupBiometric => 'Saita yatsa ko fuska';

  @override
  String get enableFaceId => 'Kunna fuska';

  @override
  String get enableFingerprint => 'Kunna yatsa';

  @override
  String get skip => 'Wuce';

  @override
  String get continue_ => 'Ci gaba';

  @override
  String get home => 'Gida';

  @override
  String get wallet => 'Walat';

  @override
  String get swap => 'Musanya';

  @override
  String get earn => 'Sami kuɗi';

  @override
  String get payment => 'Biya';

  @override
  String get me => 'Ni';

  @override
  String get settings => 'Saituna';

  @override
  String get balance => 'Kuɗin da ya rage';

  @override
  String get tokens => 'Token';

  @override
  String get nfts => 'NFTs';

  @override
  String get loadingBalances => 'Ana loda kuɗi...';

  @override
  String get noTokensYet => 'Babu token anan tukuna';

  @override
  String get depositTokens => 'Saka token don farawa';

  @override
  String get totalBalance => 'Jimillar kuɗi';

  @override
  String get nftPreview => 'NFT nunin farko';

  @override
  String get viewAll => 'Duba duka';

  @override
  String get noNftsFound => 'Ba a sami NFT ba';

  @override
  String get nftPreviewDescription =>
      'Nunin NFT ɗinka zai bayyana anan akan hanyoyin sadarwa da aka yarda da su.';

  @override
  String get send => 'Aika';

  @override
  String get receive => 'Karba';

  @override
  String get buy => 'Saya';

  @override
  String get sell => 'Sayarwa';

  @override
  String get wallets => 'Walat-walat';

  @override
  String get activeWallet => 'WALAT MAI AIKI';

  @override
  String get addWallet => 'Ƙara Walat';

  @override
  String get createNewWallet => 'Ƙirƙiri Sabon Walat';

  @override
  String get importSeedPhrase => 'Shigo da Kalmomin Sirri';

  @override
  String get importPrivateKey => 'Shigo da Mabuɗin Sirri';

  @override
  String get mainWallet => 'Babban Walat';

  @override
  String get addressCopied => 'An kwafe adireshi!';

  @override
  String get profile => 'Bayananka';

  @override
  String get general => 'Gabaɗaya';

  @override
  String get manageWallets => 'Sarrafa Walat-walat';

  @override
  String get switchNetwork => 'Canza Hanyar Sadarwa';

  @override
  String get currency => 'Kuɗi';

  @override
  String get chooseYourLanguage => 'Zaɓi Yarenka';

  @override
  String get referrals => 'Gayyata';

  @override
  String get security => 'Tsaro';

  @override
  String get others => 'Wasu';

  @override
  String get passwordSecurity => 'Lambar Sirri da Tsaro';

  @override
  String get network => 'Hanyar Sadarwa';

  @override
  String get selectNetwork => 'Zaɓi Hanyar Sadarwa';

  @override
  String get addCustomNetwork => 'Ƙara Hanyar Sadarwa';

  @override
  String get seedPhraseBackup => 'Ajiyar Kalmomin Sirri';

  @override
  String get resetWallet => 'Sake Saita Walat';

  @override
  String get privacyPolicy => 'Tsarin Sirri';

  @override
  String get termsOfService => 'Sharuɗɗan Sabis';

  @override
  String get feedback => 'Ra\'ayi';

  @override
  String get joinOurCommunity => 'Shiga cikin Al\'ummar mu';

  @override
  String get resetApp => 'Sake Saita App';

  @override
  String get noNftsYet => 'Babu NFT tukuna';

  @override
  String get nftCollection => 'Tarin NFT';

  @override
  String get nftGalleryScanning => 'Ana binciken NFTs...';

  @override
  String get nftGalleryEmptyDescription =>
      'Tarin NFT dinka zai bayyana a nan.\nSaya ko karɓi NFTs a kowace sarkar da ake tallafawa.';

  @override
  String nftGalleryUnsupportedChain(Object chain) {
    return 'Ba a tallafawa dakin nunin NFT a $chain tukuna.\nCanja zuwa Ethereum, BNB Smart Chain, Polygon, Arbitrum, Optimism, ko Base.';
  }

  @override
  String get failedToLoadNftsTitle => 'An kasa loda NFTs';

  @override
  String failedToLoadNftsWithError(Object error) {
    return 'An kasa loda NFTs: $error';
  }

  @override
  String get officialProjectNft => 'NFT na hukuma na aikin';

  @override
  String get transactionHistory => 'Tarihin Ciniki';

  @override
  String get allLabel => 'Duka';

  @override
  String get allChains => 'Dukkan chains';

  @override
  String get notifications => 'Sanarwa';

  @override
  String get notificationsSettings => 'Saitunan Sanarwa';

  @override
  String get enablePushNotifications => 'Kunna Sanarwar Turawa';

  @override
  String get pushNotificationsDesc =>
      'Karɓi faɗakarwa don adibas, canja wuri, da sabunta tsaro.';

  @override
  String get transactionBroadcast => 'An aika da cinikinka!';

  @override
  String get transactionFailed => 'Ciniki ya gaza';

  @override
  String get confirmTransfer => 'Tabbatar da Aikowa';

  @override
  String get gasFee => 'Kuɗin Hanyar Sadarwa';

  @override
  String get transactionDetails => 'BAYANIN CINIKI';

  @override
  String get closeLabel => 'Rufe';

  @override
  String get viewOnExplorer => 'Duba a Explorer';

  @override
  String get unknownNetwork => 'Network da ba a sani ba';

  @override
  String get walletHistoryFallbackWarning =>
      'Ana nuna tarihin explorer na sarkar da ke aiki yayin da tarihin walat ba ya samuwa.';

  @override
  String get walletHistoryLoadError => 'Ba a iya loda tarihin walat yanzu ba.';

  @override
  String get walletHistoryEmpty => 'Babu tarihin walat tukuna';

  @override
  String get historyTransferReceived => 'An karɓi canja wuri';

  @override
  String get historyTransferSent => 'An aika canja wuri';

  @override
  String historyReceivedAmountOnNetwork(Object amount, Object network) {
    return 'An karɓi $amount a kan $network.';
  }

  @override
  String historySentAmountOnNetwork(Object amount, Object network) {
    return 'An aika $amount a kan $network.';
  }

  @override
  String historySwapOnNetwork(Object network) {
    return 'Ayyukan musanya a kan $network.';
  }

  @override
  String historyActivityOnNetwork(Object network) {
    return 'Aiki a kan $network.';
  }

  @override
  String get historyTimestampLabel => 'Lokaci';

  @override
  String get historyTransactionHashLabel => 'Hash ɗin ciniki';

  @override
  String get historyReceiptUnavailable =>
      'Bayanan rasit na wannan abin tarihin ba su samuwa tukuna.';

  @override
  String get historyLoadingReceipt => 'Ana loda bayanan rasit...';

  @override
  String get historyReceiptLoadError => 'Ba a iya loda bayanan rasit yanzu ba.';

  @override
  String get historyReceiptPending =>
      'Rasit bai samuwa ba tukuna. Wataƙila mu\'amalar tana jiran tabbaci ko RPC ɗin nan bai dawo da ita ba.';

  @override
  String get historyStatusLabel => 'Matsayi';

  @override
  String get historyBlockNumberLabel => 'Lambar buloki';

  @override
  String get historyFromLabel => 'Daga';

  @override
  String get historyToLabel => 'Zuwa';

  @override
  String get historyGasUsedLabel => 'Gas da aka yi amfani da shi';

  @override
  String get historyGasPriceLabel => 'Farashin gas';

  @override
  String get historyContractAddressLabel => 'Adireshin kwangila';

  @override
  String get historyLogCountLabel => 'Logs';

  @override
  String get tokenLabel => 'Token';

  @override
  String get confirmedLabel => 'An tabbatar';

  @override
  String get failedLabel => 'Ya kasa';

  @override
  String get pendingLabel => 'Ana jira';

  @override
  String get swapPreparingTitle => 'Ana shiryawa...';

  @override
  String get swapPreparingSubtitle => 'Muna shirya musayar ka.';

  @override
  String get swapApprovalProcessingTitle => 'Ana neman amincewa...';

  @override
  String get swapApprovalProcessingSubtitle =>
      'Amince da amfani da token sannan ka jira tabbatarwa.';

  @override
  String get swapSubmittingTitle => 'Ana aika musanya...';

  @override
  String get swapSubmittingSubtitle =>
      'Ana aika musayar ka zuwa hanyar sadarwa.';

  @override
  String get swapGaslessSubmittingTitle => 'Ana aika oda ba tare da gas ba...';

  @override
  String get swapGaslessSubmittingSubtitle => 'Owllet na aika odar ka.';

  @override
  String get swapProcessingTitle => 'Ana kan ciniki...';

  @override
  String get swapProcessingSubtitle => 'Wannan na iya ɗaukar mintuna kaɗan.';

  @override
  String get swapGaslessProcessingSubtitle => 'Owllet na aiki akan odar ka.';

  @override
  String get swapCompletedTitle => 'An gama musanya';

  @override
  String get swapCompletedSubtitle => 'An tabbatar da cinikinka cikin nasara.';

  @override
  String get swapFailedTitle => 'Musanya ta gaza';

  @override
  String get noQuoteAvailable => 'Babu farashi';

  @override
  String get noRouterQuoteAvailable => 'Babu hanya';

  @override
  String get approvalPendingConfirmation =>
      'Amincewa na jiran tabbatarwa. Sake dubawa an jima.';

  @override
  String get transactionPendingConfirmation =>
      'Ciniki na jiran tabbatarwa. Sake dubawa an jima.';

  @override
  String get gaslessOrderFailedRetry => 'Oda ta gaza. Sake gwadawa.';

  @override
  String get swapMissingHash =>
      'An aika musanya amma ba a ga lambar tabbatarwa ba. Duba an jima.';

  @override
  String get transferPreparingTitle => 'Ana shirya canja wuri...';

  @override
  String get transferApprovalPendingTitle => 'Amincewar canja wuri na jira';

  @override
  String get transferSubmittingTitle => 'Ana aikawa da canja wuri...';

  @override
  String get transferInProgressTitle => 'Canja wuri na gudana';

  @override
  String get transferCompletedTitle => 'An kammala canja wuri';

  @override
  String get transferFailedTitle => 'Canja wuri ya kasa';

  @override
  String get transferPreparingSubtitle =>
      'Ana shirya canja wurinka domin aikawa.';

  @override
  String get transferApprovalPendingSubtitle =>
      'Da fatan za a jira yayin da sadarwar ke sarrafa amincewa.';

  @override
  String get transferSubmittingSubtitle =>
      'Ana yaɗa canja wurinka zuwa sadarwar.';

  @override
  String get transferInProgressSubtitle =>
      'Ana jiran sadarwar ta tabbatar da canja wurinka.';

  @override
  String get transferCompletedSubtitle =>
      'An tabbatar da canja wurinka cikin nasara.';

  @override
  String get genericTransactionPreparingTitle => 'Ana shirya mu\'amala...';

  @override
  String get genericTransactionApprovalPendingTitle => 'Amincewa na jira';

  @override
  String get genericTransactionSubmittingTitle => 'Ana aikawa da mu\'amala...';

  @override
  String get genericTransactionInProgressTitle => 'Mu\'amala na gudana';

  @override
  String get genericTransactionCompletedTitle => 'An kammala mu\'amala';

  @override
  String get genericTransactionPreparingSubtitle => 'Ana shirya mu\'amalarka.';

  @override
  String get genericTransactionApprovalPendingSubtitle =>
      'Da fatan za a jira yayin da sadarwar ke sarrafa amincewa.';

  @override
  String get genericTransactionSubmittingSubtitle =>
      'Ana yaɗa mu\'amalarka zuwa sadarwar.';

  @override
  String get genericTransactionInProgressSubtitle =>
      'Ana jiran sadarwar ta tabbatar da mu\'amalarka.';

  @override
  String get genericTransactionCompletedSubtitle =>
      'An tabbatar da mu\'amalarka cikin nasara.';

  @override
  String get transferWarningMessage =>
      'Tabbatar da adireshin mai karɓa sosai. Cinikin da aka riga aka aika ba ya canzawa.';

  @override
  String get maxTotal => 'JIMILLAR KUƊI';

  @override
  String get amount => 'KUƊI';

  @override
  String get estimationFailed => 'Lissafi ya gaza';

  @override
  String get networkError => 'Matsalar hanyar sadarwa';

  @override
  String get connectionFailed => 'Babu intanet. Duba haɗinka.';

  @override
  String get tryAgain => 'Sake Gwada';

  @override
  String get comingSoon => 'Yana nan tafe';

  @override
  String get congratulations => 'Taya murna!';

  @override
  String get walletCreated => 'An ƙirƙiri walat ɗinka cikin nasara';

  @override
  String get walletImported => 'An shigo da walat ɗinka cikin nasara';

  @override
  String get goToWallet => 'Je zuwa Walat';

  @override
  String get resetFailed => 'Sake saita app ya gaza. Sake gwadawa.';

  @override
  String get confirmClearLocalData =>
      'Wannan zai goge dukkan bayanan walat daga wannan wayar. Tabbatar kana da kalmomin sirri a guri mai kyau.';

  @override
  String get cancel => 'Soke';

  @override
  String get actionRequired => 'Akwai abin yi';

  @override
  String get sendToken => 'Aika Kuɗi';

  @override
  String get enterReceivingAddress => 'Saka adireshin mai karɓa';

  @override
  String get invalidEthereumAddress =>
      'Adireshin hanyar sadarwa ba shi da kyau';

  @override
  String get enterValidAmount => 'Saka iyakacin kuɗin da kake da shi';

  @override
  String get insufficientBalance => 'Kuɗinka bai isa ba';

  @override
  String get createPasscodeTitle => 'Ƙirƙiri Lambar Sirri';

  @override
  String get createPasscodeDescription =>
      'Saka lambobi shida da kai kaɗai ka sani';

  @override
  String get confirmPasscodeTitle => 'Tabbatar da Lambar Sirri';

  @override
  String get confirmPasscodeDescription => 'Tabbatar da lambobin da ka saka';

  @override
  String get failedToSavePasscode => 'Ba a iya adana lambar sirri ba';

  @override
  String get passcodesDoNotMatch => 'Lambobin ba su zo ɗaya ba. Sake gwadawa.';

  @override
  String get unlockWalletReason => 'Buɗe walat ɗinka';

  @override
  String get unlockEnterPasscode => 'Saka lambar sirrinka';

  @override
  String get lockedOutTitle => 'An kulle ka';

  @override
  String unlockTryAgainIn(Object seconds) {
    return 'Sake gwadawa bayan sakon $seconds';
  }

  @override
  String attemptsRemaining(Object count) {
    return 'Sauran gwaji $count';
  }

  @override
  String incorrectPasscodeRemaining(Object count) {
    return 'Lambar sirri ba ta yi ba. Sauran gwaji $count.';
  }

  @override
  String tooManyAttemptsLocked(Object seconds) {
    return 'Ka saka lambar sirri ba daidai ba sau da yawa. An kulle ka na tsawon sakon $seconds.';
  }

  @override
  String get enterPasscodeTitle => 'Saka Lambar Sirri';

  @override
  String get passcodeHint => 'Lambar Sirri';

  @override
  String get walletNameLabel => 'Sunan Walat';

  @override
  String get enterWalletNameHint => 'Saka sunan walat';

  @override
  String get enterSecretPhraseHint => 'Saka kalmomin sirri guda 12 ko 24';

  @override
  String get secretPhraseHelperText =>
      'Kalmomin sirrinka kalmomi ne guda 12 ko 24 masu tazarar sarari a tsakaninsu';

  @override
  String get paste => 'Manna';

  @override
  String get walletImportedSuccessfully => 'An shigo da walat cikin nasara!';

  @override
  String get enterSecretPhrasePrompt => 'Don Allah saka kalmomin sirrinka';

  @override
  String get enterWalletNamePrompt => 'Don Allah saka sunan walat';

  @override
  String get invalidSecretPhrasePrompt =>
      'Kalmomin sirri ba daidai ba ne. Duba sannan ka sake gwadawa.';

  @override
  String importWalletFailed(Object error) {
    return 'An kasa shigo da walat: $error';
  }

  @override
  String get enterPrivateKeyPrompt => 'Don Allah saka mabuɗin sirrinka';

  @override
  String get invalidPrivateKeyLength =>
      'Mabuɗin sirri ba daidai ba ne. Dole ya zama haruffa ko lambobi 64.';

  @override
  String get invalidPrivateKeyCharacters =>
      'Mabuɗin sirri ba daidai ba ne. Yi amfani da lambobi da haruffa masu kyau.';

  @override
  String get enterPrivateKeyHint => 'Saka mabuɗin sirrinka';

  @override
  String get privateKeyHelperText =>
      'Mabuɗin sirrinka haruffa ne da lambobi 64';

  @override
  String get incorrectPasscode => 'Lambar sirri ba ta yi ba';

  @override
  String get confirm => 'Tabbatar';

  @override
  String get feedbackTitle => 'Ra\'ayi';

  @override
  String get feedbackSubtitle =>
      'Taimaka mana inganta Owllet ta hanyar faɗi mana abin da kake tunani.';

  @override
  String get feedbackCategory => 'Nau\'i';

  @override
  String get feedbackSubjectOptional => 'Taken magana (Zaka iya ƙyale shi)';

  @override
  String get feedbackMessage => 'Saƙo';

  @override
  String get feedbackContactEmailOptional => 'Imeel (Zaka iya ƙyale shi)';

  @override
  String get feedbackCategoryGeneral => 'Gabaɗaya';

  @override
  String get feedbackCategoryBug => 'Rahoton Matsala';

  @override
  String get feedbackCategoryFeature => 'Neman Sabon Abu';

  @override
  String get feedbackCategoryDesign => 'Ra\'ayi kan Tsari';

  @override
  String get feedbackSubjectHint => 'Taƙaitaccen bayani';

  @override
  String get feedbackMessageHint =>
      'Faɗi mana abin da ya faru ko abin da kake buƙata';

  @override
  String get feedbackEmailHint => 'suna@misali.com';

  @override
  String get submitFeedback => 'Aika Ra\'ayi';

  @override
  String get enterFeedbackMessage => 'Don Allah saka saƙon ra\'ayin ka';

  @override
  String get noActiveWalletFound => 'Ba a sami walat mai aiki ba';

  @override
  String get feedbackSubmitted => 'An aika ra\'ayinka. Nagode.';

  @override
  String get feedbackSubmitFailed => 'Ba a iya aika ra\'ayi ba. Sake gwadawa.';

  @override
  String get manageWalletsTitle => 'Sarrafa Walat-walat';

  @override
  String get createAddWallet => 'Ƙirƙiri / Ƙara Walat';

  @override
  String get renameWallet => 'Canza Sunan Walat';

  @override
  String get viewPrivateKey => 'Duba Mabuɗin Sirri';

  @override
  String get removeWallet => 'Cire Walat';

  @override
  String get save => 'Ajiye';

  @override
  String get walletRenamed => 'An canza sunan walat';

  @override
  String get walletRemoved => 'An cire walat';

  @override
  String get unableToLoadWallets => 'An kasa loda walat-walat';

  @override
  String get newWalletCreated => 'An ƙirƙiri sabon walat';

  @override
  String unableToCreateWallet(Object error) {
    return 'An kasa ƙirƙirar walat: $error';
  }

  @override
  String walletSetAsActive(Object name) {
    return 'Yanzu kana amfani da $name';
  }

  @override
  String unableToSwitchWallet(Object error) {
    return 'An kasa canza walat: $error';
  }

  @override
  String unableToRenameWallet(Object error) {
    return 'An kasa canza suna: $error';
  }

  @override
  String unableToRemoveWallet(Object error) {
    return 'An kasa cire walat: $error';
  }

  @override
  String get mustKeepOneWallet => 'Dole ne ka sami aƙalla walat ɗaya';

  @override
  String get removeWalletWarning =>
      'Kuna son cire wannan walat ɗin daga wannan wayar? Wannan ba zai goge walat ɗin daga hanyar sadarwa ba.';

  @override
  String get authenticationRequired => 'Tabbatar da kanka';

  @override
  String get noPrivateKeyFound => 'Ba a sami mabuɗin sirri ba';

  @override
  String get privateKeySecurityWarning =>
      'Kada ka ba kowa wannan. Duk wanda ya samu zai iya yin amfani da kuɗinka.';

  @override
  String get activeWalletLabel => 'Walat mai aiki';

  @override
  String get addToken => 'Ƙara Token';

  @override
  String get authenticateToViewPrivateKey =>
      'Tabbatar da kanka don duba mabuɗin sirrinka';

  @override
  String unableToLoadPrivateKey(Object error) {
    return 'An kasa loda mabuɗin sirri: $error';
  }

  @override
  String get manageTokens => 'Sarrafa Token';

  @override
  String get visibleTokens => 'Token da ke bayyane';

  @override
  String get addedTokens => 'Token da ka ƙara';

  @override
  String get suggestedTokens => 'Token da aka ba da shawara';

  @override
  String get searchResults => 'Sakamakon bincike';

  @override
  String get noTokensDetectedYet =>
      'Ba a ga wani token a cikin wannan walat ɗin ba tukuna.';

  @override
  String get noMatchingTokensFound => 'Ba a sami token da ya dace ba.';

  @override
  String get pasteContractToAddToken =>
      'Manna adireshin contract don ƙara token nan take.';

  @override
  String get noSuggestedTokensYet =>
      'Babu wani token da aka ba da shawara anan tukuna.';

  @override
  String get noRemoteTokensFound => 'Ba a sami wani token ba.';

  @override
  String get tokenRemoved => 'An cire token';

  @override
  String get tokenAlreadyAvailable =>
      'Wannan token ɗin ya riga ya kasance a jerinka';

  @override
  String get tokenAlreadyExistsOnNetwork =>
      'Wannan token ɗin ya riga ya kasance a wannan hanyar sadarwar';

  @override
  String tokenAdded(Object symbol) {
    return 'An ƙara $symbol';
  }

  @override
  String tokenAddFailed(Object error) {
    return 'An kasa ƙara token: $error';
  }

  @override
  String get missingTokenContractAddress => 'Babu adireshin contract na token';

  @override
  String get tokenDetected => 'An Ga Sabon Token';

  @override
  String get contractAddressLabel => 'Adireshin Contract';

  @override
  String get ignore => 'Kyale shi';

  @override
  String get added => 'An ƙara';

  @override
  String get couldNotDetectTokenMetadata =>
      'Ba a iya samun bayanan token a wannan hanyar sadarwar ba';

  @override
  String get myBalance => 'KUƊINA';

  @override
  String get tokenNotFound => 'Ba a sami token ba';

  @override
  String get loading => 'Ana loda...';

  @override
  String get copiedToClipboard => 'An kwafe';

  @override
  String get passwordSecurityTitle => 'Lambar Sirri da Tsaro';

  @override
  String get accessControl => 'Ikon Shiga';

  @override
  String get changePassword => 'Canza Lambar Sirri';

  @override
  String get passcodeUnlock => 'Buɗewa da lambar sirri';

  @override
  String get biometricsFaceId => 'Yatsa / Fuska';

  @override
  String get advancedSecurity => 'Ingantaccen Tsaro';

  @override
  String get twoFactorAuth => 'Tsaro Mataki Biyu (2FA)';

  @override
  String get onLabel => 'A kunne';

  @override
  String get offLabel => 'A kashe';

  @override
  String get autoLockTimer => 'Lokacin Kullewa';

  @override
  String get foregroundAutoLockTimer => 'Kullewa Nan Take';

  @override
  String autoLockMinutesLabel(Object minutes) {
    return 'Minti $minutes';
  }

  @override
  String get lockOnBackground => 'Kullewa idan ka fita daga app';

  @override
  String get immediateWhenAppIsHidden => 'Nan take idan app ya ɓoye';

  @override
  String get securityPreferencesLoadFailed => 'An kasa loda saitunan tsaro';

  @override
  String get retry => 'Sake Gwadawa';

  @override
  String get unableToUpdateBiometric => 'An kasa canza saitin yatsa/fuska';

  @override
  String get unableToUpdateTwoFactor => 'An kasa canza saitin 2FA';

  @override
  String get unableToUpdateAutoLock => 'An kasa canza saitin kullewa';

  @override
  String get unableToUpdateBackgroundLock =>
      'An kasa canza saitin kullewar fita';

  @override
  String get securitySummary => 'Kunna sauran hanyoyin tsaro don kare kuɗinka.';

  @override
  String get searchTokenOrPasteContract =>
      'Nemi token ko ka manna adireshin contract';

  @override
  String get clearSearch => 'Goge bincike';

  @override
  String get createWalletCopiedSeed => 'An kwafe kalmomin sirrinka!';

  @override
  String get secretRecoveryPhrase => 'Kalmomin sirri na gaggawa';

  @override
  String get seedPhraseShareWarning =>
      'Kada ka ba kowa kalmomin sirrinka, koda kuwa yan gidanku ne.';

  @override
  String get tapToReveal => 'Taɓa don gani';

  @override
  String get copyToClipboard => 'Kwafe yanzu';

  @override
  String get beSureNoOneWatching => 'Tabbatar babu kowa na kallon ka';

  @override
  String get verifyAllWords => 'Don Allah saka dukkan kalmomi 12';

  @override
  String get seedPhraseMismatch => 'Kalmomin ba su zo ɗaya ba. Sake gwadawa.';

  @override
  String walletCreationError(Object error) {
    return 'Matsala wajen ƙirƙirar walat: $error';
  }

  @override
  String get referralsHeadline => 'Gayyaci abokai don ku sami lada tare';

  @override
  String get referralsSubtitle =>
      'Sami har \$0.5 idan wanda ka gayyata ya kammala musayar farko mai cancanta ta \$10 ko fiye.';

  @override
  String get yourReferralCode => 'LAMBAR GAYYATAR KA';

  @override
  String get myCode => 'Lambara';

  @override
  String get myReferral => 'Wanda Ya Gayyace Ni';

  @override
  String get noReferral => 'Babu wanda ya gayyace ni';

  @override
  String get rewardsEarned => 'Ladoyin da Na Samu';

  @override
  String get referredUsers => 'Mutanen da Na Gayyata';

  @override
  String referredUsersCount(Object count) {
    return 'Mutane $count';
  }

  @override
  String get addReferral => 'Ƙara Wanda Ya Gayyace Ka';

  @override
  String get enterReferralCode => 'Saka lambar gayyata';

  @override
  String get unableToLoadReferrals => 'An kasa loda mutanen da ka gayyata';

  @override
  String get enterReferralCodePrompt => 'Saka lambar gayyata';

  @override
  String get ownReferralCodeError => 'Ba zaka iya amfani da lambar ka ba';

  @override
  String get referralAdded => 'An ƙara wanda ya gayyace ka';

  @override
  String get unableToAddReferral => 'An kasa ƙara wanda ya gayyace ka';

  @override
  String get referralCodeCopied => 'An kwafe lambar gayyatar ka!';

  @override
  String get refresh => 'Sake Loda';

  @override
  String get backupSeedPhraseTitle => 'Ajiyar Kalmomin Sirri';

  @override
  String get authenticateToViewSeedPhrase =>
      'Tabbatar da kanka don duba kalmomin sirrinka';

  @override
  String get authenticationRequiredSeedPhrase =>
      'Dole ne ka tabbatar da kanka don ganin kalmomin sirri';

  @override
  String get securityWarning => 'Gargaɗin Tsaro';

  @override
  String get seedPhraseMasterKeyWarning =>
      'Kalmomin sirrinka sune mabuɗin walat ɗinka. Duk wanda ya samu zai iya tafi da dukkan kuɗinka.';

  @override
  String get seedPhraseSafetyBullets =>
      '• Kada ka ba kowa\n• Kada ka saka a kowane shafin intanet\n• Rubuta ka ajiye a guri mai kyau';

  @override
  String get iUnderstand => 'Na fahimta';

  @override
  String get noSeedPhraseStored =>
      'Babu kalmomin sirri da aka ajiye don wannan walat ɗin';

  @override
  String get seedPhraseCopied => 'An kwafe kalmomin sirrinka!';

  @override
  String get backupSeedPhraseIntro =>
      'Kalmomin sirrinka guda 12 sune kaɗai hanyar da zaka iya dawo da walat ɗinka idan wayarka ta ɓace ko ka manta lambar sirri.';

  @override
  String unableToOpenLink(Object value) {
    return 'Ba a iya buɗe $value ba';
  }

  @override
  String get searchReceivingToken => 'Nemi token ɗin da zaka karba';

  @override
  String get selectTokenTitle => 'Zaɓi Token';

  @override
  String get checkingStatus => 'Ana dubawa...';

  @override
  String get connected => 'An haɗa';

  @override
  String get noConnection => 'Babu haɗi';

  @override
  String get noInternetConnection => 'Babu Intanet';

  @override
  String tokenAddedFromClipboard(Object symbol) {
    return 'An ƙara $symbol daga clipboard';
  }

  @override
  String networkAddedSuccessfully(Object name) {
    return 'An ƙara $name cikin nasara!';
  }

  @override
  String networkChainIdExists(Object chainId) {
    return 'Hanyar sadarwa mai Chain ID $chainId ta riga ta kasance.';
  }

  @override
  String get networkNameLabel => 'Sunan Hanyar Sadarwa *';

  @override
  String get networkNameHint => 'misali: Cronos, zkSync Era';

  @override
  String get currencySymbolLabel => 'Amiyar Kuɗi *';

  @override
  String get currencySymbolHint => 'misali: CRO, ETH';

  @override
  String get chainIdLabel => 'ID na sarkar*';

  @override
  String get chainIdHint => 'misali: 25, 324';

  @override
  String get requiredField => 'Dole ne ka saka';

  @override
  String get mustBeNumber => 'Dole ya zama lamba';

  @override
  String get autoFillFromChainId => 'Cika da kansa ta amfani da Chain ID';

  @override
  String get enterChainIdHelp =>
      'Saka Chain ID don cika bayanan hanyar sadarwa da kansa.';

  @override
  String get rpcUrlLabel => 'RPC URL*';

  @override
  String get rpcUrlHint => 'https://rpc.example.com';

  @override
  String get mustBeSecureHttps => 'Dole ya zama adireshin (https) mai tsaro';

  @override
  String get rpcReachable => 'RPC na aiki';

  @override
  String get rpcUnreachable => 'RPC ba ya aiki, duba adireshinka';

  @override
  String get blockExplorerOptionalLabel =>
      'URL na Block Explorer (Zaka iya ƙyale)';

  @override
  String get blockExplorerHint => 'https://explorer.example.com';

  @override
  String get trustedNetworkWarning =>
      'Adireshin walat ɗinka na aiki akan dukkanin hanyoyin sadarwa na EVM. Kawai ka ƙara hanyoyin sadarwa da ka yarda dasu.';

  @override
  String get addNetworkAction => 'Ƙara Hanyar Sadarwa';

  @override
  String autoHidesInSeconds(Object seconds) {
    return 'Zai ɓoye nan da daƙiƙa $seconds';
  }

  @override
  String get hide => 'Ɓoye';

  @override
  String get noSeedPhraseAvailablePrivateKey =>
      'Babu kalmomin sirri.\nAn shigo da wannan walat ɗin ne ta hanyar mabuɗin sirri.';

  @override
  String get communityDiscordSubtitle => 'Shiga cikin rukuni';

  @override
  String get communityTelegramSubtitle => 'FOMOWL Channel';

  @override
  String get noNftsToDisplay => 'Babu NFT da za a nuna';

  @override
  String get moreNftsAvailable => 'NFTs sun riga sun bayyana a shafin gida';

  @override
  String get seedPhraseSecureScreenNotice =>
      'An hana ɗaukar hoton waya yayin da waɗannan kalmomin ke bayyane.';

  @override
  String get iBackedItUp => 'Na riga na ajiye';

  @override
  String get seedPhraseVerificationTitle => 'Tabbatar da ajiyarka';

  @override
  String get seedPhraseVerificationSubtitle =>
      'Zaɓi kalmomin da aka nema don tabbatar da cewa ka adana su.';

  @override
  String selectSeedPhraseWord(Object index) {
    return 'Zaɓi kalma ta #$index';
  }

  @override
  String get verifyBackup => 'Tabbatar da ajiyar';

  @override
  String get seedPhraseVerificationFailed =>
      'Wannan cak ɗin ajiyar bai dace ba. Gwada kuma.';

  @override
  String get seedPhraseBackupVerified => 'An tabbatar da madadin jimlar iri';

  @override
  String get seedPhraseBackupVerificationComplete =>
      'An tabbatar da madadin jimlar dawo da ku.';

  @override
  String get confirmSecretPhraseTitle => 'Tabbatar da kalmar sirrinku';

  @override
  String get confirmSecretPhraseCheckOne => 'Ni kadai na san shi.';

  @override
  String get confirmSecretPhraseCheckTwo =>
      'Kalmar sirrin ba ta isa ga wasu mutane na uku.';

  @override
  String get confirmSecretPhraseCheckThree =>
      'Za a iya sace kuɗina idan wani ya ga maganar dawo da ni.';

  @override
  String get adminControlCenter => 'Cibiyar Kula da Owllet';

  @override
  String get adminSystemStatus => 'Yanayin Tsarin';

  @override
  String get adminBackendLatency => 'Latency Backend';

  @override
  String get adminAppPerformance => 'Aikin App';

  @override
  String get adminRegistryTokens => 'Alamar rajista';

  @override
  String get adminTotalUsers => 'Dukkan Mutane';

  @override
  String get adminTransactions => 'Dukkan Ciniki';

  @override
  String get adminMaintainers => 'Masu Kula';

  @override
  String get adminGlobalBroadcast => 'Sanarwa ta Gabaɗaya';

  @override
  String get adminNotificationTitleHint => 'Taken sanarwa';

  @override
  String get adminMessageBodyHint => 'Saƙon sanarwa';

  @override
  String get adminSendToAllUsers => 'Aika wa kowa';

  @override
  String get adminWalletAddressHint => 'Adireshin walat';

  @override
  String get adminNameOptionalHint => 'Suna (Zaka iya ƙyale)';

  @override
  String get adminAddMaintainer => 'Ƙara mai kula';

  @override
  String get adminMaintainerAdded => 'An ƙara mai kula';

  @override
  String get adminMaintainerAddFailed => 'An kasa ƙara mai kula';

  @override
  String get adminTokenRegistry => 'Registry Token';

  @override
  String get adminSearchRegistryHint => 'Nema a cikin registry...';

  @override
  String get adminTokenVerified => 'An tabbatar da token';

  @override
  String get adminTokenUnverified => 'Ba a tabbatar da token ba';

  @override
  String get adminRegistryUpdateFailed => 'An kasa gyara registry';

  @override
  String get adminBroadcastSent => 'An aika sanarwa cikin nasara';

  @override
  String adminBroadcastSentToDevices(Object count) {
    return 'An aika sanarwa zuwa kusan wayoyi $count';
  }

  @override
  String get adminBroadcastFailed => 'Sanarwa ta gaza';

  @override
  String get adminSecretRequired => 'Ana buƙatar mabuɗin kula';

  @override
  String get continueAgreementPrefix => 'Ta hanyar ci gaba, kun yarda da ';

  @override
  String get continueAgreementSuffix => '.';

  @override
  String get termsOfUseLabel => 'Sharuddan amfani';

  @override
  String get andLabel => ' da ';

  @override
  String get privacyPolicyLabel => 'Manufar sirri';

  @override
  String get termsServiceTitle => 'Sharuddan Sabis';

  @override
  String get termsSection1Title => '1. Yarda da Sharudda';

  @override
  String get termsSection1Body =>
      'Ta hanyar girka ko amfani da Owllet kun tabbatar da cewa an ba ku damar doka don riƙe kadarorin dijital kuma kun yarda da waɗannan sharuɗɗan. Idan ba ku yarda ba, goge aikace-aikacen nan take.';

  @override
  String get termsSection2Title => '2. Hakki na Tsaron Kai';

  @override
  String get termsSection2Body =>
      'Owllet kawai yana samar da mabuɗai kuma yana sanya hannu kan ma\'amaloli a cikin wayarka. Kuna sarrafa kalmomin sirri, asusun da aka samo, amincewa, da ma\'amaloli. Ba za mu iya dawo da lambar sirri da aka manta ba, ko mabuɗin kalmomi, ko mabuɗin sirri.';

  @override
  String get termsSection3Title => '3. Ma\'amalolin Blockchain & Kudade';

  @override
  String get termsSection3Body =>
      'Kowane tura kudi, ko amincewa, ko musaya da kuka aika ana watsa shi zuwa hanyar sadarwa ta EVM da kuka zaɓa. Kimanta gas ƙoƙari ne kawai kuma hanyar sadarwa ce ke ƙayyade farashin ƙarshe. Kuna da alhakin tabbatar da adreshin masu karɓa da biyan duk kudaden hanyar sadarwa.';

  @override
  String get termsSection4Title => '4. Ayyukan Wasu & Musanya';

  @override
  String get termsSection4Body =>
      'Manhajar tana dogara ne akan masu samar da RPC (misali, Alchemy da duk wani RPC da kuka ƙara), CoinGecko, da masu zirga-zirgar AMM na jama\'a kamar Uniswap, QuickSwap, PancakeSwap, da SushiSwap. Katsewar sabis, bayanan kasuwa marasa inganci, ko kurakuran kwangilar dijital na iya haifar da asara ko gazawar ma\'amaloli. Ba ma binciken tokens ko kwangilar dijital.';

  @override
  String get termsSection5Title => '5. Bin Dokoki & Haraji';

  @override
  String get termsSection5Body =>
      'Kai ne kawai ke da alhakin tantance ko amfani da Owllet ya halatta a yankinka da biyan duk wani haraji ko wajibcin bayar da rahoto game da ayyukan kadarorin dijital.';

  @override
  String get termsSection6Title => '6. Haramcin Amfani';

  @override
  String get termsSection6Body =>
      'Ba za ku iya amfani da manhajar don ayyukan da ba bisa ka\'ida ba, guje wa takunkumi, rarraba kwayoyin cuta na kwamfuta, ko keta sharuɗɗan kowane blockchain, mai ba da RPC, ko dokar da ta dace. Muna da damar dakatar da damar yin amfani da abubuwan hanyar sadarwa idan aka yi amfani da su ba daidai ba.';

  @override
  String get termsSection7Title => '7. Musanta Garanti';

  @override
  String get termsSection7Body =>
      'Ana bayar da manhajar \"kamar yadda take\" ba tare da kowane irin garanti ba. Ba mu ba da tabbacin cewa bayanan farashin daidai ne, ko kuma ma\'amaloli za su yi nasara, ko kuma babu kuskure a cikin manhajar.';

  @override
  String get termsSection8Title => '8. Iyakar Hakki';

  @override
  String get termsSection8Body =>
      'Har iyakar abin da doka ta amince da shi, ba mu da alhakin bataccen kuɗi, bataccen mabuɗin kalmomi, asarar kasuwa, ko duk wata matsala da ta taso daga amfani da manhajar.';

  @override
  String get termsSection9Title => '9. Canje-canje & Tuntuɓa';

  @override
  String get termsSection9Body =>
      'Za mu iya sabunta waɗannan sharuɗɗan yayin da muke ƙaddamar da sabbin abubuwa. Ci gaba da amfani bayan canji yana nufin kun yarda da sabbin sharuɗɗan. Tuntuɓe mu a X (@fomowlhq) idan kuna buƙatar bayani.';

  @override
  String get termsEffectiveDate => 'Ranar fara aiki: Fabrairu 2026';

  @override
  String get privacyPolicyTitle => 'Manufar Sirri';

  @override
  String get privacySection1Title => '1. Bayani na Gabaɗaya';

  @override
  String get privacySection1Body =>
      'Owllet walat ne na tsaron kai wanda ke aiki akan EVM kawai. Dukkan samar da mabuɗai ana yin sa ne a cikin wayarka ta amfani da amintattun ɗakunan karatu na BIP-39/BIP-32. Ba ma riƙe asusunka ko kadarorinka.';

  @override
  String get privacySection2Title => '2. Bayanan da Aka Adana a Wayarka';

  @override
  String get privacySection2Body =>
      'Muna adana abubuwa masu zuwa ta amfani da Flutter Secure Storage ko SharedPreferences a cikin wayarka:\n• Sunayen walat, adireshi, da bayanan asali\n• Mabuɗan sirri da aka rufe, kalmomin sirri, da lambar sirrinka\n• Saitunan biometrik da yarenka\nGoge manhajar ko bayanan wayarka zai goge waɗannan bayanan har abada. Ba sa fita daga wayarka.';

  @override
  String get privacySection3Title => '3. Ayyukan Wasu';

  @override
  String get privacySection3Body =>
      'Don nuna kudi, bayanan farashi, da yin musanya, manhajar tana haɗawa kai tsaye da:\n• Masu samar da RPC kamar Alchemy da duk wani RPC da kuka ƙara\n• CoinGecko don bayanan kasuwa da jadawali\n• Masu zirga-zirgar AMM na jama\'a (Uniswap, QuickSwap, PancakeSwap, SushiSwap, da sauransu)\nWaɗannan masu samarwa na iya adana adireshin IP bisa ga manufofinsu.';

  @override
  String get privacySection4Title => '4. Izinin Wayar';

  @override
  String get privacySection4Body =>
      'Ana amfani da kyamara ne kawai don duba lambar QR. Saitunan biometrik (Face/Touch ID, yatsa) tsarin wayarka ne ke sarrafa su; muna karɓar nasara ko gazawa kawai. Ba ma shiga hotunanka, kiran waya, makirufo, ko inda kake.';

  @override
  String get privacySection5Title => '5. Hakki na Kanka';

  @override
  String get privacySection5Body =>
      '• Ka adana mabuɗin kalmominka guda 12 a waje da wayarka kuma kada ka taɓa raba su da kowa\n• Ka tabbatar da adreshin da kake tura kudi kafin ka sanya hannu\n• Ka sanya wa wayarka lamba mai ƙarfi da biometrik\n• Ka gane cewa ma\'amalolin blockchain ba sa canzawa bayan an yi su';

  @override
  String get privacySection6Title => '6. Sabuntawa & Tuntuɓa';

  @override
  String get privacySection6Body =>
      'Za mu iya sabunta wannan sanarwar yayin da muke ƙara sabbin ayyuka. Sabon sigar koyaushe tana cikin manhajar. Tuntuɓe mu a X (@fomowlhq) idan kuna da tambayoyi.';

  @override
  String get privacyLastUpdated => 'An sabunta ƙarshe: Fabrairu 2026';

  @override
  String get faceVerifyReason => 'Tabbatar da asalin ku tare da ID na Fuskar';

  @override
  String get faceVerificationFailed =>
      'Tabbatar da fuska ya gaza. Da fatan za a sake gwadawa.';

  @override
  String get biometricUnavailable =>
      'Babu tabbacin biometric akan wannan na\'urar.';

  @override
  String get verifying => 'Tabbatarwa...';

  @override
  String get faceVerificationTitle => 'Tabbatar da fuska';

  @override
  String get biometricPromptInstruction =>
      'Sanya fuskarka a cikin firam don tabbatarwa';

  @override
  String get facePromptInstruction => 'Sanya fuskarka a cikin da\'irar sama';

  @override
  String get verifyFace => 'Tabbatar da Fuska';

  @override
  String get identityVerifyReason => 'Tabbatar da asalin ku don ci gaba';

  @override
  String get biometricVerificationFailed =>
      'Tabbacin biometric ya gaza. Da fatan za a sake gwadawa.';

  @override
  String get biometricVerificationFailedWithPasscode =>
      'Tabbacin biometric ya gaza. Da fatan za a yi amfani da lambar wucewar ku maimakon.';

  @override
  String get biometricVerificationTitle => 'Tabbatar da Biometric';

  @override
  String get tapBelowToVerify => 'Matsa ƙasa don tabbatarwa';

  @override
  String get startVerification => 'Fara Tabbatarwa';

  @override
  String get fingerprintVerifyReason => 'Tabbatar da asalin ku da sawun yatsa';

  @override
  String get fingerprintVerificationFailed =>
      'Tabbatar da sawun yatsa ya kasa. Da fatan za a sake gwadawa.';

  @override
  String get fingerprintVerificationTitle => 'Tabbatar da Sawun yatsa';

  @override
  String get fingerprintPromptInstruction =>
      'Sanya yatsanka akan firikwensin don tabbatarwa';

  @override
  String get verify => 'Tabbatar';

  @override
  String get swapFromLabel => 'Daga';

  @override
  String get priceLabel => 'Farashin';

  @override
  String get platformFeeLabel => 'Kuɗin Platform';

  @override
  String get networkFeeLabel => 'Kudin hanyar sadarwa';

  @override
  String get coveredByOwllet => 'Owllet ne ya rufe';

  @override
  String get toReceiveLabel => 'Don Karɓa';

  @override
  String get swapToLabel => 'Zuwa';

  @override
  String get calculatingLabel => 'Ana lissafin...';

  @override
  String get receiveTokenTitle => 'Karɓi Token';

  @override
  String get receiveExternalWarning =>
      'Kawai aika alamu akan hanyar sadarwa daidai. Aika alamu akan hanyar sadarwar da ba daidai ba na iya haifar da asara ta dindindin.';

  @override
  String get currencyUsd => 'Dalar Amurka (USD)';

  @override
  String get currencyEur => 'Yuro (EUR)';

  @override
  String get currencyGbp => 'Fam na Ingila (GBP)';

  @override
  String get currencyNgn => 'Naira (NGN)';

  @override
  String get selectTokenAndNetwork => 'ZAƁI TOKEN DA CIBIYAR SADARWA';

  @override
  String get networkLabel => 'Cibiyar sadarwa';

  @override
  String get noNotificationsYet => 'Babu sanarwa tukuna';

  @override
  String get availableBalance => 'KUƊIN DA AKE DA SU';

  @override
  String get history => 'Tarihi';

  @override
  String get followSocialhq => 'Bi @fomowlhq a X don samun sababbin labarai';

  @override
  String get socialhqHandle => 'x.com/fomowlhq';
}
