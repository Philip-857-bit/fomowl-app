import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/mobile_scaffold.dart';
import '../../services/storage_service.dart';

/// Language Selection Screen
/// Allows users to choose their preferred language
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final StorageService _storage = StorageService();
  String selectedLanguage = 'English';
  String selectedLanguageCode = 'en';

  final Map<String, String> languages = {
    'English': 'en',
    'Español': 'es',
    'Français': 'fr',
    'Chinese': 'zh',
    'Arabic': 'ar',
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    final languageCode = await _storage.getLanguage();
    if (languageCode != null) {
      setState(() {
        selectedLanguageCode = languageCode;
        // Find the language name from code
        selectedLanguage = languages.entries
            .firstWhere(
              (entry) => entry.value == languageCode,
              orElse: () => const MapEntry('English', 'en'),
            )
            .key;
      });
    }
  }

  Future<void> _saveLanguage(String languageName, String languageCode) async {
    await _storage.setLanguage(languageCode);
    
    setState(() {
      selectedLanguage = languageName;
      selectedLanguageCode = languageCode;
    });

    // Navigate back after selection
    if (mounted) {
      // Return the language code so the app can update
      Navigator.pop(context, languageCode);
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
                  const Icon(
                    Icons.language,
                    color: Colors.white,
                    size: 29,
                  ),
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
                itemCount: languages.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 2,
                  color: const Color(0xFF605F5F).withValues(alpha: 0.27),
                ),
                itemBuilder: (context, index) {
                  final entry = languages.entries.elementAt(index);
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
