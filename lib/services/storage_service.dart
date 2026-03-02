import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallet_account.dart';
import '../utils/language_utils.dart';

/// Storage Service
/// Handles secure storage of sensitive data and preferences
class StorageService {
  // Secure storage for sensitive data (encrypted)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  // Keys for secure storage
  static const String _keyPrivateKey = 'wallet_private_key';
  static const String _keyMnemonic = 'wallet_mnemonic';
  static const String _keyAddress = 'wallet_address';
  static const String _keyWalletName = 'wallet_name';
  static const String _keyPasscode = 'user_passcode';
  static const String _keyWalletList = 'wallet_list';
  static const String _keyNextDerivationIndex = 'next_derivation_index';
  static const String _keyCurrentDerivationIndex = 'current_derivation_index';

  // Keys for shared preferences (non-sensitive)
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyFaceIdEnabled = 'face_id_enabled';
  static const String _keyFingerprintEnabled = 'fingerprint_enabled';
  static const String _keyLanguage = 'app_language';
  static const String _keyCurrency = 'preferred_currency';
  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyFailedAttempts = 'failed_attempts';
  static const String _keyLockoutUntil = 'lockout_until';
  static const String _keyTwoFactorEnabled = 'two_factor_enabled';
  static const String _keyAutoLockMinutes = 'auto_lock_minutes';

  // Brute-force protection constants
  static const int maxFailedAttempts = 5;
  static const int lockoutDurationSeconds = 30;

  /// Save wallet data securely
  Future<void> saveWallet({
    required String address,
    required String privateKey,
    String? mnemonic,
    String? walletName,
    WalletOrigin origin = WalletOrigin.derived,
    int? derivationIndex,
    DateTime? createdAt,
  }) async {
    await _secureStorage.write(key: _keyAddress, value: address);
    await _secureStorage.write(key: _keyPrivateKey, value: privateKey);
    await _secureStorage.write(
      key: _walletPrivateKeyKey(address),
      value: privateKey,
    );

    if (mnemonic != null) {
      await _secureStorage.write(key: _keyMnemonic, value: mnemonic);
    }

    if (walletName != null) {
      await _secureStorage.write(key: _keyWalletName, value: walletName);
    }

    final account = WalletAccount(
      address: address,
      name: walletName ?? 'Wallet',
      origin: origin,
      derivationIndex: derivationIndex,
      createdAt: createdAt ?? DateTime.now(),
    );
    await _upsertWalletAccount(account);

    if (derivationIndex != null) {
      await _setCurrentDerivationIndex(derivationIndex);
      final nextIndex = await getNextDerivationIndex();
      if (derivationIndex >= nextIndex) {
        await setNextDerivationIndex(derivationIndex + 1);
      }
    }
  }

  /// Get wallet address
  Future<String?> getWalletAddress() async {
    return await _secureStorage.read(key: _keyAddress);
  }

  /// Get private key
  Future<String?> getPrivateKey() async {
    final address = await getWalletAddress();
    if (address != null) {
      final existing = await _secureStorage.read(
        key: _walletPrivateKeyKey(address),
      );
      if (existing != null) return existing;
    }
    return await _secureStorage.read(key: _keyPrivateKey);
  }

  Future<String?> getPrivateKeyForAddress(String address) async {
    return await _secureStorage.read(key: _walletPrivateKeyKey(address));
  }

  /// Get mnemonic
  Future<String?> getMnemonic() async {
    return await _secureStorage.read(key: _keyMnemonic);
  }

  /// Get wallet name
  Future<String?> getWalletName() async {
    return await _secureStorage.read(key: _keyWalletName);
  }

  /// Delete wallet data
  Future<void> deleteWallet() async {
    await _secureStorage.delete(key: _keyAddress);
    await _secureStorage.delete(key: _keyPrivateKey);
    await _secureStorage.delete(key: _keyMnemonic);
    await _secureStorage.delete(key: _keyWalletName);
  }

  Future<void> setActiveWallet(String? address) async {
    if (address == null) {
      await clearActiveWallet();
      return;
    }
    final wallet = await _findWallet(address);
    if (wallet == null) throw Exception('Wallet not found');
    final privateKey = await _secureStorage.read(
      key: _walletPrivateKeyKey(address),
    );
    if (privateKey == null) throw Exception('Missing private key for wallet');
    await _secureStorage.write(key: _keyAddress, value: address);
    await _secureStorage.write(key: _keyPrivateKey, value: privateKey);
    await _secureStorage.write(key: _keyWalletName, value: wallet.name);
    if (wallet.derivationIndex != null) {
      await _setCurrentDerivationIndex(wallet.derivationIndex!);
    }
  }

