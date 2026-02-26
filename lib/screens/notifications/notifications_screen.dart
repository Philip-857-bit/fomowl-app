import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/wallet_service.dart';

/// Notifications Screen
/// Lists withdrawal/transfer receipts, KYC status, etc.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<_Notification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final walletService = context.read<WalletService>();
      final address = await walletService.getCurrentWalletAddress();
      if (address == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "No wallet connected";
        });
        return;
      }

      final url = Uri.parse('https://fomowl-backend.onrender.com/api/notifications/$address');
      final response = await http.get(url).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final notifList = data['notifications'] as List<dynamic>? ?? [];
        
        final parsed = notifList.map((j) {
          final dtStr = j['created_at'] as String? ?? '';
          DateTime? dt;
          try {
            dt = DateTime.parse(dtStr);
          } catch (_) {}
          final formatted = dt != null ? DateFormat('MM.dd.yyyy HH:mm').format(dt) : dtStr;

          return _Notification(
            id: j['id'] ?? '',
            title: j['title'] ?? 'Notification',
            message: j['message'] ?? '',
            isRead: j['is_read'] == 1 || j['is_read'] == true,
            date: formatted,
          );
        }).toList();

        setState(() {
          _notifications = parsed;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load (${response.statusCode})";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error connecting to server";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      l.notifications,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // List State
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _errorMessage != null
                      ? Center(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: AppColors.accentRed,
                            ),
                          ),
                        )
                      : _notifications.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 100, height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.04),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.notifications_off_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'No notifications yet',
                                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Updates about transactions, security,\nand news will appear here.',
                                      style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54, height: 1.5),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              separatorBuilder: (_, a) => const SizedBox(height: 10),
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                final n = _notifications[index];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: n.isRead ? Colors.transparent : AppColors.cardDark,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            n.title,
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            n.date,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: n.isRead ? 0.4 : 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        n.message,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          color: Colors.white.withValues(alpha: 0.6),
                                          height: 1.4,
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notification {
  final String id;
  final String title;
  final String message;
  final bool isRead;
  final String date;

  _Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.date,
  });
}
