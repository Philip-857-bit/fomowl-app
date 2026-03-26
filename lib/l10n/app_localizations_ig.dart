// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Igbo (`ig`).
class AppLocalizationsIg extends AppLocalizations {
  AppLocalizationsIg([String locale = 'ig']) : super(locale);

  @override
  String get appName => 'Owllet';

  @override
  String get welcomeTitle => 'Nnọọ, I loola Owlian';

  @override
  String get welcomeSubtitle =>
      'Mepụta obere akpa gị echedoro, detuo ya ma banye n\'ime usoro Owllet';

  @override
  String get createWallet => 'Mepụta Obere Akpa';

  @override
  String get importWallet => 'Bubata Obere Akpa';

  @override
  String get chooseLanguage => 'Họrọ asụsụ gị';

  @override
  String get chooseDesiredLanguage => 'Họrọ asụsụ ị chọrọ';

  @override
  String get tradeInstantly => 'Zụọ ahịa ozugbo.';

  @override
  String get spendEffortlessly => 'Mefuo ego n\'enweghị nsogbu.';

  @override
  String get getStarted => 'Bido ugbu a';

  @override
  String get alreadyHaveWallet => 'Ị nwere obere akpa mbụ?';

  @override
  String get importExistingWallet => 'Bubata obere akpa dị adị';

  @override
  String get secretPhrase => 'Okwu Nzuzo';

  @override
  String get privateKey => 'Igodo Nzuzo';

  @override
  String get enterPasscode => 'Tinye koodu';

  @override
  String get confirmPasscode => 'Gosi koodu';

  @override
  String get setupBiometric => 'Tọọ ika ma ọ bụ ihu';

  @override
  String get enableFaceId => 'Gbanwuo ID ihu';

  @override
  String get enableFingerprint => 'Gbanwuo akara aka';

  @override
  String get skip => 'Mafere';

  @override
  String get continue_ => 'Gaa n\'ihu';

  @override
  String get home => 'Ebe Obibi';

  @override
  String get wallet => 'Obere Akpa';

  @override
  String get swap => 'Gbanwee';

  @override
  String get earn => 'Nweta';

  @override
  String get payment => 'Ịkwụ ụgwọ';

  @override
  String get me => 'Mụ onwe m';

  @override
  String get settings => 'Ntọala';

  @override
  String get balance => 'Ego fọdụrụ';

  @override
  String get tokens => 'Token';

  @override
  String get nfts => 'NFT';

  @override
  String get loadingBalances => 'Na-ebupụta ego...';

  @override
  String get noTokensYet => 'Enweghị token ọ bụla ebe a';

  @override
  String get depositTokens => 'Tinye token ka i nwee ike bido';

  @override
  String get totalBalance => 'Ego niile';

  @override
  String get nftPreview => 'NFT nlele';

  @override
  String get viewAll => 'Hụ ihe niile';

  @override
  String get noNftsFound => 'Ahụghị NFT ọ bụla';

  @override
  String get nftPreviewDescription =>
      'NFT gị ga-apụta ebe a n\'elu netwọk na-akwado ya.';

  @override
  String get send => 'Zipụ';

  @override
  String get receive => 'Nweta';

  @override
  String get buy => 'Zụta';

  @override
  String get sell => 'Ree';

  @override
  String get wallets => 'Obere akpa niile';

  @override
  String get activeWallet => 'OBERE AKPA NA-ARỤ ỌRỤ';

  @override
  String get addWallet => 'Tinye Obere Akpa';

  @override
  String get createNewWallet => 'Mepụta Obere Akpa Ọhụrụ';

  @override
  String get importSeedPhrase => 'Bubata Okwu Nzuzo';

  @override
  String get importPrivateKey => 'Bubata Igodo Nzuzo';

  @override
  String get mainWallet => 'Isi Obere Akpa';

  @override
  String get addressCopied => 'E depụtaghachiri adreesị gị!';

  @override
  String get profile => 'Profaịlụ gị';

  @override
  String get general => 'Izugbe';

  @override
  String get manageWallets => 'Njikwa Obere Akpa';

  @override
  String get switchNetwork => 'Gbanwee Netwọk';

  @override
  String get currency => 'Ego';

  @override
  String get chooseYourLanguage => 'Họrọ Asụsụ Gị';

  @override
  String get referrals => 'Ndị ị kpọbatara';

  @override
  String get security => 'Nchekwa';

  @override
  String get others => 'Ndị ọzọ';

  @override
  String get passwordSecurity => 'Paswọdụ na Nchekwa';

  @override
  String get network => 'Netwọk';

  @override
  String get selectNetwork => 'Họrọ Netwọk';

  @override
  String get addCustomNetwork => 'Tinye Netwọk Ọhụrụ';

  @override
  String get seedPhraseBackup => 'Detuo Okwu Nzuzo';

  @override
  String get resetWallet => 'Tọgharịa Obere Akpa';

  @override
  String get privacyPolicy => 'Iwu Nzuzo';

  @override
  String get termsOfService => 'Usoro Ọrụ';

  @override
  String get feedback => 'Nzaghachi';

  @override
  String get joinOurCommunity => 'Soro anyị n\'otu';

  @override
  String get resetApp => 'Tọgharịa App';

  @override
  String get noNftsYet => 'Enweghị NFT mbụ';

  @override
  String get nftCollection => 'Nchịkọta NFT';

  @override
  String get nftGalleryScanning => 'Na-enyocha NFTs...';

  @override
  String get nftGalleryEmptyDescription =>
      'Nchịkọta NFT gị ga-apụta ebe a.\nZụta ma ọ bụ nata NFTs na chain ọ bụla a na-akwado.';

  @override
  String nftGalleryUnsupportedChain(Object chain) {
    return 'A naghị akwado NFT gallery na $chain ugbu a.\nGbanwee gaa Ethereum, BNB Smart Chain, Polygon, Arbitrum, Optimism, ma ọ bụ Base.';
  }

  @override
  String get failedToLoadNftsTitle => 'Enweghị ike ibudata NFTs';

  @override
  String failedToLoadNftsWithError(Object error) {
    return 'Enweghị ike ibudata NFTs: $error';
  }

  @override
  String get officialProjectNft => 'NFT ọrụ gọọmentị';

  @override
  String get transactionHistory => 'Akụkọ Azụmahịa';

  @override
  String get allLabel => 'Niile';

  @override
  String get allChains => 'Chains niile';

  @override
  String get notifications => 'Ịma Ọkwa';

