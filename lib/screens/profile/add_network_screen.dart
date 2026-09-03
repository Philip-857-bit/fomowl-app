import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'dart:async';
import 'dart:convert';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chain.dart';
import '../../services/blockchain_service.dart';
import '../../utils/rpc_url_validator.dart';
import '../../utils/toast_utils.dart';

class AddNetworkScreen extends StatefulWidget {
  /// When non-null the screen edits this existing custom network instead of
  /// adding a new one.
  final EvmChain? existing;

  const AddNetworkScreen({super.key, this.existing});

  @override
  State<AddNetworkScreen> createState() => _AddNetworkScreenState();
}

class _AddNetworkScreenState extends State<AddNetworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();
  final _rpcUrlController = TextEditingController();
  final _chainIdController = TextEditingController();
  final _explorerController = TextEditingController();
  final _coinGeckoIdController = TextEditingController();

  bool _isTesting = false;
  bool _isSaving = false;
  bool _isAutofilling = false;
  bool? _rpcValid;
  Timer? _chainIdDebounce;
  static List<dynamic>? _chainRegistryCache;
  static Map<String, String>? _chainLogoCache;
  int? _lastAutofilledChainId;
  String? _resolvedLogoUrl;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _symbolController.dispose();
    _rpcUrlController.dispose();
    _chainIdController.dispose();
    _explorerController.dispose();
    _coinGeckoIdController.dispose();
    _chainIdDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _symbolController.text = existing.symbol;
      _chainIdController.text = existing.chainId.toString();
      _rpcUrlController.text = existing.rpcUrl;
      _explorerController.text = existing.explorerUrl ?? '';
      _coinGeckoIdController.text = existing.coinGeckoId ?? '';
      _lastAutofilledChainId = existing.chainId;
      _resolvedLogoUrl = existing.logoUrl;
    }
    _chainIdController.addListener(_onChainIdChanged);
  }

  void _onChainIdChanged() {
    _chainIdDebounce?.cancel();
    _chainIdDebounce = Timer(const Duration(milliseconds: 500), () {
      final chainId = int.tryParse(_chainIdController.text.trim());
      if (chainId == null || chainId == _lastAutofilledChainId) return;
      unawaited(_autofillFromChainId(chainId));
    });
  }

  Future<void> _testRpc() async {
    final url = _rpcUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTesting = true;
      _rpcValid = null;
    });

    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    // Fetch the chain id the RPC actually serves so we can confirm it matches
    // the chain id the user entered. An RPC that reports a different chain id
    // would cause transactions to be signed/broadcast on the wrong chain.
    final reportedChainId = await blockchain.getRpcChainId(url);
    final enteredChainId = int.tryParse(_chainIdController.text.trim());

    if (!mounted) return;
    final matches =
        reportedChainId != null &&
        (enteredChainId == null || reportedChainId == enteredChainId);
    setState(() {
      _isTesting = false;
      _rpcValid = matches;
    });

    if (reportedChainId != null &&
        enteredChainId != null &&
        reportedChainId != enteredChainId) {
      ToastUtils.showError(
        'This RPC serves chain $reportedChainId, not $enteredChainId. '
        'Fix the Chain ID or the RPC URL.',
      );
    } else if (reportedChainId == null) {
      ToastUtils.showError('Could not reach this RPC. Check the URL.');
    }
  }

  Future<void> _saveNetwork() async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final enteredChainId = int.parse(_chainIdController.text.trim());
    final rpcUrl = _rpcUrlController.text.trim();

    // Verify the RPC serves the entered chain id before saving. Block on a
    // CONFIRMED mismatch (reachable RPC reporting a different chain) — that is
    // the dangerous case. If the RPC is simply unreachable (null), allow the
    // save so a temporarily-down endpoint doesn't block setup.
    final reportedChainId = await blockchain.getRpcChainId(rpcUrl);
    if (!mounted) return;
    if (reportedChainId != null && reportedChainId != enteredChainId) {
      setState(() => _isSaving = false);
      ToastUtils.showError(
        'This RPC serves chain $reportedChainId, not $enteredChainId. '
        'Fix the Chain ID or the RPC URL before adding the network.',
      );
      return;
    }

    final coinGeckoId = _coinGeckoIdController.text.trim().toLowerCase();
    final chain = EvmChain(
      name: _nameController.text.trim(),
      symbol: _symbolController.text.trim().toUpperCase(),
      chainId: enteredChainId,
      rpcUrl: rpcUrl,
      coinGeckoId: coinGeckoId.isNotEmpty ? coinGeckoId : null,
      explorerUrl: _explorerController.text.trim().isNotEmpty
          ? _explorerController.text.trim()
          : null,
      logoUrl: _resolvedLogoUrl,
      isCustom: true,
    );

    final bool saved;
    if (_isEditing) {
      saved = await blockchain.updateCustomChain(
        widget.existing!.chainId,
        chain,
      );
    } else {
      saved = await blockchain.addCustomChain(chain);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (saved) {
      ToastUtils.showSuccess(l.networkAddedSuccessfully(chain.name));
      Navigator.pop(context, true);
    } else {
      ToastUtils.showError(l.networkChainIdExists(chain.chainId));
    }
  }

  Future<void> _autofillFromChainId(int chainId) async {
    if (_isAutofilling) return;
    setState(() => _isAutofilling = true);
    try {
      final registry = await _loadChainRegistry();
      final match = registry.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item != null && item['chainId'] == chainId,
        orElse: () => null,
      );
      if (match == null) return;

      final name = (match['name'] as String?)?.trim();
      final nativeCurrency =
          match['nativeCurrency'] as Map<String, dynamic>? ?? const {};
      final symbol = (nativeCurrency['symbol'] as String?)?.trim();
      final rpcList = (match['rpc'] as List?)?.cast<dynamic>() ?? const [];
      final explorers =
          (match['explorers'] as List?)?.cast<Map<String, dynamic>>() ??
          const [];

      final rpcCandidate = rpcList
          .map((e) => e.toString().trim())
          .where((e) => e.startsWith('https://') && !e.contains(r'${'))
          .cast<String?>()
          .firstWhere((e) => e != null && e.isNotEmpty, orElse: () => null);
      final explorerCandidate = explorers
          .map((e) => (e['url'] as String?)?.trim())
          .firstWhere((e) => e != null && e.isNotEmpty, orElse: () => null);

      if (_nameController.text.trim().isEmpty &&
          name != null &&
          name.isNotEmpty) {
        _nameController.text = name;
      }
      if (_symbolController.text.trim().isEmpty &&
          symbol != null &&
          symbol.isNotEmpty) {
        _symbolController.text = symbol.toUpperCase();
      }
      if (_rpcUrlController.text.trim().isEmpty && rpcCandidate != null) {
        _rpcUrlController.text = rpcCandidate;
      }
      if (_explorerController.text.trim().isEmpty &&
          explorerCandidate != null) {
        _explorerController.text = explorerCandidate;
      }
      final iconName = (match['icon'] as String?)?.trim();
      if (iconName != null && iconName.isNotEmpty) {
        _resolvedLogoUrl = await _resolveChainLogo(iconName);
      }
      _lastAutofilledChainId = chainId;
    } catch (_) {
      // Best effort only.
    } finally {
      if (mounted) {
        setState(() => _isAutofilling = false);
      }
    }
  }

  Future<List<dynamic>> _loadChainRegistry() async {
    if (_chainRegistryCache != null) return _chainRegistryCache!;
    final uri = Uri.parse('https://chainid.network/chains.json');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch chain registry');
    }
    final body = jsonDecode(response.body);
    if (body is! List<dynamic>) {
      throw Exception('Invalid chain registry response');
    }
    _chainRegistryCache = body;
    return body;
  }

  /// Resolves Chainlist's icon metadata only when it supplies an IPFS CID.
  /// Do not load arbitrary image URLs from chain metadata or an RPC endpoint.
  Future<String?> _resolveChainLogo(String iconName) async {
    try {
      final icons = await _loadChainLogoCache();
      return icons[iconName];
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _loadChainLogoCache() async {
    if (_chainLogoCache != null) return _chainLogoCache!;
    final response = await http
        .get(Uri.parse('https://chainid.network/chain_icons.json'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch chain icon registry');
    }
    final data = jsonDecode(response.body);
    if (data is! List) throw Exception('Invalid chain icon registry');

    final icons = <String, String>{};
    final cidPattern = RegExp(r'^[A-Za-z0-9]{32,128}$');
    for (final item in data.whereType<Map>()) {
      final name = item['name']?.toString().trim();
      final variants = item['icons'];
      if (name == null || name.isEmpty || variants is! List) continue;
      for (final variant in variants.whereType<Map>()) {
        final source = variant['url']?.toString().trim() ?? '';
        if (!source.startsWith('ipfs://')) continue;
        final cid = source.substring('ipfs://'.length).split('/').first;
        if (!cidPattern.hasMatch(cid)) continue;
        icons.putIfAbsent(name, () => 'https://cloudflare-ipfs.com/ipfs/$cid');
      }
    }
    _chainLogoCache = icons;
    return icons;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.divider.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(l.networkNameLabel),
                        _buildTextField(
                          controller: _nameController,
                          hint: l.networkNameHint,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l.requiredField;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildSectionLabel(l.currencySymbolLabel),
                        _buildTextField(
                          controller: _symbolController,
                          hint: l.currencySymbolHint,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l.requiredField;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildSectionLabel(l.chainIdLabel),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _chainIdController,
                                hint: l.chainIdHint,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return l.requiredField;
                                  }
                                  if (int.tryParse(value.trim()) == null) {
                                    return l.mustBeNumber;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.accentRed.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.divider.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: IconButton(
                                onPressed: _isAutofilling
                                    ? null
                                    : () {
                                        final chainId = int.tryParse(
                                          _chainIdController.text.trim(),
                                        );
                                        if (chainId == null) return;
                                        unawaited(
                                          _autofillFromChainId(chainId),
                                        );
                                      },
                                tooltip: l.autoFillFromChainId,
                                icon: _isAutofilling
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.enterChainIdHelp,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildSectionLabel(l.rpcUrlLabel),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _rpcUrlController,
                                hint: l.rpcUrlHint,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return l.requiredField;
                                  }
                                  // Reject http/malformed/private-or-local
                                  // hosts up front (backend also enforces this).
                                  if (!value.trim().startsWith('https://')) {
                                    return l.mustBeSecureHttps;
                                  }
                                  return validateCustomRpcUrl(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _isTesting ? null : _testRpc,
                              child: Container(
                                margin: const EdgeInsets.only(top: 2),
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _rpcValid == null
                                      ? AppColors.accentRed.withValues(
                                          alpha: 0.18,
                                        )
                                      : _rpcValid!
                                      ? AppColors.success.withValues(
                                          alpha: 0.22,
                                        )
                                      : AppColors.error.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.divider.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: _isTesting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          _rpcValid == null
                                              ? Icons.wifi_find
                                              : _rpcValid!
                                              ? Icons.check_circle
                                              : Icons.error,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_rpcValid != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _rpcValid! ? l.rpcReachable : l.rpcUnreachable,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: _rpcValid!
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        _buildSectionLabel(l.blockExplorerOptionalLabel),
                        _buildTextField(
                          controller: _explorerController,
                          hint: l.blockExplorerHint,
                        ),
                        const SizedBox(height: 14),
                        _buildSectionLabel('CoinGecko ID (optional)'),
                        _buildTextField(
                          controller: _coinGeckoIdController,
                          hint: 'e.g. ethereum, binancecoin',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Sets the native token's USD price. Find it on the "
                          "token's CoinGecko page (the 'API id'). Leave blank "
                          'if unavailable — the token will show without a price.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.inputBackground.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.divider.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.trustedNetworkWarning,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        GestureDetector(
                          onTap: _isSaving ? null : _saveNetwork,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: _isSaving
                                  ? null
                                  : AppColors.primaryGradient,
                              color: _isSaving
                                  ? AppColors.textSecondary.withValues(
                                      alpha: 0.35,
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      l.addNetworkAction,
                                      style: GoogleFonts.outfit(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Text(
            l.addCustomNetwork,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.outfit(fontSize: 15, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(
          fontSize: 14,
          color: AppColors.textSecondary.withValues(alpha: 0.45),
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.accentRed, width: 1.2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.error, width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}
