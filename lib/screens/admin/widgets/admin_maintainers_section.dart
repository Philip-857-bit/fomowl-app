import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class AdminMaintainersSection extends StatefulWidget {
  final List<dynamic> maintainers;
  final VoidCallback onAddMaintainer;
  final Function(String) onDeactivateMaintainer;
  final TextEditingController addressController;
  final TextEditingController nameController;
  final bool isLoading;

  const AdminMaintainersSection({
    Key? key,
    required this.maintainers,
    required this.onAddMaintainer,
    required this.onDeactivateMaintainer,
    required this.addressController,
    required this.nameController,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<AdminMaintainersSection> createState() =>
      _AdminMaintainersSectionState();
}

class _AdminMaintainersSectionState extends State<AdminMaintainersSection> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.adminMaintainers,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.addressController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l.adminWalletAddressHint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l.adminNameOptionalHint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onAddMaintainer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
              ),
              child: Text(
                widget.isLoading ? 'Adding...' : l.adminAddMaintainer,
              ),
            ),
          ),
          if (widget.maintainers.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._buildMaintainersList(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildMaintainersList() {
    return widget.maintainers.map((maintainer) {
      final walletAddress = maintainer['walletAddress']?.toString() ?? '--';
      final name = maintainer['name']?.toString();
      final isActive = maintainer['isActive'] == true;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          isActive ? Icons.verified_user : Icons.block,
          color: isActive ? Colors.green : Colors.orange,
        ),
        title: Text(
          name == null || name.isEmpty ? walletAddress : name,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          walletAddress,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: isActive
            ? IconButton(
                onPressed: () => widget.onDeactivateMaintainer(walletAddress),
                icon: const Icon(Icons.person_off, color: Colors.orange),
              )
            : null,
      );
    }).toList();
  }
}