  @override
  String get notificationsSettings => 'Nhazi Ọkwa';

  @override
  String get enablePushNotifications => 'Mee ka Ọkwa Push rụọ ọrụ';

  @override
  String get pushNotificationsDesc =>
      'Nweta ọkwa maka nkwụnye ego, nnyefe, na mmelite nchekwa.';

  @override
  String get transactionBroadcast => 'Ezipụlarị azụmahịa gị!';

  @override
  String get transactionFailed => 'Azụmahịa agaghị nke ọma';

  @override
  String get confirmTransfer => 'Gosi Nzipụ';

  @override
  String get gasFee => 'Ụgwọ Netwọk';

  @override
  String get transactionDetails => 'NKỌWA AZỤMAHỊA';

  @override
  String get closeLabel => 'Mechie';

  @override
  String get viewOnExplorer => 'Lee na Explorer';

  @override
  String get unknownNetwork => 'Network a na-amaghị';

  @override
  String get walletHistoryFallbackWarning =>
      'A na-egosi explorer history nke chain na-arụ ọrụ mgbe wallet history adịghị.';

  @override
  String get walletHistoryLoadError =>
      'Enweghị ike ibudata wallet history ugbu a.';

  @override
  String get walletHistoryEmpty => 'Enweghị wallet history ugbu a';

  @override
  String get historyTransferReceived => 'Anatara nnyefe';

  @override
  String get historyTransferSent => 'E zigara nnyefe';

  @override
  String historyReceivedAmountOnNetwork(Object amount, Object network) {
    return 'Anatara $amount na $network.';
  }

  @override
  String historySentAmountOnNetwork(Object amount, Object network) {
    return 'E zigara $amount na $network.';
  }

  @override
  String historySwapOnNetwork(Object network) {
    return 'ọrụ mgbanwe na $network.';
  }

  @override
  String historyActivityOnNetwork(Object network) {
    return 'ọrụ na $network.';
  }

  @override
  String get historyTimestampLabel => 'Oge';

  @override
  String get historyTransactionHashLabel => 'Hash azụmahịa';

  @override
  String get historyReceiptUnavailable =>
      'Nkọwa risiti adịghị maka ihe ndekọ a ugbu a.';

  @override
  String get historyLoadingReceipt => 'Na-ebudata nkọwa risiti...';

  @override
  String get historyReceiptLoadError =>
      'Enweghị ike ibudata nkọwa risiti ugbu a.';

  @override
  String get historyReceiptPending =>
      'Risiti adịghị ugbu a. O nwere ike ịbụ na azụmahịa ka na-echere ma ọ bụ RPC a akabeghị inye ya.';

  @override
  String get historyStatusLabel => 'Ọnọdụ';

  @override
  String get historyBlockNumberLabel => 'Nọmba block';

  @override
  String get historyFromLabel => 'Site na';

  @override
  String get historyToLabel => 'Ruo';

  @override
  String get historyGasUsedLabel => 'Gas ejiri';

  @override
  String get historyGasPriceLabel => 'Ọnụ gas';

  @override
  String get historyContractAddressLabel => 'Adịreshị nkwekọrịta';

  @override
  String get historyLogCountLabel => 'Logs';

  @override
  String get tokenLabel => 'Token';

  @override
  String get confirmedLabel => 'Ekwadoro';

  @override
  String get failedLabel => 'Dara';

  @override
  String get pendingLabel => 'Na-echere';

  @override
  String get swapPreparingTitle => 'Na-akwadebe...';

  @override
  String get swapPreparingSubtitle => 'Anyị na-akwadebe nlegharị anya gị.';

  @override
  String get swapApprovalProcessingTitle => 'Na-achọ nkwado...';

  @override
  String get swapApprovalProcessingSubtitle =>
      'Kwapụta iji token ma chere nkwenye netwọk.';

  @override
  String get swapSubmittingTitle => 'Na-ezipụ nlegharị anya...';

  @override
  String get swapSubmittingSubtitle => 'A na-ezipụ azụmahịa gị na netwọk.';

  @override
  String get swapGaslessSubmittingTitle => 'Na-ezipụ n\'ụgwọ netwọk...';

  @override
  String get swapGaslessSubmittingSubtitle => 'Owllet na-ezipụ azụmahịa gị.';

  @override
  String get swapProcessingTitle => 'Azụmahịa na-aga n\'ihu...';

  @override
  String get swapProcessingSubtitle => 'Nke a nwere ike iwe nkeji ole na ole.';

  @override
  String get swapGaslessProcessingSubtitle => 'Owllet na-arụ ọrụ na ya.';

  @override
  String get swapCompletedTitle => 'Azụmahịa agafeela';

  @override
  String get swapCompletedSubtitle => 'E nwetara nkwenye azụmahịa gị nke ọma.';

  @override
  String get swapFailedTitle => 'Azụmahịa adaghị';

  @override
  String get noQuoteAvailable => 'Enweghị ọnụahịa dị';

  @override
  String get noRouterQuoteAvailable => 'Enweghị ụzọ dị';

  @override
  String get approvalPendingConfirmation =>
      'Nkwenye ka na-echere. Biko lelee ma e mesịa.';

  @override
  String get transactionPendingConfirmation =>
      'Azụmahịa na-echere nkwenye. Biko lelee ma e mesịa.';

  @override
  String get gaslessOrderFailedRetry => 'Nzipụ adaghị. Biko gbalịa ọzọ.';

  @override
  String get swapMissingHash =>
      'E ziri azụmahịa mana ahụghị koodu ya. Biko lelee ma e mesịa.';

  @override
  String get transferPreparingTitle => 'Na-akwadebe nnyefe...';

  @override
  String get transferApprovalPendingTitle => 'Nkwenye nnyefe ka na-echere';

  @override
  String get transferSubmittingTitle => 'Na-eziga nnyefe...';

  @override
  String get transferInProgressTitle => 'Nnyefe na-aga n\'ihu';

  @override
  String get transferCompletedTitle => 'Emechaala nnyefe';

  @override
  String get transferFailedTitle => 'Nnyefe dara';

  @override
  String get transferPreparingSubtitle => 'A na-akwadebe nnyefe gị maka iziga.';

  @override
  String get transferApprovalPendingSubtitle =>
      'Biko chere ka network hazie nkwenye ahụ.';

  @override
  String get transferSubmittingSubtitle => 'A na-ebufe nnyefe gị na network.';

  @override
  String get transferInProgressSubtitle =>
      'Na-eche ka network kwado nnyefe gị.';

