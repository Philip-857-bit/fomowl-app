import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/storage_service.dart';
import '../../services/language_bridge_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/toast_utils.dart';
import '../../utils/language_utils.dart';

/// Language Selection Screen
/// Allows users to choose their preferred language
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final StorageService _storage = StorageService();
  final WalletService _walletService = WalletService();
  final LanguageBridgeService _languageBridge = LanguageBridgeService();
  String selectedLanguage = 'English';
  String selectedLanguageCode = 'en';

  Map<String, String> _languages = {
    'English': 'en',
    'Español': 'es',
    'Français': 'fr',
    'Chinese': 'zh',
    'Arabic': 'ar',
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguageAndProviderOptions();
  }

  Future<void> _loadCurrentLanguageAndProviderOptions() async {
    try {
      final providerLanguages = await _languageBridge.getSupportedLanguages();
      final supportedCodes = LanguageUtils.supportedLanguageCodes;
      final filtered = <String, String>{};
      providerLanguages.forEach((name, code) {
        final normalized = LanguageUtils.normalizeLanguageCode(code);
        if (supportedCodes.contains(normalized)) {
          filtered[name] = normalized;
        }
      });
      if (filtered.isNotEmpty && mounted) {
        setState(() {
          _languages = filtered;
        });
      }
    } catch (_) {}

    final languageCode = await _storage.getLanguage();
    if (languageCode != null) {
      final normalizedCode = LanguageUtils.normalizeLanguageCode(languageCode);
      setState(() {
        selectedLanguageCode = normalizedCode;
        // Find the language name from code
        selectedLanguage = _languages.entries
            .firstWhere(
              (entry) => entry.value == normalizedCode,
              orElse: () => const MapEntry('English', 'en'),
            )
            .key;
      });
    }
  }

  Future<void> _saveLanguage(String languageName, String languageCode) async {
    final normalizedCode = LanguageUtils.normalizeLanguageCode(languageCode);
    await _storage.setLanguage(normalizedCode);

    setState(() {
      selectedLanguage = languageName;
      selectedLanguageCode = normalizedCode;
    });

    // Sync to backend in background so UI localization is instant.
    unawaited(
      _syncLanguageToBackend(normalizedCode).catchError((e) {
        debugPrint('Language sync failed: $e');
      }),
    );

    // Navigate back after selection
    if (mounted) {
      // Return the language code so the app can update
      Navigator.pop(context, normalizedCode);
    }
  }

  Future<void> _syncLanguageToBackend(String languageCode) async {
    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) return;
    try {
      await _languageBridge.syncLanguagePreference(
        walletAddress: walletAddress,
        languageCode: languageCode,
      );
    } catch (_) {
      ToastUtils.showInfo(
        'Language saved locally. Backend sync will retry later.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),

            // Title with globe icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  const Icon(Icons.language, color: Colors.white, size: 29),
                  const SizedBox(width: 12),
                  Text(
                    'Choose your desired language',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Language list
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _languages.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 2,
                  color: const Color(0xFF605F5F).withValues(alpha: 0.27),
                ),
                itemBuilder: (context, index) {
                  final entry = _languages.entries.elementAt(index);
                  final languageName = entry.key;
                  final languageCode = entry.value;
                  final isSelected = languageName == selectedLanguage;

                  return InkWell(
                    onTap: () async {
                      await _saveLanguage(languageName, languageCode);
                    },
                    child: Container(
                      height: 79,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            languageName,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E5F1F),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 5.2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                        ],
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
}
