import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/chain.dart';
import '../../services/blockchain_service.dart';
import '../../utils/toast_utils.dart';

/// Add Custom Network Screen
/// Lets users add any EVM-compatible chain by entering RPC details
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

    setState(() { _isTesting = true; _rpcValid = null; });

    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final valid = await blockchain.testRpcUrl(url);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _rpcValid = valid;
      });
    }
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
    
    if (mounted) {
      setState(() => _isSaving = false);
      if (added) {
        ToastUtils.showSuccess('${chain.name} added successfully!');
        Navigator.pop(context, true);
      } else {
        ToastUtils.showError('A network with Chain ID ${chain.chainId} already exists.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Add Custom Network',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Network Name *'),
                      _buildTextField(
                        controller: _nameController,
                        hint: 'e.g. Cronos, zkSync Era',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Currency Symbol *'),
                      _buildTextField(
                        controller: _symbolController,
                        hint: 'e.g. CRO, ETH',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Chain ID *'),
                      _buildTextField(
                        controller: _chainIdController,
                        hint: 'e.g. 25, 324',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (int.tryParse(v.trim()) == null) return 'Must be a number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('RPC URL *'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _rpcUrlController,
                              hint: 'https://rpc.example.com',
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                if (!v.trim().startsWith('http')) return 'Must be a valid URL';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _isTesting ? null : _testRpc,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: _rpcValid == null
                                  ? AppColors.accentRed.withValues(alpha: 0.2)
                                  : _rpcValid! ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
                                  : AppColors.error.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _isTesting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Icon(
                                    _rpcValid == null ? Icons.wifi_find
                                    : _rpcValid! ? Icons.check_circle
                                    : Icons.error,
                                    color: Colors.white, size: 20,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (_rpcValid != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _rpcValid! ? '✅ RPC is reachable' : '❌ RPC unreachable — check URL',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: _rpcValid! ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      _buildLabel('Block Explorer URL (optional)'),
                      _buildTextField(
                        controller: _explorerController,
                        hint: 'https://explorer.example.com',
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('CoinGecko ID (optional)'),
                      _buildTextField(
                        controller: _coinGeckoIdController,
                        hint: 'e.g. crypto-com-chain (for price data)',
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.white.withValues(alpha: 0.4)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your wallet address works on all EVM chains. Only add networks you trust — malicious RPCs can show fake data.',
                                style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Save button
                      GestureDetector(
                        onTap: _isSaving ? null : _saveNetwork,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: _isSaving ? null : AppColors.primaryGradient,
                            color: _isSaving ? Colors.grey : null,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                                  'Add Network',
                                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.7)),
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
        hintStyle: GoogleFonts.outfit(fontSize: 14, color: Colors.white.withValues(alpha: 0.25)),
        filled: true,
        fillColor: AppColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentRed, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