  @override
  String get transferCompletedSubtitle => 'Ekwadoro nnyefe gị nke ọma.';

  @override
  String get genericTransactionPreparingTitle => 'Na-akwadebe azụmahịa...';

  @override
  String get genericTransactionApprovalPendingTitle => 'Nkwenye ka na-echere';

  @override
  String get genericTransactionSubmittingTitle => 'Na-eziga azụmahịa...';

  @override
  String get genericTransactionInProgressTitle => 'Azụmahịa na-aga n\'ihu';

  @override
  String get genericTransactionCompletedTitle => 'Emechaala azụmahịa';

  @override
  String get genericTransactionPreparingSubtitle =>
      'A na-akwadebe azụmahịa gị.';

  @override
  String get genericTransactionApprovalPendingSubtitle =>
      'Biko chere ka network hazie nkwenye ahụ.';

  @override
  String get genericTransactionSubmittingSubtitle =>
      'A na-ebufe azụmahịa gị na network.';

  @override
  String get genericTransactionInProgressSubtitle =>
      'Na-eche ka network kwado azụmahịa gị.';

  @override
  String get genericTransactionCompletedSubtitle =>
      'Ekwadoro azụmahịa gị nke ọma.';

  @override
  String get transferWarningMessage =>
      'Lelee adreesị onye ị na-eziri ego nke ọma. Azụmahịa emechara adịghị agbanwe agbanwe.';

  @override
  String get maxTotal => 'EGO NIILE';

  @override
  String get amount => 'EGO';

  @override
  String get estimationFailed => 'Ihe atụ adaghị';

  @override
  String get networkError => 'Nsogbu netwọk';

  @override
  String get connectionFailed => 'Ịntanetị adaghị. Lelee njikọ gị.';

  @override
  String get tryAgain => 'Gbalịa Ọzọ';

  @override
  String get comingSoon => 'Ọ na-abịa n\'oge adịghị anya';

  @override
  String get congratulations => 'Ekele diri gị!';

  @override
  String get walletCreated => 'Emechaala mepụta obere akpa gị nke ọma';

  @override
  String get walletImported => 'Emechaala bubata obere akpa gị nke ọma';

  @override
  String get goToWallet => 'Gaa n\'obere akpa';

  @override
  String get resetFailed => 'Enweghị ike itọgharịa app. Biko gbalịa ọzọ.';

  @override
  String get confirmClearLocalData =>
      'Nke a ga-ehichapụ profulụ obere akpa niile dị na foonu a. Gbaa mbọ hụ na i nwere okwu nzuzo gị ebe dị mma.';

  @override
  String get cancel => 'Kagbuo';

  @override
  String get actionRequired => 'Ihe dị mkpa ka i mee';

  @override
  String get sendToken => 'Zipụ Ego';

  @override
  String get enterReceivingAddress => 'Biko tinye adreesị onye na-anata ego';

  @override
  String get invalidEthereumAddress => 'Adreesị netwọk adịghị mma';

  @override
  String get enterValidAmount => 'Biko tinye ego ziri ezi';

  @override
  String get insufficientBalance => 'Ego gị ezughị';

  @override
  String get createPasscodeTitle => 'Mepụta Koodu';

  @override
  String get createPasscodeDescription =>
      'Tinye nọmba isii ị ga-eji na-emepe app a';

  @override
  String get confirmPasscodeTitle => 'Gosi Koodu';

  @override
  String get confirmPasscodeDescription => 'Gosi nọmba ndị ahụ ị tinyere';

  @override
  String get failedToSavePasscode => 'Enweghị ike idowe koodu gị';

  @override
  String get passcodesDoNotMatch => 'Nọmba ndị ahụ adabaghị. Gbalịa ọzọ.';

  @override
  String get unlockWalletReason => 'Mepee obere akpa gị';

  @override
  String get unlockEnterPasscode => 'Tinye koodu gị';

  @override
  String get lockedOutTitle => 'A kpọchiri gị n\'èzí';

  @override
  String unlockTryAgainIn(Object seconds) {
    return 'Gbalịa ọzọ n\'ime sekọnd $seconds';
  }

  @override
  String attemptsRemaining(Object count) {
    return 'Nnwale fọdụrụ: $count';
  }

  @override
  String incorrectPasscodeRemaining(Object count) {
    return 'Koodu adịghị mma. Nnwale fọdụrụ: $count.';
  }

  @override
  String tooManyAttemptsLocked(Object seconds) {
    return 'I tinyela koodu na-adịghị mma ọtụtụ ugboro. A kpọchiri gị sekọnd $seconds.';
  }

  @override
  String get enterPasscodeTitle => 'Tinye Koodu';

  @override
  String get passcodeHint => 'Koodu';

  @override
  String get walletNameLabel => 'Aha Obere Akpa';

  @override
  String get enterWalletNameHint => 'Tinye aha obere akpa';

  @override
  String get enterSecretPhraseHint => 'Tinye okwu nzuzo 12 ma ọ bụ 24 gị';

  @override
  String get secretPhraseHelperText =>
      'Okwu nzuzo gị bụ mkpụrụokwu 12 ma ọ bụ 24 nwere ohere n\'etiti ha';

  @override
  String get paste => 'Namado';

  @override
  String get walletImportedSuccessfully =>
      'Emechaala bubata obere akpa gị nke ọma!';

  @override
  String get enterSecretPhrasePrompt => 'Biko tinye okwu nzuzo gị';

  @override
  String get enterWalletNamePrompt => 'Biko tinye aha obere akpa';

  @override
  String get invalidSecretPhrasePrompt =>
      'Okwu nzuzo adịghị mma. Biko lelee ya ma gbalịa ọzọ.';

  @override
  String importWalletFailed(Object error) {
    return 'Enweghị ike ibubata obere akpa: $error';
  }

  @override
  String get enterPrivateKeyPrompt => 'Biko tinye igodo nzuzo gị';

  @override
  String get invalidPrivateKeyLength =>
      'Igodo nzuzo adịghị mma. Ọ ga-abụ mkpụrụ lẹta/nọmba 64.';

  @override
  String get invalidPrivateKeyCharacters =>
      'Igodo nzuzo adịghị mma. Jiri nọmba na lẹta ziri ezi.';

  @override
  String get enterPrivateKeyHint => 'Tinye igodo nzuzo gị';

  @override
  String get privateKeyHelperText =>
      'Igodo nzuzo gị bụ mkpụrụ lẹta na nọmba 64';