  Future<void> clearActiveWallet() async {
    await _secureStorage.delete(key: _keyAddress);
    await _secureStorage.delete(key: _keyPrivateKey);
    await _secureStorage.delete(key: _keyWalletName);
  }

  Future<void> renameWallet(String address, String newName) async {
    final accounts = await getWalletAccounts();
    final index = accounts.indexWhere(
      (a) => a.address.toLowerCase() == address.toLowerCase(),
    );
    if (index < 0) return;
    final account = accounts[index];
    accounts[index] = WalletAccount(
      address: account.address,
      name: newName,
      origin: account.origin,
      derivationIndex: account.derivationIndex,
      createdAt: account.createdAt,
    );
    await _saveWalletAccounts(accounts);
    final activeAddress = await getWalletAddress();
    if (activeAddress != null &&
        activeAddress.toLowerCase() == address.toLowerCase()) {
      await _secureStorage.write(key: _keyWalletName, value: newName);
    }
  }

  Future<void> removeWalletAccount(String address) async {
    final accounts = await getWalletAccounts();
    final normalized = address.toLowerCase();
    final index = accounts.indexWhere(
      (a) => a.address.toLowerCase() == normalized,
    );
    if (index < 0) {
      throw Exception('Wallet not found');
    }
    if (accounts.length <= 1) {
      throw Exception('You must keep at least one wallet');
    }

    final wasActive = (await getWalletAddress())?.toLowerCase() == normalized;
    
    if (wasActive) {
      final replacement = accounts.firstWhere(
        (a) => a.address.toLowerCase() != normalized,
      );
      final replacementPk = await _secureStorage.read(
        key: _walletPrivateKeyKey(replacement.address),
      );
      if (replacementPk == null) {
        throw Exception('Replacement wallet private key is missing');
      }
      
      // Update active pointers FIRST
      await _secureStorage.write(key: _keyAddress, value: replacement.address);
      await _secureStorage.write(key: _keyPrivateKey, value: replacementPk);
      await _secureStorage.write(key: _keyWalletName, value: replacement.name);
      if (replacement.derivationIndex != null) {
        await _setCurrentDerivationIndex(replacement.derivationIndex!);
      }
    }

    // Now safe to remove from list and delete specific key
    accounts.removeAt(index);
    await _saveWalletAccounts(accounts);
    await _secureStorage.delete(key: _walletPrivateKeyKey(address));
  }

