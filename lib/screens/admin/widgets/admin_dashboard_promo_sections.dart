import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import 'admin_dashboard_common.dart';

class AdminHomeBannersSection extends StatelessWidget {
  const AdminHomeBannersSection({
    super.key,
    required this.isLoading,
    required this.isSubmitting,
    required this.isUploadingImage,
    required this.isEditing,
    required this.showFallbackSocialBanner,
    required this.titleController,
    required this.descriptionController,
    required this.linkUrlController,
    required this.imageUrlController,
    required this.ctaLabelController,
    required this.sortOrderController,
    required this.isActive,
    required this.onActiveChanged,
    required this.onFallbackSocialBannerChanged,
    required this.onUploadImage,
    required this.onSubmit,
    required this.onReset,
    required this.banners,
    required this.onEdit,
    required this.onToggleActive,
  });

  final bool isLoading;
  final bool isSubmitting;
  final bool isUploadingImage;
  final bool isEditing;
  final bool showFallbackSocialBanner;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController linkUrlController;
  final TextEditingController imageUrlController;
  final TextEditingController ctaLabelController;
  final TextEditingController sortOrderController;
  final bool isActive;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onFallbackSocialBannerChanged;
  final VoidCallback onUploadImage;
  final VoidCallback onSubmit;
  final VoidCallback onReset;
  final List<Map<String, dynamic>> banners;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final void Function(Map<String, dynamic>, bool) onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeading(
          title: 'Home promos',
          subtitle: 'Manage the wallet spotlight. Owllet can rotate up to four active promos on the home screen.',
        ),
        const AdminBanner(
          title: 'Spotlight behavior',
          message: 'Choose whether Owllet should keep the default social spotlight visible whenever no live promos are active.',
        ),
        const SizedBox(height: 14),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Default social spotlight',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Show the follow-on-X card when there are no live promos.',
                          style: GoogleFonts.outfit(
                            color: Colors.white60,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch.adaptive(
                    value: showFallbackSocialBanner,
                    activeThumbColor: AppColors.success,
                    onChanged: isSubmitting
                        ? null
                        : onFallbackSocialBannerChanged,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                isEditing ? 'Edit home promo' : 'Create home promo',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: adminInputDecoration(
                  label: 'Title',
                  hint: 'Spring trading rewards',
                  icon: Icons.title_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: adminInputDecoration(
                  label: 'Description',
                  hint: 'Explain the promo in one clear sentence.',
                  icon: Icons.notes_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: linkUrlController,
                decoration: adminInputDecoration(
                  label: 'Link URL',
                  hint: 'https://cash.owllet.app',
                  icon: Icons.link_rounded,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Promo artwork',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Use a clean banner image or keep the promo text-only.',
                                style: GoogleFonts.outfit(
                                  color: Colors.white60,
                                  fontSize: 12.5,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: isUploadingImage ? null : onUploadImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: isUploadingImage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            isUploadingImage ? 'Uploading...' : 'Upload',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                      animation: imageUrlController,
                      builder: (context, child) {
                        final imageUrl = imageUrlController.text.trim();
                        if (imageUrl.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Text(
                              'No promo artwork selected yet. Upload one or keep the card text-only.',
                              style: GoogleFonts.outfit(
                                color: Colors.white54,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                imageUrl,
                                height: 136,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      height: 136,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Preview unavailable',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Current creative URL',
                              style: GoogleFonts.outfit(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              imageUrl,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imageUrlController,
                decoration: adminInputDecoration(
                  label: 'Image URL',
                  hint: 'Optional public image URL',
                  icon: Icons.image_outlined,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctaLabelController,
                      decoration: adminInputDecoration(
                        label: 'CTA label',
                        hint: 'Open',
                        icon: Icons.ads_click_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: sortOrderController,
                      decoration: adminInputDecoration(
                        label: 'Sort order',
                        hint: '0',
                        icon: Icons.format_list_numbered_rounded,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Active',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    value: isActive,
                    activeThumbColor: AppColors.success,
                    onChanged: onActiveChanged,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : onReset,
                      child: Text(isEditing ? 'Cancel edit' : 'Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentRed,
                        foregroundColor: Colors.white,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEditing ? 'Save promo' : 'Create promo'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Live home promos',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentRed,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (banners.isEmpty)
          const AdminEmptyState(
            title: 'No home promos yet',
            message: 'Create up to four active banners and Owllet will rotate them on the wallet home screen.',
          )
        else
          ...banners.map(
            (banner) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AdminHomeBannerCard(
                banner: banner,
                onEdit: () => onEdit(banner),
                onToggleActive: (value) => onToggleActive(banner, value),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminHomeBannerCard extends StatelessWidget {
  const _AdminHomeBannerCard({
    required this.banner,
    required this.onEdit,
    required this.onToggleActive,
  });

  final Map<String, dynamic> banner;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final title = (banner['title'] ?? 'Untitled promo').toString();
    final description = (banner['description'] ?? '--').toString();
    final linkUrl = (banner['linkUrl'] ?? '--').toString();
    final imageUrl = (banner['imageUrl'] ?? '').toString();
    final ctaLabel = (banner['ctaLabel'] ?? 'Open').toString();
    final isActive = banner['isActive'] != false;
    final sortOrder = banner['sortOrder']?.toString() ?? '0';

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AdminStatusPill(
                label: isActive ? 'Active' : 'Inactive',
                color: isActive ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                imageUrl,
                height: 132,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 132,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Image unavailable',
                    style: GoogleFonts.outfit(color: Colors.white54),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            description,
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          AdminInfoRow(label: 'Link', value: linkUrl),
          AdminInfoRow(label: 'CTA', value: ctaLabel),
          AdminInfoRow(label: 'Sort order', value: sortOrder),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SwitchListTile.adaptive(
                  value: isActive,
                  activeThumbColor: AppColors.success,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Visible',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onChanged: onToggleActive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminAppReleaseSection extends StatelessWidget {
  const AdminAppReleaseSection({
    super.key,
    required this.isLoading,
    required this.isSubmitting,
    required this.versionController,
    required this.minVersionController,
    required this.releaseNotesController,
    required this.onSubmit,
    required this.currentVersion,
    required this.currentMinVersion,
  });

  final bool isLoading;
  final bool isSubmitting;
  final TextEditingController versionController;
  final TextEditingController minVersionController;
  final TextEditingController releaseNotesController;
  final VoidCallback onSubmit;
  final String currentVersion;
  final String currentMinVersion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeading(
          title: 'App release',
          subtitle: 'Manage the version, minimum required version, and release notes shown to users inside the wallet.',
        ),
        const AdminBanner(
          title: 'Release notes format',
          message: 'Enter one bullet point per line. Each line becomes a separate entry in the "What\'s New" sheet.',
        ),
        const SizedBox(height: 14),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current published version',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLoading ? '...' : currentVersion,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AdminStatusPill(
                    label: 'min: $currentMinVersion',
                    color: AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Update release',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: versionController,
                      decoration: adminInputDecoration(
                        label: 'Version',
                        hint: '1.3.10',
                        icon: Icons.tag_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: minVersionController,
                      decoration: adminInputDecoration(
                        label: 'Min version',
                        hint: '1.0.0',
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: releaseNotesController,
                maxLines: 6,
                decoration: adminInputDecoration(
                  label: 'Release notes (one bullet per line)',
                  hint: 'Solana and Tron wallets are now fully supported\nSend, receive and view transaction history cross-chain',
                  icon: Icons.notes_rounded,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Publish release',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