  @override
  String get incorrectPasscode => 'Koodu adịghị mma';

  @override
  String get confirm => 'Kwapụta';

  @override
  String get feedbackTitle => 'Nzaghachi';

  @override
  String get feedbackSubtitle =>
      'Nyere anyị aka mee ka Owllet dị mma site n\'ịgwa anyị ihe ị chere.';

  @override
  String get feedbackCategory => 'Ụdị';

  @override
  String get feedbackSubjectOptional => 'Isiokwu (Nwere ike ịhapụ ya)';

  @override
  String get feedbackMessage => 'Ozi';

  @override
  String get feedbackContactEmailOptional => 'Imeeli (Nwere ike ịhapụ ya)';

  @override
  String get feedbackCategoryGeneral => 'Izugbe';

  @override
  String get feedbackCategoryBug => 'Akụkọ Maka Nsogbu';

  @override
  String get feedbackCategoryFeature => 'Ihe Ị Chọrọ ka A Tinye';

  @override
  String get feedbackCategoryDesign => 'Maka Otú Ihe Dị';

  @override
  String get feedbackSubjectHint => 'Mkpụmkpụ ihe ọ gbasara';

  @override
  String get feedbackMessageHint => 'Gwa anyị ihe merenụ ma ọ bụ ihe ị chọrọ';

  @override
  String get feedbackEmailHint => 'aha@omume.com';

  @override
  String get submitFeedback => 'Zipụ Nzaghachi';

  @override
  String get enterFeedbackMessage => 'Biko tinye ozi gị';

  @override
  String get noActiveWalletFound => 'Ahụghị obere akpa na-arụ ọrụ';

  @override
  String get feedbackSubmitted => 'Ezipụlarị nzaghachi gị. Imeela.';

  @override
  String get feedbackSubmitFailed => 'Enweghị ike izipu nzaghachi. Gbalịa ọzọ.';

  @override
  String get manageWalletsTitle => 'Njikwa Obere Akpa';

  @override
  String get createAddWallet => 'Mepụta / Tinye Obere Akpa';

  @override
  String get renameWallet => 'Gbanwee Aha Obere Akpa';

  @override
  String get viewPrivateKey => 'Lee Igodo Nzuzo';

  @override
  String get removeWallet => 'Wepụ Obere Akpa';

  @override
  String get save => 'Chekwaa';

  @override
  String get walletRenamed => 'Emechaala gbanwee aha obere akpa';

  @override
  String get walletRemoved => 'Ewepụla obere akpa';

  @override
  String get unableToLoadWallets => 'Enweghị ike ibupụta obere akpa';

  @override
  String get newWalletCreated => 'Emepụtara obere akpa ọhụrụ';

  @override
  String unableToCreateWallet(Object error) {
    return 'Enweghị ike imepụta obere akpa: $error';
  }

  @override
  String walletSetAsActive(Object name) {
    return 'Ị na-eji $name ugbu a';
  }

  @override
  String unableToSwitchWallet(Object error) {
    return 'Enweghị ike ịgbanwee obere akpa: $error';
  }

  @override
  String unableToRenameWallet(Object error) {
    return 'Enweghị ike ịgbanwee aha: $error';
  }

  @override
  String unableToRemoveWallet(Object error) {
    return 'Enweghị ike iwepụ obere akpa: $error';
  }

  @override
  String get mustKeepOneWallet => 'Ị ga-enwerịrị opekata mpe otu obere akpa';

  @override
  String get removeWalletWarning =>
      'Ị chọrọ iwepụ obere akpa a na foonu a? Nke a agaghị ehichapụ obere akpa gị na netwọk.';

  @override
  String get authenticationRequired => 'Gosi onye ị bụ';

  @override
  String get noPrivateKeyFound => 'Ahụghị igodo nzuzo ọ bụla';

  @override
  String get privateKeySecurityWarning =>
      'Enyela onye ọ bụla ihe a. Onye ọ bụla nwere ya nwere ike iji ego gị.';

  @override
  String get activeWalletLabel => 'Obere akpa na-arụ ọrụ';

  @override
  String get addToken => 'Tinye Token';

  @override
  String get authenticateToViewPrivateKey =>
      'Gosi onye ị bụ ka i nwee ike hụ igodo nzuzo gị';

  @override
  String unableToLoadPrivateKey(Object error) {
    return 'Enweghị ike ibupụta igodo nzuzo: $error';
  }

  @override
  String get manageTokens => 'Njikwa Token';

  @override
  String get visibleTokens => 'Token na-apụta';

  @override
  String get addedTokens => 'Token ndị i tinyere';

  @override
  String get suggestedTokens => 'Token ndị a kwadoro';

  @override
  String get searchResults => 'Ihe a chọtara';

  @override
  String get noTokensDetectedYet => 'Ahụghị token ọ bụla n\'obere akpa a.';

  @override
  String get noMatchingTokensFound => 'Ahụghị token kwekọrọ na ya.';

  @override
  String get pasteContractToAddToken =>
      'Namado adreesị contract ka i nwee ike tinye token ozugbo.';

  @override
  String get noSuggestedTokensYet => 'Enweghị token mbụ a kwadoro ebe a.';

  @override
  String get noRemoteTokensFound => 'Ahụghị token ọ bụla.';

  @override
  String get tokenRemoved => 'Ewepụla token';

  @override
  String get tokenAlreadyAvailable => 'Token a adịworị na listi gị';

  @override
  String get tokenAlreadyExistsOnNetwork => 'Token a adịworị na netwọk a';

  @override
  String tokenAdded(Object symbol) {
    return 'Etinyela $symbol';
  }

  @override
  String tokenAddFailed(Object error) {
    return 'Enweghị ike itinye token: $error';
  }

  @override
  String get missingTokenContractAddress => 'Adreesị contract token na-efu efu';

  @override
  String get tokenDetected => 'Ahụrụ Token Ọhụrụ';

  @override
  String get contractAddressLabel => 'Adreesị Contract';

  @override
  String get ignore => 'Hapụ ya';

  @override
  String get added => 'Etinyela ya';

  @override
  String get couldNotDetectTokenMetadata =>
      'Enweghị ike ịnweta ozi maka token a na netwọk a';

  @override
  String get myBalance => 'EGO M';

  @override
  String get tokenNotFound => 'Ahụghị token ahụ';

  @override
  String get loading => 'Na-ebupụta...';

  @override
  String get copiedToClipboard => 'E depụtaghachiri ya';

  @override
  String get passwordSecurityTitle => 'Paswọdụ na Nchekwa';

