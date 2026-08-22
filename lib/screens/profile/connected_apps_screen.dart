import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../features/discover/permissions/dapp_permission_record.dart';
import '../../features/discover/permissions/dapp_permission_service.dart';
import '../../services/wallet_service.dart';
import '../../services/walletconnect/wallet_connect_models.dart';
import '../../services/walletconnect/wallet_connect_service.dart';
import '../../utils/toast_utils.dart';

class ConnectedAppsScreen extends StatefulWidget {
  const ConnectedAppsScreen({super.key});

  @override
  State<ConnectedAppsScreen> createState() => _ConnectedAppsScreenState();
}

class _ConnectedAppsScreenState extends State<ConnectedAppsScreen> {
  final DappPermissionService _permissionService = DappPermissionService();
  final WalletService _walletService = WalletService();

  bool _loading = true;
  bool _busy = false;
  String? _walletAddress;
  String? _error;
  List<DappPermissionRecord> _inAppConnections = const <DappPermissionRecord>[];

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final walletAddress = await _walletService.getCurrentWalletAddress();
      if (walletAddress == null || walletAddress.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _walletAddress = null;
          _inAppConnections = const <DappPermissionRecord>[];
          _loading = false;
          _error = 'No active wallet found.';
        });
        return;
      }

      final inAppRecords = await _permissionService.loadPermissionsForWallet(
        walletAddress,
      );

      if (!mounted) return;
      setState(() {
        _walletAddress = walletAddress;
        _inAppConnections = inAppRecords;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load connected apps right now.';
      });
      debugPrint('Connected apps load failed: $error');
    }
  }

  Future<void> _disconnectInApp(DappPermissionRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Disconnect app?',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This removes in-app wallet access for ${_displayOrigin(record.origin)}.',
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Disconnect', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );

    if (confirm != true || _busy) return;

    setState(() => _busy = true);
    try {
      await _permissionService.revokeConnectionApproval(
        record.origin,
        record.walletAddress,
      );
      await _loadConnections();
      ToastUtils.showSuccess('App disconnected.');
    } catch (error) {
      ToastUtils.showError('Unable to disconnect app right now.');
      debugPrint('Failed to disconnect app: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _disconnectWcSession(WcActiveSessionModel session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Disconnect WalletConnect Session?',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This ends the active session with ${session.dappName}.',
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Disconnect', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );

    if (confirm != true || _busy) return;

    setState(() => _busy = true);
    try {
      await WalletConnectService.instance.disconnectSession(session.topic);
      await _loadConnections();
    } catch (error) {
      debugPrint('Failed to disconnect WC session: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _disconnectAll() async {
    final walletAddress = _walletAddress;
    if (walletAddress == null || walletAddress.isEmpty || _busy) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Disconnect all apps?',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This removes all in-app and WalletConnect external sessions.',
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Disconnect all', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await _permissionService.revokeAllForWallet(walletAddress);
      await WalletConnectService.instance.disconnectAll();
      await _loadConnections();
      ToastUtils.showSuccess('All connected apps removed.');
    } catch (error) {
      ToastUtils.showError('Unable to disconnect apps right now.');
      debugPrint('Failed to disconnect all apps: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _displayOrigin(String origin) {
    final parsed = Uri.tryParse(origin);
    if (parsed == null || parsed.host.isEmpty) {
      return origin;
    }
    return parsed.host;
  }

  String _shortAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    // Listen to WalletConnectService updates in real time
    final wcService = context.watch<WalletConnectService>();
    final currentWcSessions = wcService.getActiveSessions();
    final totalCount = _inAppConnections.length + currentWcSessions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Connected Apps',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentRed),
            )
          : RefreshIndicator(
              color: AppColors.accentRed,
              onRefresh: _loadConnections,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_walletAddress != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active wallet',
                            style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _shortAddress(_walletAddress!),
                            style: GoogleFonts.robotoMono(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$totalCount connected session${totalCount == 1 ? '' : 's'}',
                            style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          if (totalCount > 0) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _disconnectAll,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accentRed,
                                side: BorderSide(
                                  color: AppColors.accentRed.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.link_off_rounded),
                              label: Text(
                                'Disconnect all',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: GoogleFonts.outfit(color: AppColors.accentRed),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 1. WalletConnect External Sessions Section
                  if (currentWcSessions.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          size: 16,
                          color: AppColors.accentRed,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'WalletConnect (External Apps)',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final session in currentWcSessions)
                      _buildWcSessionCard(session),
                    const SizedBox(height: 16),
                  ],

                  // 2. In-App Browser Connections Section
                  if (_inAppConnections.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.explore_outlined,
                          size: 16,
                          color: Color(0xFF60A5FA),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'In-App Browser Connections',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final record in _inAppConnections)
                      _buildInAppRecordCard(record),
                  ],

                  // Empty State
                  if (totalCount == 0)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        'No dapp or external session is currently connected to this wallet.',
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildWcSessionCard(WcActiveSessionModel session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (session.dappIcon != null && session.dappIcon!.isNotEmpty)
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    session.dappIcon!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallbackDappIcon(session.dappName),
                  ),
                )
              else
                _fallbackDappIcon(session.dappName),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.dappName,
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (session.dappUrl.isNotEmpty)
                      Text(
                        _displayOrigin(session.dappUrl),
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _busy ? null : () => _disconnectWcSession(session),
                icon: const Icon(
                  Icons.link_off_rounded,
                  size: 16,
                  color: AppColors.accentRed,
                ),
                label: Text(
                  'Disconnect',
                  style: GoogleFonts.outfit(
                    color: AppColors.accentRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Session expires: ${_formatDate(session.expiry)}',
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInAppRecordCard(DappPermissionRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _displayOrigin(record.origin),
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _busy ? null : () => _disconnectInApp(record),
                icon: const Icon(
                  Icons.link_off_rounded,
                  size: 16,
                  color: AppColors.accentRed,
                ),
                label: Text(
                  'Disconnect',
                  style: GoogleFonts.outfit(
                    color: AppColors.accentRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            record.origin,
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connected ${_formatDate(record.connectedAt)}',
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackDappIcon(String name) {
    final first = name.isNotEmpty ? name[0].toUpperCase() : 'W';
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppColors.canvasDark,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      alignment: Alignment.center,
      child: Text(
        first,
        style: GoogleFonts.outfit(
          color: AppColors.accentRed,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}
