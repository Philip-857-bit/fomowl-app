import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';
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
  final WalletService _walletService = WalletService();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  String? _errorMessage;
  List<_Notification> _notifications = [];

  // Simple local cache for current session
  static List<_Notification>? _cachedNotifications;
  static DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    if (_cachedNotifications != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < const Duration(minutes: 5)) {
      _notifications = _cachedNotifications!;
      _isLoading = false;
    } else {
      _fetchNotifications();
    }
  }

  Future<void> _fetchNotifications({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final address = await _walletService.getCurrentWalletAddress();
      if (address == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "No wallet connected";
        });
        return;
      }

      final path = '/notifications/$address';
      final response = await _apiClient.get(path);

      if (response.statusCode == 200) {
        final data = response.data;
        final notifList = data['notifications'] as List<dynamic>? ?? [];

        final parsed = notifList.map((j) {
          final dtStr = j['created_at'] as String? ?? '';
          DateTime? dt;
          try {
            dt = DateTime.parse(dtStr);
          } catch (e) {
            debugPrint('Error parsing notification date: $e');
          }
          final formatted = dt != null
              ? DateFormat('MM.dd.yyyy HH:mm').format(dt)
              : dtStr;

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
          _cachedNotifications = parsed;
          _lastFetchTime = DateTime.now();
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
          _errorMessage = "Exception: $e";
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
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
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
                  : RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: AppColors.background,
                      onRefresh: () => _fetchNotifications(isRefresh: true),
                      child: _notifications.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.7,
                                alignment: Alignment.center,
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.04),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.notifications_off_outlined,
                                          size: 48,
                                          color: Colors.white.withValues(alpha: 0.15),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'No notifications yet',
                                        style: GoogleFonts.outfit(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Updates about transactions, security,\nand news will appear here.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          color: Colors.white54,
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Pull down to refresh',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: Colors.white24,
                                        ),
                                      ),
                                    ],
                                  ),
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
                            color: n.isRead
                                ? Colors.transparent
                                : AppColors.cardDark,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    n.title,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: n.isRead
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    n.date,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: n.isRead ? 0.4 : 0.7,
                                      ),
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
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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