  @override
  String get accessControl => 'Njikwa Mbanye';

  @override
  String get changePassword => 'Gbanwee Paswọdụ';

  @override
  String get passcodeUnlock => 'Iji koodu meghee ya';

  @override
  String get biometricsFaceId => 'Akara aka / Ihu';

  @override
  String get advancedSecurity => 'Nchekwa Dị Elu';

  @override
  String get twoFactorAuth => 'Nchekwa Okpukpu Abụọ (2FA)';

  @override
  String get onLabel => 'Gbanye';

  @override
  String get offLabel => 'Gbanyụọ';

  @override
  String get autoLockTimer => 'Oge eji akpọchi ya';

  @override
  String get foregroundAutoLockTimer => 'Oge eji akpọchi ozugbo';

  @override
  String autoLockMinutesLabel(Object minutes) {
    return 'Nkeji $minutes';
  }

  @override
  String get lockOnBackground => 'Kpọchie ma i pụọ na app';

  @override
  String get immediateWhenAppIsHidden => 'Ozugbo app roro';

  @override
  String get securityPreferencesLoadFailed =>
      'Enweghị ike ibupụta ntọala nchekwa';

  @override
  String get retry => 'Gbalịa Ọzọ';

  @override
  String get unableToUpdateBiometric => 'Enweghị ike ịgbanwee ntọala biometric';

  @override
  String get unableToUpdateTwoFactor => 'Enweghị ike ịgbanwee ntọala 2FA';

  @override
  String get unableToUpdateAutoLock => 'Enweghị ike ịgbanwee oge akpọchi';

  @override
  String get unableToUpdateBackgroundLock =>
      'Enweghị ike ịgbanwee ntọala mkpọchi azụ';

  @override
  String get securitySummary => 'Gbanwuo nchekwa ndị ọzọ iji chebe ego gị.';

  @override
  String get searchTokenOrPasteContract =>
      'Chọọ token ma ọ bụ namado adreesị contract';

  @override
  String get clearSearch => 'Hichapụ ihe ị na-achọ';

  @override
  String get createWalletCopiedSeed => 'E depụtaghachiri okwu nzuzo gị!';

  @override
  String get secretRecoveryPhrase => 'Okwu nzuzo nnapụta';

  @override
  String get seedPhraseShareWarning =>
      'Enyela onye ọ bụla okwu nzuzo gị, ma ndị ezinụlọ gị.';

  @override
  String get tapToReveal => 'Pịa ka i hụ ya';

  @override
  String get copyToClipboard => 'Depụtaghachi ya';

  @override
  String get beSureNoOneWatching => 'Gbaa mbọ hụ na ọ dịghị onye na-ele gị';

  @override
  String get verifyAllWords => 'Biko tinye okwu 12 niile';

  @override
  String get seedPhraseMismatch => 'Okwu nzuzo adabaghị. Biko gbalịa ọzọ.';

  @override
  String walletCreationError(Object error) {
    return 'Njehie na imepụta obere akpa: $error';
  }

  @override
  String get referralsHeadline => 'Kpọọ ndị enyi ma nweta ere niile';

  @override
  String get referralsSubtitle =>
      'Nweta ruo \$0.5 mgbe onye ị kpọbatara mezuru swap mbụ tozuru etozu nke \$10 ma ọ bụ karịa.';

  @override
  String get yourReferralCode => 'KOODU Ị KPỌBATARA';

  @override
  String get myCode => 'Koodu M';

  @override
  String get myReferral => 'Onye Kpọbatara M';

  @override
  String get noReferral => 'Enweghị onye kpọrọ m';

  @override
  String get rewardsEarned => 'Ere M Nwetara';

  @override
  String get referredUsers => 'Ndị M Kpọbatara';

  @override
  String referredUsersCount(Object count) {
    return 'Mmadụ $count';
  }

  @override
  String get addReferral => 'Tinye Onye Kpọbatara Gị';

  @override
  String get enterReferralCode => 'Tinye koodu ị kpọbatara';

  @override
  String get unableToLoadReferrals => 'Enweghị ike ibupụta ndị a kpọbatara';

  @override
  String get enterReferralCodePrompt => 'Tinye koodu ndapụta';

  @override
  String get ownReferralCodeError => 'I nweghị ike iji koodu gị n\'onwe gị';

  @override
  String get referralAdded => 'Etinyela onye kpọrọ gị';

  @override
  String get unableToAddReferral => 'Enweghị ike itinye onye kpọbatara gị';

  @override
  String get referralCodeCopied => 'E depụtaghachiri koodu obibata gị!';

  @override
  String get refresh => 'Sọgharịa';

  @override
  String get backupSeedPhraseTitle => 'Detuo Okwu Nzuzo';

  @override
  String get authenticateToViewSeedPhrase =>
      'Gosi onye ị bụ ka i nwee ike hụ okwu nzuzo gị';

  @override
  String get authenticationRequiredSeedPhrase =>
      'I kwesịrị igosi onye ị bụ iji hụ okwu nzuzo';

  @override
  String get securityWarning => 'Ịdọ Aka ná Ntị Nchekwa';

  @override
  String get seedPhraseMasterKeyWarning =>
      'Okwu nzuzo gị bụ igodo obere akpa gị. Onye ọ bụla nwere ya nwere ike izuru ego gị niile.';

  @override
  String get seedPhraseSafetyBullets =>
      '• Enyela ya onye ọ bụla ọzọ tẹlẹ\n• Atinyela ya na websait ọ bụla\n• Detuo ya n\'akwụkwọ ma dowe ya ebe adịghị n\'ígwé';

  @override
  String get iUnderstand => 'Aghọtara m';

  @override
  String get noSeedPhraseStored =>
      'Enweghị okwu nzuzo e dekwara maka obere akpa a';

  @override
  String get seedPhraseCopied => 'E depụtaghachiri okwu nzuzo gị!';

  @override
  String get backupSeedPhraseIntro =>
      'Okwu nzuzo 12 gị bụ naanị ụzọ i nwere ike iji nwetaghachi obere akpa gị ma foonu gị funa ma ọ bụ ma i chefuo paswọdụ gị.';

  @override
  String unableToOpenLink(Object value) {
    return 'Enweghị ike imeghe $value';
  }

  @override
  String get searchReceivingToken => 'Chọọ token ị na-anata';

  @override
  String get selectTokenTitle => 'Họrọ Token';

  @override
  String get checkingStatus => 'Na-elele...';

