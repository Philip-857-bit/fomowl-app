import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/chain.dart';
import '../../services/blockchain_service.dart';
import '../../utils/toast_utils.dart';

class AddNetworkScreen extends StatefulWidget {
  const AddNetworkScreen({super.key});

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
  bool? _rpcValid;

  @override
  void dispose() {
    _nameController.dispose();
    _symbolController.dispose();
    _rpcUrlController.dispose();
    _chainIdController.dispose();
    _explorerController.dispose();
    _coinGeckoIdController.dispose();
    super.dispose();
  }

  Future<void> _testRpc() async {
    final url = _rpcUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTesting = true;
      _rpcValid = null;
    });

    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final valid = await blockchain.testRpcUrl(url);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _rpcValid = valid;
    });
  }

  Future<void> _saveNetwork() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final chain = EvmChain(
      name: _nameController.text.trim(),
      symbol: _symbolController.text.trim().toUpperCase(),
      chainId: int.parse(_chainIdController.text.trim()),
      rpcUrl: _rpcUrlController.text.trim(),
      coinGeckoId: _coinGeckoIdController.text.trim(),
      explorerUrl: _explorerController.text.trim().isNotEmpty
          ? _explorerController.text.trim()
          : null,
      isCustom: true,
    );

    final added = await blockchain.addCustomChain(chain);

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (added) {
      ToastUtils.showSuccess('${chain.name} added successfully!');
      Navigator.pop(context, true);
    } else {
      ToastUtils.showError(
        'A network with Chain ID ${chain.chainId} already exists.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      color: const Color(0xFF121315),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Network Name *'),
                        _buildTextField(
                          controller: _nameController,
                          hint: 'e.g. Cronos, zkSync Era',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildSectionLabel('Currency Symbol *'),
                        _buildTextField(
                          controller: _symbolController,
                          hint: 'e.g. CRO, ETH',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildSectionLabel('Chain ID *'),
                        _buildTextField(
                          controller: _chainIdController,
                          hint: 'e.g. 25, 324',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            if (int.tryParse(value.trim()) == null) {
                              return 'Must be a number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildSectionLabel('RPC URL *'),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _rpcUrlController,
                                hint: 'https://rpc.example.com',
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (!value.trim().startsWith('https://')) {
                                    return 'Must be a secure (https) URL';
                                  }
                                  return null;
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
                                      ? const Color(
                                          0xFF1B5E20,
                                        ).withValues(alpha: 0.3)
                                      : AppColors.error.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
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
                              _rpcValid!
                                  ? 'RPC is reachable'
                                  : 'RPC unreachable, check URL',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: _rpcValid!
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        _buildSectionLabel('Block Explorer URL (optional)'),
                        _buildTextField(
                          controller: _explorerController,
                          hint: 'https://explorer.example.com',
                        ),
                        const SizedBox(height: 14),
                        _buildSectionLabel('CoinGecko ID (optional)'),
                        _buildTextField(
                          controller: _coinGeckoIdController,
                          hint: 'e.g. crypto-com-chain',
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
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
                                  'Your wallet address works on all EVM chains. Only add networks you trust because malicious RPCs can show fake data.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF9CA9C1),
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
                              color: _isSaving ? const Color(0xFF4B4B4B) : null,
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
                                      'Add Network',
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
            'Add Custom Network',
            style: GoogleFonts.outfit(
              fontSize: 34,
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
          color: const Color(0xFF7D8DAA),
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
          color: Colors.white.withValues(alpha: 0.3),
        ),
        filled: true,
        fillColor: const Color(0xFF181A1F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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
