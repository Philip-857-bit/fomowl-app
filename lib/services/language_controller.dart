import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/language_utils.dart';
import 'language_bridge_service.dart';
import 'storage_service.dart';
import 'wallet_service.dart';

class LanguageController extends ChangeNotifier {
  LanguageController({
    StorageService? storage,
    WalletService? walletService,
    LanguageBridgeService? bridgeService,
  }) : _storage = storage ?? StorageService(),
       _walletService = walletService ?? WalletService(),
       _bridgeService = bridgeService ?? LanguageBridgeService();

  final StorageService _storage;
  final WalletService _walletService;
  final LanguageBridgeService _bridgeService;

  Locale _locale = LanguageUtils.defaultLocale;
  bool _initialized = false;

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get initialized => _initialized;

  Future<void> init() async {
    final storedLanguage = await _storage.getLanguage();
    _locale = LanguageUtils.toLocale(storedLanguage);
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLanguageCode(String rawLanguageCode) async {
    final normalized = LanguageUtils.normalizeLanguageCode(rawLanguageCode);
    if (_locale.languageCode != normalized) {
      _locale = LanguageUtils.toLocale(normalized);
      notifyListeners();
    }

    await _storage.setLanguage(normalized);
    unawaited(_syncToBackend(normalized));
  }

  Future<void> _syncToBackend(String languageCode) async {
    final walletAddress = await _walletService.getCurrentWalletAddress();
    if (walletAddress == null || walletAddress.isEmpty) return;
    await _bridgeService.syncLanguagePreference(
      walletAddress: walletAddress,
      languageCode: languageCode,
    );
  }
}