  @override
  String get connected => 'Ejikọtara ya';

  @override
  String get noConnection => 'Enweghị njikọ';

  @override
  String get noInternetConnection => 'Enweghị Ịntanetị';

  @override
  String tokenAddedFromClipboard(Object symbol) {
    return 'Etinyela $symbol site na clipboard';
  }

  @override
  String networkAddedSuccessfully(Object name) {
    return 'Etinyela $name nke ọma!';
  }

  @override
  String networkChainIdExists(Object chainId) {
    return 'Netwọk nwere Chain ID $chainId adịworị tẹlẹ.';
  }

  @override
  String get networkNameLabel => 'Aha Netwọk *';

  @override
  String get networkNameHint => 'dịka: Cronos, zkSync Era';

  @override
  String get currencySymbolLabel => 'Ihe Atụ Ego *';

  @override
  String get currencySymbolHint => 'dịka: CRO, ETH';

  @override
  String get chainIdLabel => 'NJ Chain *';

  @override
  String get chainIdHint => 'dịka: 25, 324';

  @override
  String get requiredField => 'I kwesịrị itinye ya';

  @override
  String get mustBeNumber => 'Ọ ga-abụ nọmba';

  @override
  String get autoFillFromChainId => 'Jiri Chain ID dejuo ya';

  @override
  String get enterChainIdHelp => 'Tinye Chain ID ka o dejua ozi netwọk ozugbo.';

  @override
  String get rpcUrlLabel => 'URL RPC *';

  @override
  String get rpcUrlHint => 'https://rpc.example.com';

  @override
  String get mustBeSecureHttps => 'Ọ ga-abụ URL echedoro (https)';

  @override
  String get rpcReachable => 'RPC na-arụ ọrụ';

  @override
  String get rpcUnreachable => 'RPC anaghị arụ ọrụ, lelee URL';

  @override
  String get blockExplorerOptionalLabel => 'URL Maka Nchadi (Nwere ike ịhapụ)';

  @override
  String get blockExplorerHint => 'https://explorer.example.com';

  @override
  String get trustedNetworkWarning =>
      'Adreesị obere akpa gị na-arụ ọrụ na netwọk EVM niile. Naanị tinye netwọk ndị i tụkwara obi.';

  @override
  String get addNetworkAction => 'Tinye Netwọk';

  @override
  String autoHidesInSeconds(Object seconds) {
    return 'Ọ ga-apụ n\'ime sekọnd $seconds';
  }

  @override
  String get hide => 'Zoo ya';

  @override
  String get noSeedPhraseAvailablePrivateKey =>
      'Enweghị okwu nzuzo dị ebe a.\nE si n\'igodo nzuzo bubata obere akpa a.';

  @override
  String get communityDiscordSubtitle => 'Soro anyị ebe a';

  @override
  String get communityTelegramSubtitle => 'FOMOWL Channel';

  @override
  String get noNftsToDisplay => 'Enweghị NFT ọ bụla a ga-egosi';

  @override
  String get moreNftsAvailable => 'NFT niile apụtaburị n\'ihu obere akpa';

  @override
  String get seedPhraseSecureScreenNotice =>
      'A naghị ekwe ka a sere foto skrin mgbe okwu nzuzo a na-apụta.';

  @override
  String get iBackedItUp => 'Edetuola m ya';

  @override
  String get seedPhraseVerificationTitle => 'Gosi na i deturu ya';

  @override
  String get seedPhraseVerificationSubtitle =>
      'Họrọ mkpụrụokwu ndị a chọrọ iji gosi na i doro ha ebe ọzọ.';

  @override
  String selectSeedPhraseWord(Object index) {
    return 'Họrọ okwu #$index';
  }

  @override
  String get verifyBackup => 'Gosi na i deturu ya';

  @override
  String get seedPhraseVerificationFailed =>
      'Nyocha ndabere ahụ adabaghị. Nwaa ọzọ.';

  @override
  String get seedPhraseBackupVerified =>
      'Ekwenyere nkwado ndabere nke mkpụrụokwu';

  @override
  String get seedPhraseBackupVerificationComplete =>
      'Ekwenyela nkwado ndabere nkebiokwu mgbake gị.';

  @override
  String get confirmSecretPhraseTitle => 'Kwado akpaokwu nzuzo gị';

  @override
  String get confirmSecretPhraseCheckOne => 'Ọ bụ naanị m maara ya.';

  @override
  String get confirmSecretPhraseCheckTwo =>
      'Ndị ọzọ enweghị ike ịnweta akpaokwu nzuzo a.';

  @override
  String get confirmSecretPhraseCheckThree =>
      'Enwere ike izuru ego m ma ọ bụrụ na onye ọzọ ahụ nkebi ahịrịokwu mgbake m.';

  @override
  String get adminControlCenter => 'Ebe nchịkwa Owllet';

  @override
  String get adminSystemStatus => 'Ọnọdụ Usoro';

  @override
  String get adminBackendLatency => 'Latency azụ';

  @override
  String get adminAppPerformance => 'Ọrụ App';

  @override
  String get adminRegistryTokens => 'Ndebanye aha Token';

  @override
  String get adminTotalUsers => 'Ndị Ọrụ Niile';

  @override
  String get adminTransactions => 'Azụmahịa Niile';

  @override
  String get adminMaintainers => 'Ndị Nlekọta';

  @override
  String get adminGlobalBroadcast => 'Ozi Izugbe';

  @override
  String get adminNotificationTitleHint => 'Isiokwu ozi';

  @override
  String get adminMessageBodyHint => 'Ozi ị chọrọ izipu';

  @override
  String get adminSendToAllUsers => 'Zipụrụ onye ọ bụla';

  @override
  String get adminWalletAddressHint => 'Adreesị obere akpa';

  @override
  String get adminNameOptionalHint => 'Aha (Nwere ike ịhapụ)';

  @override
  String get adminAddMaintainer => 'Tinye onye nlekọta';

  @override
  String get adminMaintainerAdded => 'Etinyela onye nlekọta';

  @override
  String get adminMaintainerAddFailed => 'Enweghị ike itinye onye nlekọta';

  @override
  String get adminTokenRegistry => 'Ndekọ Token';

  @override
  String get adminSearchRegistryHint => 'Chọọ n\'ime registry...';

  @override
  String get adminTokenVerified => 'Akpọpụtara token a';

  @override
  String get adminTokenUnverified => 'Wepụrụ token a n\'ọkwa';

