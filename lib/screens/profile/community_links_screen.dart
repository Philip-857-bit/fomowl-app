import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/bottom_navigation.dart';

class CommunityLinksScreen extends StatelessWidget {
  const CommunityLinksScreen({super.key});

  static const List<_CommunityLink> _links = [
    _CommunityLink(
      label: 'YouTube',
      subtitle: '@fomowlhq',
      icon: Icons.play_arrow_rounded,
      url: 'https://www.youtube.com/@fomowlhq',
    ),
    _CommunityLink(
      label: 'X (Twitter)',
      subtitle: '@fomowlhq',
      icon: Icons.alternate_email_rounded,
      url: 'https://x.com/fomowlhq',
    ),
    _CommunityLink(
      label: 'Instagram',
      subtitle: '@fomowlhq',
      icon: Icons.camera_alt_outlined,
      url: 'https://www.instagram.com/fomowlhq',
    ),
    _CommunityLink(
      label: 'TikTok',
      subtitle: '@fomowlhq',
      icon: Icons.music_note_rounded,
      url: 'https://www.tiktok.com/@fomowlhq',
    ),
    _CommunityLink(
      label: 'Discord',
      subtitle: 'Join server',
      icon: Icons.forum_outlined,
      url: 'https://discord.gg/bZzqXw6ub2',
    ),
    _CommunityLink(
      label: 'Telegram',
      subtitle: 'FOMOWL channel',
      icon: Icons.send_rounded,
      url: 'https://t.me/FOMOWL',
    ),
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
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    'Join Our Community',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _links.length,
                itemBuilder: (context, index) {
                  final item = _links[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121315),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: ListTile(
                      onTap: () => _open(item.url),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0.03),
                            ],
                          ),
                        ),
                        child: Icon(
                          item.icon,
                          color: const Color(0xFF91A0BB),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item.label,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        item.subtitle,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF7D8DAA),
                          fontSize: 13,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.open_in_new_rounded,
                        color: Color(0xFF7D8DAA),
                        size: 17,
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
  final String subtitle;
  final IconData icon;
  final String url;

  const _CommunityLink({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.url,
  });
}
