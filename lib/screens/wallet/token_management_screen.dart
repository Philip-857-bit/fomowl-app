import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/token.dart';
import '../../services/blockchain_service.dart';
import '../../services/token_visibility_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/toast_utils.dart';
import '../../utils/token_visibility_utils.dart';

/// Full-screen token manager that lets users hide tokens or add/remove custom ones.
class TokenManagementScreen extends StatefulWidget {
  const TokenManagementScreen({super.key});

  @override
  State<TokenManagementScreen> createState() => _TokenManagementScreenState();
}

class _TokenManagementScreenState extends State<TokenManagementScreen> {
  final WalletService _walletService = WalletService();
  final TokenVisibilityService _visibilityService = TokenVisibilityService();

  List<Token> _tokens = [];
  Set<String> _hiddenKeys = {};
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final blockchain = context.read<BlockchainService>();
    final chainId = blockchain.activeChain.chainId;
    setState(() => _isLoading = true);

    final hidden = await _visibilityService.loadHiddenTokens(chainId);
    final address = await _walletService.getCurrentWalletAddress();
    List<Token> fetched = blockchain.tokens;
    if (address != null) {
      try {
        fetched = await blockchain.fetchWalletTokens(address);
      } catch (e) {
        debugPrint('Error fetching tokens in manager: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _tokens = fetched;
      _hiddenKeys = hidden;
      _isLoading = false;
    });
  }

  bool _isTokenHidden(Token token) {
    return _hiddenKeys.contains(TokenVisibilityUtils.identifier(token));
  }

  Future<void> _toggleToken(Token token, bool hideToken) async {
    final blockchain = context.read<BlockchainService>();
    await _visibilityService.setTokenHidden(blockchain.activeChain.chainId, token, hideToken);
    if (!mounted) return;
    setState(() {
      final key = TokenVisibilityUtils.identifier(token);
      if (hideToken) {
        _hiddenKeys.add(key);
      } else {
        _hiddenKeys.remove(key);
      }
      _hasChanges = true;
    });
  }

  Future<void> _removeCustomToken(CustomTokenDefinition token) async {
    final blockchain = context.read<BlockchainService>();
    await blockchain.removeCustomToken(blockchain.activeChain.chainId, token.address);
    await _loadData();
    setState(() => _hasChanges = true);
    ToastUtils.showSuccess('Token removed');
  }

  Future<void> _showAddTokenDialog() async {
    final blockchain = context.read<BlockchainService>();
    final nameController = TextEditingController();
    final symbolController = TextEditingController();
    final addressController = TextEditingController();
    final decimalsController = TextEditingController();
    final coinGeckoController = TextEditingController();

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Custom Token', style: GoogleFonts.outfit(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(symbolController, 'Symbol'),
              const SizedBox(height: 12),
              _buildTextField(nameController, 'Name'),
              const SizedBox(height: 12),
              _buildTextField(addressController, 'Contract Address'),
              const SizedBox(height: 12),
              _buildTextField(decimalsController, 'Decimals', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _buildTextField(coinGeckoController, 'CoinGecko ID (optional)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Add', style: GoogleFonts.outfit(color: AppColors.accentRed)),
          ),
        ],
      ),
    );

    if (shouldAdd != true) return;

    final symbol = symbolController.text.trim();
    final name = nameController.text.trim();
    final address = addressController.text.trim();
    final decimals = int.tryParse(decimalsController.text.trim());
    if (symbol.isEmpty || name.isEmpty || address.isEmpty || decimals == null) {
      ToastUtils.showError('All fields except CoinGecko ID are required');
      return;
    }

    final added = await blockchain.addCustomToken(
      chainId: blockchain.activeChain.chainId,
      token: CustomTokenDefinition(
        symbol: symbol.toUpperCase(),
        name: name,
        address: address,
        decimals: decimals,
        coinGeckoId: coinGeckoController.text.trim().isEmpty ? null : coinGeckoController.text.trim(),
      ),
    );

    if (!added) {
      ToastUtils.showError('Token already exists on this network');
      return;
    }

    await _loadData();
    setState(() => _hasChanges = true);
    ToastUtils.showSuccess('Token added');
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.outfit(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: Colors.white54),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentRed),
        ),
      ),
    );
  }

  void _closeScreen() {
    Navigator.pop(context, _hasChanges);
  }

  @override
  Widget build(BuildContext context) {
    final blockchain = context.watch<BlockchainService>();
    final customTokens = blockchain.customTokensForActiveChain;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _closeScreen,
        ),
        title: Text(
          'Manage Tokens',
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentRed))
          : RefreshIndicator(
              color: AppColors.accentRed,
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Visible Tokens',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  if (_tokens.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'No tokens detected for this wallet yet.',
                        style: GoogleFonts.outfit(color: Colors.white54),
                      ),
                    )
                  else
                    ..._tokens.map(
                      (token) => SwitchListTile.adaptive(
                        value: !_isTokenHidden(token),
                        onChanged: (value) => _toggleToken(token, !value),
                        contentPadding: EdgeInsets.zero,
                        activeTrackColor: AppColors.accentRed.withValues(alpha: 0.4),
                        title: Text(token.name, style: GoogleFonts.outfit(color: Colors.white)),
                        subtitle: Text(
                          token.symbol,
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Custom Tokens',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      TextButton.icon(
                        onPressed: _showAddTokenDialog,
                        icon: const Icon(Icons.add, color: AppColors.accentRed),
                        label: Text('Add', style: GoogleFonts.outfit(color: AppColors.accentRed)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (customTokens.isEmpty)
                    Text('No custom tokens yet.', style: GoogleFonts.outfit(color: Colors.white54))
                  else
                    ...customTokens.map(
                      (custom) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(custom.name, style: GoogleFonts.outfit(color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text(
                                    custom.address,
                                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white54),
                              onPressed: () => _removeCustomToken(custom),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