  @override
  String get adminRegistryUpdateFailed => 'Enweghị ike ịgbanwee registry';

  @override
  String get adminBroadcastSent => 'Ezipụlarị ozi ahụ';

  @override
  String adminBroadcastSentToDevices(Object count) {
    return 'Ezipụrụ ozi ahụ n\'ihe dịka ngwa $count';
  }

  @override
  String get adminBroadcastFailed => 'Ozi ahụ agaghị';

  @override
  String get adminSecretRequired => 'A chọrọ koodu nzuzo nlekọta';

  @override
  String get continueAgreementPrefix =>
      'Site n\'ịga n\'ihu, ị kwetara na anyị ';

  @override
  String get continueAgreementSuffix => '.';

  @override
  String get termsOfUseLabel => 'Usoro ojiji';

  @override
  String get andLabel => ' na ';

  @override
  String get privacyPolicyLabel => 'Atumatu nzuzo';

  @override
  String get termsServiceTitle => 'Usoro Ọrụ';

  @override
  String get termsSection1Title => '1. Nnabata nke Usoro';

  @override
  String get termsSection1Body =>
      'Site n\'itinye ma ọ bụ iji Owllet ị nwetara na iwu kwadoro gị ijide akụ dijitalụ yana na ị nabatara usoro ndị a. Ọ bụrụ na ị kwenyeghị, wepụ ngwa ahụ ozugbo.';

  @override
  String get termsSection2Title => '2. Ọrụ nlekọta onwe onye';

  @override
  String get termsSection2Body =>
      'Owllet na-emepụta naanị igodo ma debanye aha azụmahịa na mpaghara. Ị na-achịkwa mnemonic, obere akpa ewepụtara, nkwado, na azụmahịa. Anyị enweghị ike iweghachite koodu passcode echefuru echefu, nkebi mkpụrụ, ma ọ bụ igodo nzuzo.';

  @override
  String get termsSection3Title => '3. Azụmahịa Blockchain & Ụgwọ';

  @override
  String get termsSection3Body =>
      'A na-agbasa nnyefe, nkwado, ma ọ bụ swap ọ bụla ị zitere gaa na netwọkụ EVM ị họọrọ. Atụmatụ gas bụ mgbalị kachasị mma na ụgwọ ikpeazụ na-ekpebi site na netwọkụ. Ị ga-ahụ maka ịchọpụta adreesị ndị nnata na ịkwụ ụgwọ ụgwọ netwọkụ niile.';

  @override
  String get termsSection4Title => '4. Ọrụ ndị ọzọ & Swaps';

  @override
  String get termsSection4Body =>
      'Ngwa na-adabere na ndị na-enye RPC (dịka, Alchemy na RPC ọ bụla ị gbakwunyere), CoinGecko, na ndị na-anya AMM ọha dịka Uniswap, QuickSwap, PancakeSwap, na SushiSwap. Nkwụsị ọrụ, data ahịa na-ezighi ezi, ma ọ bụ ahụhụ nwere ike ibute mfu ma ọ bụ azụmahịa dara ada. Anyị anaghị asụgharị tokens, pools, ma ọ bụ nkwekọrịta mara mma.';

  @override
  String get termsSection5Title => '5. Nnabata & Atụmatụ';

  @override
  String get termsSection5Body =>
      'Ị bụ naanị gị ga-ahụ maka ikpebi ma ojiji ị na-eji Owllet bụ iwu kwadoro na ikike gị yana maka ịkwụ ụgwọ ụtụ isi ọ bụla ma ọ bụ ọrụ mkpesa metụtara ọrụ akụ dijitalụ gị.';

  @override
  String get termsSection6Title => '6. Ojiji amachibidoro';

  @override
  String get termsSection6Body =>
      'Ị nwere ike ghara iji ngwa maka ọrụ na-akwadoghị, mbata mmachi, nkesa malware, ma ọ bụ imebi usoro nke blockchain ọ bụla, onye na-enye RPC, ma ọ bụ iwu dabara adaba. Anyị debere ikike iji gbanyụọ ohere ịnweta atụmatụ netwọkụ ejiri mee ihe n\'ụzọ na-ezighị ezi.';

  @override
  String get termsSection7Title => '7. Nkwupụta nke Akwụkwọ ikike';

  @override
  String get termsSection7Body =>
      'A na-enye ngwa ahụ \"dị ka ọ dị\" ma \"dị ka ọ dị\" na-enweghị akwụkwọ ikike nke ụdị ọ bụla, kwupụtara ma ọ bụ gosipụta. Anyị anaghị ekwe nkwa na data ọnụahịa ziri ezi, na azụmahịa ga-aga nke ọma, ma ọ bụ na sọftụwia ahụ enweghị njehie.';

  @override
  String get termsSection8Title => '8. Mmachi nke ụgwọ';

  @override
  String get termsSection8Body =>
      'Ruo n\'ókè kachasị nke iwu kwadoro, anyị agaghị akwụ ụgwọ maka ego furu efu, nkebi mkpụrụ okwu furu efu, mfu ahịa, nrigbu mara mma, na-apụtaghị ìhè, nnyefe, ma ọ bụ mmebi na-esite na iji ngwa gị.';

  @override
  String get termsSection9Title => '9. Mgbanwe & kọntaktị';

  @override
  String get termsSection9Body =>
      'Anyị nwere ike imelite usoro ndị a ka anyị na-ebupụta atụmatụ ọhụrụ ma ọ bụ netwọkụ. Ojiji na-aga n\'ihu mgbe mgbanwe gasịrị pụtara na ị nabatara usoro ọhụrụ ahụ. Kpọtụrụ anyị na X (@fomowlhq) ma ọ bụrụ na ịchọrọ nkọwa.';

  @override
  String get termsEffectiveDate => 'Ụbọchị dị irè: Febụwarị 2026';

  @override
  String get privacyPolicyTitle => 'Atumatu Nzuzo';

  @override
  String get privacySection1Title => '1. Nkọwa zuru oke';

  @override
  String get privacySection1Body =>
      'Owllet bụ obere akpa njide onwe onye EVM naanị. Ọgbọ niile nke igodo na mbinye aka na-eme na ngwaọrụ gị site na iji ọba akwụkwọ BIP-39/BIP-32 nwalere agha. Anyị anaghị agba ọsọ akwụkwọ akụkọ ma ọ bụ nweta akụ gị.';

  @override
  String get privacySection2Title => '2. Data echekwara na mpaghara';

