import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/bitcoin_account_state.dart';
import '../../services/bitcoin/bitcoin_receive_service.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../widgets/token_selector_modal.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import 'package:provider/provider.dart';
import '../../models/token.dart';
import '../../models/token_standard.dart';
import '../../models/chain.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast_utils.dart';
import 'widgets/send/send_header.dart';
import 'widgets/send/token_selector_card.dart';
import 'widgets/receive/receive_warning_banner.dart';
import 'widgets/receive/bitcoin_receive_format_selector.dart';
import 'widgets/receive/qr_code_card.dart';
import 'widgets/receive/address_display_card.dart';
import 'widgets/receive/receive_action_buttons.dart';

class ReceiveTokenScreen extends StatefulWidget {
  final BitcoinReceiveApi? bitcoinReceive;
  final WalletService? walletService;
  const ReceiveTokenScreen({
    super.key,
    this.bitcoinReceive,
    this.walletService,
  });

  @override
  State<ReceiveTokenScreen> createState() => _ReceiveTokenScreenState();
}

class _ReceiveTokenScreenState extends State<ReceiveTokenScreen> {
  Token? _selectedToken;
  ChainFamily? _lastFamily;
  String? _lastWalletIdentity;
  String _walletAddress = '';
  late final WalletService _walletService =
      widget.walletService ?? WalletService();
  late final BitcoinReceiveApi _bitcoinReceive =
      widget.bitcoinReceive ?? BitcoinReceiveService();
  int _addressGeneration = 0;
  String? _receiveError;
  BitcoinPurpose _bitcoinPurpose = BitcoinPurpose.bip84;
  bool _didApplyRouteToken = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final blockchain = Provider.of<BlockchainService>(context);
    final currentFamily = blockchain.activeFamily;