  Future<List<WalletAccount>> getWalletAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyWalletList);
    if (jsonStr == null) {
      final address = await getWalletAddress();
      if (address == null) return [];
      final name = await getWalletName() ?? 'Wallet';
      final index = await getCurrentDerivationIndex();
      return [
        WalletAccount(
          address: address,
          name: name,
          origin: WalletOrigin.derived,
          derivationIndex: index,
          createdAt: DateTime.now(),
        ),
      ];
    }
    final List<dynamic> data = jsonDecode(jsonStr) as List<dynamic>;
    return data
        .map((e) => WalletAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getNextDerivationIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyNextDerivationIndex) ?? 1;
  }

  Future<void> setNextDerivationIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNextDerivationIndex, index);
  }

  Future<int?> getCurrentDerivationIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCurrentDerivationIndex);
  }

  Future<void> _setCurrentDerivationIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCurrentDerivationIndex, index);
  }

  Future<void> _saveWalletAccounts(List<WalletAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_keyWalletList, jsonStr);
  }

  Future<void> _upsertWalletAccount(WalletAccount account) async {
    final accounts = await getWalletAccounts();
    final index = accounts.indexWhere(
      (a) => a.address.toLowerCase() == account.address.toLowerCase(),
    );
    if (index >= 0) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }
    await _saveWalletAccounts(accounts);
  }

  Future<WalletAccount?> _findWallet(String address) async {
    final accounts = await getWalletAccounts();
    try {
      return accounts.firstWhere(
        (a) => a.address.toLowerCase() == address.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  String _walletPrivateKeyKey(String address) =>
      'wallet_private_key_${address.toLowerCase()}';

  /// Save passcode
  Future<void> savePasscode(String passcode) async {
    await _secureStorage.write(key: _keyPasscode, value: passcode);
  }

  /// Get passcode
  Future<String?> getPasscode() async {
    return await _secureStorage.read(key: _keyPasscode);
  }

  /// Verify passcode
  Future<bool> verifyPasscode(String passcode) async {
    final stored = await getPasscode();
    return stored == passcode;
  }

  /// Delete passcode
  Future<void> deletePasscode() async {
    await _secureStorage.delete(key: _keyPasscode);
  }

  // --- Brute-force protection ---

  /// Get the number of failed passcode attempts
  Future<int> getFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFailedAttempts) ?? 0;
  }

  /// Increment failed attempt counter
  Future<void> incrementFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyFailedAttempts) ?? 0;
    await prefs.setInt(_keyFailedAttempts, current + 1);
  }

  /// Reset failed attempt counter (on successful login)
  Future<void> resetFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFailedAttempts, 0);
    await prefs.remove(_keyLockoutUntil);
  }

  /// Set a lockout time (current time + duration)
  Future<void> setLockout() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutTime = DateTime.now()
        .add(const Duration(seconds: lockoutDurationSeconds))
        .millisecondsSinceEpoch;
    await prefs.setInt(_keyLockoutUntil, lockoutTime);
  }

  /// Get the lockout end time (or null if not locked out)
  Future<DateTime?> getLockoutUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutMs = prefs.getInt(_keyLockoutUntil);
    if (lockoutMs == null) return null;
    final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutMs);
    if (DateTime.now().isAfter(lockoutTime)) {
      // Lockout expired — clear it
      await prefs.remove(_keyLockoutUntil);
      await prefs.setInt(_keyFailedAttempts, 0);
      return null;
    }
    return lockoutTime;
  }

  /// Check if the user is currently locked out
  Future<bool> isLockedOut() async {
    final lockoutTime = await getLockoutUntil();
    return lockoutTime != null;
  }

  // --- Biometric settings ---

  /// Save biometric settings
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
    // If disabling generally, also disable specific types
    if (!enabled) {
      await prefs.setBool(_keyFaceIdEnabled, false);
      await prefs.setBool(_keyFingerprintEnabled, false);
    }
  }

  /// Get biometric enabled status
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_keyBiometricEnabled) ?? false) ||
        (prefs.getBool(_keyFingerprintEnabled) ?? false) ||
        (prefs.getBool(_keyFaceIdEnabled) ?? false);
  }

  /// Save Face ID setting
  Future<void> setFaceIdEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFaceIdEnabled, enabled);
  }

  /// Get Face ID enabled status
  Future<bool> isFaceIdEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFaceIdEnabled) ?? false;
  }

  /// Save Fingerprint setting
  Future<void> setFingerprintEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFingerprintEnabled, enabled);
    if (enabled) {
      await prefs.setBool(_keyBiometricEnabled, true);
    }
  }

  /// Get Fingerprint enabled status
  Future<bool> isFingerprintEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFingerprintEnabled) ?? false;
  }

  /// Save 2FA preference
  Future<void> setTwoFactorEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTwoFactorEnabled, enabled);
  }

  /// Get 2FA preference
  Future<bool> isTwoFactorEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTwoFactorEnabled) ?? false;
  }

  /// Save auto-lock timer in minutes
  Future<void> setAutoLockMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoLockMinutes, minutes);
  }

  /// Get auto-lock timer in minutes
  Future<int> getAutoLockMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAutoLockMinutes) ?? 1;
  }

  /// Save language preference
  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = LanguageUtils.normalizeLanguageCode(languageCode);
    await prefs.setString(_keyLanguage, normalized);
  }

  /// Get language preference
  Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyLanguage);
    if (stored == null || stored.isEmpty) return null;
    return LanguageUtils.normalizeLanguageCode(stored);
  }

  /// Save preferred display currency (e.g., USD)
  Future<void> setCurrency(String currencyCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, currencyCode);
  }

  /// Get preferred display currency
  Future<String> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrency) ?? 'USD';
  }

  /// Check if first launch
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstLaunch) ?? true;
  }

  /// Set first launch completed
  Future<void> setFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstLaunch, false);
  }

  /// Clear all data (for testing/reset)
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