  @override
  String get privacySection2Body =>
      'Anyị na-echekwa ihe ndị a site na iji Flutter Secure Storage ma ọ bụ SharedPreferences na ngwaọrụ gị:\n• Aha obere akpa, adreesị na ndenye\n• igodo nzuzo ezoro ezo, nkebi mkpụrụ okwu (ọ bụrụ na ị chekwaa ya), yana koodu passcode gị\n• Mgbanwe biometric gbakwunyere asụsụ/UI mmasị\nIhichapụ ngwa ahụ ma ọ bụ ihichapụ nchekwa echekwara na-ewepụ data a kpamkpam. Ọ dịghị emegiderịta onwe ya na ngwaọrụ gị.';

  @override
  String get privacySection3Title => '3. Ọrụ ndị ọzọ';

  @override
  String get privacySection3Body =>
      'Iji gosipụta itule, data ọnụahịa, na ime swaps ngwa na-ejikọ ozugbo na:\n• RPC enye dị ka Alchemy na ọ bụla omenala RPC gị tinye\n• CoinGecko maka data ahịa na chaatị\n• Ndị na-anya AMM ọha (Uniswap, QuickSwap, PancakeSwap, SushiSwap, wdg) mgbe ị nyere swaps ma ọ bụ nkwado\nNdị na-enye a nwere ike ịdenye adreesị IP ma ọ bụ obere akpa ọrụ n\'okpuru onwe ha atumatu.';

  @override
  String get privacySection4Title => '4. Ikike ngwaọrụ';

  @override
  String get privacySection4Body =>
      'A na-eji ohere igwefoto eme ihe naanị maka nyocha QR. A na-ejikwa sistemụ arụmọrụ biometric (Face/Touch ID, akara mkpịsị aka); anyị na-enweta naanị nsonaazụ. Anyị anaghị enweta foto gị, kọntaktị gị, igwe okwu gị, ma ọ bụ ebe gị.';

  @override
  String get privacySection5Title => '5. Ọrụ gị';

  @override
  String get privacySection5Body =>
      '• Back up your 12-word seed phrase offline and never share it\n• Nyochaa adreesị ebe a na nkwado tupu ị banye mbinye aka\n• Debe ngwaọrụ gị ka ọ dị ugbu a, tọọ koodu nchebe siri ike, ma mee ka biometrics nwee ike\n• Ghọta na azụmahịa blockchain agaghị agbanwe agbanwe';

  @override
  String get privacySection6Title => '6. Mmelite & kọntaktị';

  @override
  String get privacySection6Body =>
      'Anyị nwere ike nyochaa ọkwa a ka anyị na-agbakwụnye netwọkụ ma ọ bụ atụmatụ. Ụdị kachasị ọhụrụ na-adị mgbe niile na ngwa ahụ. Kpọtụrụ anyị na X (@fomowlhq) ma ọ bụrụ na ị nwere ajụjụ nzuzo.';

  @override
  String get privacyLastUpdated => 'Emelitere ikpeazụ: Febụwarị 2026';

  @override
  String get faceVerifyReason => 'Jiri NJ ihu nyochaa njirimara gị';

  @override
  String get faceVerificationFailed => 'Nnwale ihu dara. Biko nwaa ọzọ.';

  @override
  String get biometricUnavailable => 'Nyocha biometric adịghị na ngwaọrụ a.';

  @override
  String get verifying => 'Na-enyocha...';

  @override
  String get faceVerificationTitle => 'Nyocha ihu';

  @override
  String get biometricPromptInstruction =>
      'Tinye ihu gị n\'ime etiti iji nyochaa';

  @override
  String get facePromptInstruction => 'Debe ihu gị n\'okirikiri dị n\'elu';

  @override
  String get verifyFace => 'Nyochaa ihu';

  @override
  String get identityVerifyReason => 'Nyochaa njirimara gị ka ịga n\'ihu';

  @override
  String get biometricVerificationFailed =>
      'Nyocha biometric dara. Biko nwaa ọzọ.';

  @override
  String get biometricVerificationFailedWithPasscode =>
      'Nyocha biometric dara. Biko jiri koodu passcode gị kama.';

  @override
  String get biometricVerificationTitle => 'Nyocha biometric';

  @override
  String get tapBelowToVerify => 'Pịa n\'okpuru iji nyochaa';

  @override
  String get startVerification => 'Malite nkwenye';

  @override
  String get fingerprintVerifyReason =>
      'Jiri akara mkpịsị aka nyochaa njirimara gị';

  @override
  String get fingerprintVerificationFailed =>
      'Nyochaa akara mkpịsị aka dara. Biko nwaa ọzọ.';

  @override
  String get fingerprintVerificationTitle => 'Nyochaa akara mkpịsị aka';

  @override
  String get fingerprintPromptInstruction =>
      'Tinye mkpịsị aka gị na ihe mmetụta iji nyochaa';

  @override
  String get verify => 'Nyochaa';

  @override
  String get swapFromLabel => 'Site na';

  @override
  String get priceLabel => 'Ọnụ ahịa';

  @override
  String get platformFeeLabel => 'Ụgwọ Platform';

  @override
  String get networkFeeLabel => 'Ụgwọ netwọkụ';

  @override
  String get coveredByOwllet => 'Owllet kpuchiri ya';

  @override
  String get toReceiveLabel => 'To Receive';

  @override
  String get swapToLabel => 'Iji';

  @override
  String get calculatingLabel => 'Calculating...';

  @override
  String get receiveTokenTitle => 'Receive Token';

  @override
  String get receiveExternalWarning =>
      'Naanị zipu token na netwọk ziri ezi. Izipu akara na netwọk na-ezighi ezi nwere ike bute mfu na-adịgide adịgide.';

  @override
  String get currencyUsd => 'Dọla Amerika (USD)';

  @override
  String get currencyEur => 'Euro (EUR)';

  @override
  String get currencyGbp => 'Paụndụ Bekee (GBP)';

  @override
  String get currencyNgn => 'Naịra (NGN)';

  @override
  String get selectTokenAndNetwork => 'HỌ̀RỌ̀ TOKEN NA NETWỌK';

  @override
  String get networkLabel => 'Netwọk';

  @override
  String get noNotificationsYet => 'Enweghị ọkwa ọ bụla ugbu a';

  @override
  String get availableBalance => 'EGO DỊ';

  @override
  String get history => 'Akụkọ';

  @override
  String get followSocialhq => 'Soro @fomowlhq na X maka ozi ọhụrụ';

  @override
  String get socialhqHandle => 'x.com/fomowlhq';
}
