import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../widgets/chain_logo_image.dart';

/// Wallet selector + actions row displayed at the top of the home screen.
class HomeTopBar extends StatelessWidget {
  final String walletName;
  final VoidCallback onWalletTap;
  final String chainSymbol;
  final int? chainId;
  final String? chainLogoUrl;
  final VoidCallback onNetworkTap;
  final VoidCallback onHelpTap;
  final VoidCallback onNotificationsTap;
  final bool showNotificationDot;

  const HomeTopBar({
    super.key,
    required this.walletName,
    required this.onWalletTap,
    required this.chainSymbol,
    this.chainId,
    this.chainLogoUrl,
    required this.onNetworkTap,
    required this.onHelpTap,
    required this.onNotificationsTap,
    this.showNotificationDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: _WalletSelector(
                    walletName: walletName,
                    onTap: onWalletTap,
                  ),
                ),
                const SizedBox(width: 8),
                _NetworkChip(
                  chainSymbol: chainSymbol,
                  chainId: chainId,
                  chainLogoUrl: chainLogoUrl,
                  onTap: onNetworkTap,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HelpButton(onTap: onHelpTap),
          const SizedBox(width: 14),
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFFCBD5E1),
                    size: 20,
                  ),
                  onPressed: onNotificationsTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ),
              if (showNotificationDot)
                Positioned(
                  right: 1,
                  top: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.dangerBadge,
                      shape: BoxShape.circle,
                      border: Border.all(width: 2, color: AppColors.canvasDark),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletSelector extends StatelessWidget {
  const _WalletSelector({required this.walletName, required this.onTap});

  final String walletName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.topBarSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.canvasDark,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                size: 14,
                color: AppColors.accentRed,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                walletName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkChip extends StatelessWidget {
  const _NetworkChip({
    required this.chainSymbol,
    required this.chainId,
    required this.chainLogoUrl,
    required this.onTap,
  });

  final String chainSymbol;
  final int? chainId;
  final String? chainLogoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Switch blockchain network',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.fromLTRB(8, 6, 7, 6),
          decoration: BoxDecoration(
            color: AppColors.topBarSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.canvasDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accentRed.withValues(alpha: 0.28),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ChainLogoImage(
                  chainId: chainId,
                  logoUrl: chainLogoUrl,
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
                  fallback: _symbolFallback(),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFFCBD5E1),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _symbolFallback() {
    final symbol = chainSymbol.trim();
    return Center(
      child: Text(
        symbol.isEmpty ? '?' : symbol.substring(0, 1).toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.accentRed,
        ),
      ),
    );
  }
}

class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Open feedback',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: Icon(
                Icons.support_agent_rounded,
                color: Color(0xFFCBD5E1),
                size: 22,
              ),
            ),
            Positioned(
              left: -8,
              top: -7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.dangerBadge,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(width: 2, color: AppColors.canvasDark),
                ),
                child: Text(
                  'HELP',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 8,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
