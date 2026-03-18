import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/blockchain_service.dart';
import '../../../widgets/token_icon.dart';

class AdminRegistrySection extends StatefulWidget {
  final List<dynamic> registryTokens;
  final Function(dynamic, bool) onToggleVerification;

  const AdminRegistrySection({
    super.key,
    required this.registryTokens,
    required this.onToggleVerification,
  });

  @override
  State<AdminRegistrySection> createState() => _AdminRegistrySectionState();
}

class _AdminRegistrySectionState extends State<AdminRegistrySection> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.adminTokenRegistry,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l.adminSearchRegistryHint,
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            filled: true,
            fillColor: AppColors.cardDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.registryTokens.length,
          itemBuilder: (context, index) {
            final t = widget.registryTokens[index];
            final isCertified = t['isCertified'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: TokenIcon(
                  tokenSymbol: t['symbol'] ?? '?',
                  tokenImageUrl: t['imageUrl'],
                  tokenAddress: t['contractAddress'],
                  chainId: Provider.of<BlockchainService>(
                    context,
                    listen: false,
                  ).activeChain.chainId,
                  size: 32,
                  isCertified: isCertified,
                ),
                title: Text(
                  t['name'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  t['symbol'] ?? '',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: Switch(
                  value: isCertified,
                  activeThumbColor: Colors.green,
                  onChanged: (val) => widget.onToggleVerification(t, val),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