    if (!_didApplyRouteToken) {
      _didApplyRouteToken = true;
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is Token) {
        if (arg.networkKey != null &&
            arg.networkKey != blockchain.activeNetworkKey) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (blockchain.activeNetworkKey != arg.networkKey) {
              blockchain.setActiveNetworkKey(arg.networkKey!);
            }
            _lastFamily = blockchain.activeFamily;
            _lastWalletIdentity = blockchain.activeWalletAddress;
            _initForFamily(
              initialToken: blockchain.activeNetworkKey == arg.networkKey
                  ? arg
                  : null,
            );
          });
          return;
        }
        _lastFamily = currentFamily;
        _lastWalletIdentity = blockchain.activeWalletAddress;
        _initForFamily(initialToken: arg);
        return;
      }
    }

    // Re-initialise when the family changes OR when the selected token is
    // stale — i.e. it belongs to the previous network (happens because tokens
    // for the new family load asynchronously after the family switch).
    final tokenIsStale =
        _selectedToken != null &&
        _selectedToken!.networkKey != blockchain.activeNetworkKey;
    if (_lastFamily != currentFamily ||
        tokenIsStale ||
        _lastWalletIdentity != blockchain.activeWalletAddress) {
      _lastWalletIdentity = blockchain.activeWalletAddress;
      _lastFamily = currentFamily;
      _initForFamily();
    }
  }

  /// Resets the selected token to the native token of the active family and
  /// reloads the correct wallet address for that family.
  Future<void> _initForFamily({Token? initialToken}) async {
    if (!mounted) return;
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final generation = ++_addressGeneration;
    final family = blockchain.activeFamily;
    final activeNetworkKey = blockchain.activeNetworkKey;

    // Pick the native token for the active family from the loaded token list.
    final familyTokens = blockchain.tokens
        .where((t) => t.networkKey == activeNetworkKey)
        .toList();
    Token nativeToken;
    if (familyTokens.isNotEmpty) {
      nativeToken = familyTokens.firstWhere(
        (t) => t.contractAddress == null || t.contractAddress!.isEmpty,
        orElse: () => familyTokens.first,
      );
    } else {
      // Tokens have not loaded yet. Derive the fallback from the active
      // network so every EVM chain shows its correct native asset.
      nativeToken = blockchain.activeNativeToken;
    }

    final targetToken =
        initialToken ??
        ((_selectedToken != null &&
                _selectedToken!.networkKey == activeNetworkKey)
            ? _selectedToken!
            : nativeToken);

    // Clear the old address before an asynchronous wallet/network transition.
    setState(() {
      _walletAddress = '';
      _receiveError = null;
      _selectedToken = targetToken;
    });
    String? address;
    String? identity;
    try {
      if (family == ChainFamily.bitcoin) {
        identity = await _walletService.getCurrentWalletAddress();
        if (identity == null) throw StateError('No active wallet');
        final derived = await _bitcoinReceive.currentAddress(
          identity,
          BitcoinProductNetwork.fromId(
            NetworkKey.bitcoinNetworkIdOf(activeNetworkKey),
          ),
          purpose: _bitcoinPurpose,
        );
        address = derived.address;
        if (await _walletService.getCurrentWalletAddress() != identity) return;
      } else {
        address = await _walletService.getWalletAddressForFamily(family);
      }
    } catch (_) {
      if (mounted && generation == _addressGeneration) {
        setState(
          () => _receiveError = family == ChainFamily.bitcoin
              ? 'Bitcoin receive address is unavailable. Refresh your account and try again.'
              : 'Receive address is unavailable. Try again.',
        );
      }
      return;
    }
    if (mounted &&
        generation == _addressGeneration &&
        blockchain.activeNetworkKey == activeNetworkKey) {
      setState(() {
        _selectedToken = targetToken;
        _walletAddress = address ?? '';
      });
    }
  }

  void _showTokenSelector() async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    if (blockchain.activeFamily == ChainFamily.bitcoin) return;
    final familyTokens = await _loadSelectableTokens(blockchain);
    if (!mounted) {
      return;
    }
    final result = await showDialog<Token>(
      context: context,
      builder: (context) => TokenSelectorDialog(
        tokens: familyTokens,
        chainId: blockchain.activeTokenStorageChainId,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedToken = result;
      });
    }
  }

  Future<List<Token>> _loadSelectableTokens(
    BlockchainService blockchain,
  ) async {
    final suggestedTokens = await _loadSuggestedTokens(blockchain);
    return _mergeSelectableTokens(blockchain, [
      [blockchain.activeNativeToken],
      blockchain.tokens,
      suggestedTokens,
      _customTokensForActiveNetwork(blockchain),
    ]);
  }

  Future<List<Token>> _loadSuggestedTokens(BlockchainService blockchain) async {
    try {
      return await blockchain.searchTokensFromBackend('', limit: 60);
    } catch (_) {
      return const [];
    }
  }

  List<Token> _customTokensForActiveNetwork(BlockchainService blockchain) {
    return blockchain.customTokensForActiveChain.map((token) {
      return Token(
        symbol: token.symbol,
        name: token.name,
        contractAddress: token.address,
        balance: 0,
        valueUsd: 0,
        changePercent24h: 0,
        decimals: token.decimals,
        imageUrl: token.imageUrl,
        coinGeckoId: token.coinGeckoId,
        isCertified: false,
        networkKey: token.networkKey ?? blockchain.activeNetworkKey,
        tokenStandard: token.tokenStandard,
      );
    }).toList();
  }

  List<Token> _mergeSelectableTokens(
    BlockchainService blockchain,
    List<List<Token>> tokenGroups,
  ) {
    final byKey = <String, Token>{};
    for (final token in tokenGroups.expand((tokens) => tokens)) {
      if (!_tokenMatchesActiveNetwork(token, blockchain)) {
        continue;
      }
      final key = _tokenScopedKey(token, blockchain.activeNetworkKey);
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = token.networkKey == null
            ? token.copyWith(networkKey: blockchain.activeNetworkKey)
            : token;
      } else {
        final winner = _shouldReplaceToken(existing, token) ? token : existing;
        final loser = identical(winner, token) ? existing : token;
        final preservedImageUrl =
            (winner.imageUrl == null || winner.imageUrl!.isEmpty) &&
                loser.imageUrl != null &&
                loser.imageUrl!.isNotEmpty
            ? loser.imageUrl
            : null;
        byKey[key] = winner.copyWith(
          networkKey: winner.networkKey ?? blockchain.activeNetworkKey,
          imageUrl: preservedImageUrl ?? winner.imageUrl,
        );
      }
    }

    final nativeKey = _tokenScopedKey(
      blockchain.activeNativeToken,
      blockchain.activeNetworkKey,
    );
    final native = byKey.remove(nativeKey) ?? blockchain.activeNativeToken;
    final rest = byKey.values.toList()
      ..sort((left, right) => left.symbol.compareTo(right.symbol));
    return [native, ...rest];
  }

  bool _tokenMatchesActiveNetwork(Token token, BlockchainService blockchain) {
    final expectedKey = blockchain.activeNetworkKey.trim().toLowerCase();
    final tokenKey = token.networkKey?.trim().toLowerCase();
    if (tokenKey != null && tokenKey.isNotEmpty) {
      return tokenKey == expectedKey;
    }
    if (blockchain.activeFamily == ChainFamily.evm) {
      return true;
    }
    final contract = token.contractAddress?.trim();
    final isNative = contract == null || contract.isEmpty;
    return isNative &&
        token.symbol.trim().toUpperCase() ==
            blockchain.activeNetworkSymbol.trim().toUpperCase();
  }

  String _tokenScopedKey(Token token, String activeNetworkKey) {
    final scope = token.networkKey?.trim().toLowerCase() ?? activeNetworkKey;
    final identity = token.contractAddress?.trim().isNotEmpty == true
        ? token.contractAddress!.trim().toLowerCase()
        : token.symbol.trim().toLowerCase();
    return '$scope:$identity';
  }

  bool _shouldReplaceToken(Token current, Token next) {
    if (current.balance != next.balance) {
      return next.balance > current.balance;
    }
    if (current.totalValueUsd != next.totalValueUsd) {
      return next.totalValueUsd > current.totalValueUsd;
    }
    if (!current.isCertified && next.isCertified) {
      return true;
    }
    if ((current.imageUrl == null || current.imageUrl!.isEmpty) &&
        next.imageUrl != null &&
        next.imageUrl!.isNotEmpty) {
      return true;
    }
    return current.tokenStandard == TokenStandard.erc20 &&
        next.tokenStandard != TokenStandard.erc20;
  }

  @override
  Widget build(BuildContext context) {
    final blockchain = Provider.of<BlockchainService>(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SendHeader(
                title: l.receiveTokenTitle,
                onBack: () => Navigator.pop(context),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TokenSelectorCard(
                  token: _selectedToken,
                  onTap: blockchain.activeFamily == ChainFamily.bitcoin
                      ? () {}
                      : _showTokenSelector,
                  blockchain: blockchain,
                ),
              ),
              const SizedBox(height: 24),

              if (blockchain.activeFamily == ChainFamily.bitcoin)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: BitcoinReceiveFormatSelector(
                      selected: _bitcoinPurpose,
                      onChanged: (value) {
                        if (value == _bitcoinPurpose) return;
                        setState(() => _bitcoinPurpose = value);
                        _initForFamily();
                      },
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ReceiveWarningBanner(
                  message: blockchain.activeFamily == ChainFamily.bitcoin
                      ? l.bitcoinReceiveWarning
                      : l.receiveExternalWarning,
                ),
              ),
              if (_walletAddress.isEmpty &&
                  blockchain.activeFamily != ChainFamily.evm &&
                  blockchain.activeFamily != ChainFamily.bitcoin) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ReceiveWarningBanner(
                    message:
                        'This wallet was imported via private key and does not have a ${blockchain.activeFamily == ChainFamily.solana ? 'Solana' : 'Tron'} address. '
                        'Create a new wallet from a seed phrase to receive on this network.',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.warning,
                    borderColor: AppColors.warning,
                  ),
                ),
              ],
              const SizedBox(height: 32),

              if (_receiveError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ReceiveWarningBanner(message: _receiveError!),
                ),
              if (_walletAddress.isNotEmpty) QrCodeCard(data: _walletAddress),
              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: AddressDisplayCard(
                  value: _walletAddress,
                  isInterTransfer: false,
                  onCopy: () {
                    if (_walletAddress.isEmpty) return;
                    Clipboard.setData(ClipboardData(text: _walletAddress));
                    ToastUtils.showSuccess(l.addressCopied);
                  },
                ),
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ReceiveActionButtons(
                  onShare: () {
                    if (_walletAddress.isEmpty) return;
                    if (blockchain.activeFamily == ChainFamily.bitcoin) {
                      SharePlus.instance.share(
                        ShareParams(text: _walletAddress),
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  onCopy: () {
                    if (_walletAddress.isEmpty) return;
                    Clipboard.setData(ClipboardData(text: _walletAddress));
                    ToastUtils.showSuccess(l.addressCopied);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
