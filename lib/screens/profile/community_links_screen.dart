import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/bottom_navigation.dart';

class CommunityLinksScreen extends StatelessWidget {
  const CommunityLinksScreen({super.key});

  static const List<_CommunityLink> _links = [
    _CommunityLink(label: 'YouTube', url: 'https://www.youtube.com/@fomowlhq'),
    _CommunityLink(label: 'X (Twitter)', url: 'https://x.com/fomowlhq'),
    _CommunityLink(
      label: 'Instagram',
      url: 'https://www.instagram.com/fomowlhq',
    ),
    _CommunityLink(label: 'TikTok', url: 'https://www.tiktok.com/@fomowlhq'),
    _CommunityLink(label: 'Discord', url: 'https://discord.gg/bZzqXw6ub2'),
    _CommunityLink(label: 'Telegram', url: 'https://t.me/FOMOWL'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BottomNavBar(
        currentIndex: 4,
        onTap: (index) => BottomNavBar.handleNavigation(context, index, 4),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Join Our Community',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _links.length,
                itemBuilder: (context, index) {
                  final item = _links[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: ListTile(
                      onTap: () => _open(item.url),
                      title: Text(
                        item.label,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        item.url,
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.open_in_new_rounded,
                        color: Color(0xFF98A7C5),
                        size: 18,
                      ),
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

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      ToastUtils.showError('Unable to open $url');
    }
  }
}

class _CommunityLink {
  final String label;
  final String url;

  const _CommunityLink({required this.label, required this.url});
}
