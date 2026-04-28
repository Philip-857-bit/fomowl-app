import 'dart:convert';
import 'dart:math';

import 'package:argon2/argon2.dart' as dart_argon2;
import 'package:shared_preferences/shared_preferences.dart';
import '../src/rust/api/argon2.dart' as rust_argon2;
import 'package:flutter/foundation.dart';

import '../models/chain.dart';
import '../models/wallet_account.dart';
import '../utils/language_utils.dart';
import 'secure_store.dart';

/// Handles secure storage of sensitive data and preferences.
class StorageService {
  StorageService({
    SecureStore? secureStore,
    SharedPreferences? sharedPreferences,
  }) : _secureStore = secureStore ?? const FlutterSecureStoreAdapter(),
       _sharedPreferences = sharedPreferences;

  final SecureStore _secureStore;
  final SharedPreferences? _sharedPreferences;

  static const String _keyPrivateKey = 'wallet_private_key';
  static const String _keyMnemonic = 'wallet_mnemonic';
  static const String _keyAddress = 'wallet_address';
  static const String _keyWalletName = 'wallet_name';
  static const String _keyPasscode = 'user_passcode';
  static const String _keyWalletList = 'wallet_list';
  static const String _keyNextDerivationIndex = 'next_derivation_index';
  static const String _keyCurrentDerivationIndex = 'current_derivation_index';

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
  static const String _keyLockOnBackground = 'lock_on_background';
  static const String _keyBackendSessionPrefix = 'backend_session_';
  static const String _keyNotificationDevicePrefix = 'notification_device_';
  static const String _keyPushPreferencePrefix = 'push_pref_';
  static const String _keyEnabledChainFamilies = 'enabled_chain_families';

  static const int maxFailedAttempts = 5;
  // 60-second lockout after maxFailedAttempts consecutive wrong passcode
  // attempts. This limits brute-force to ≤300 guesses/hour while remaining
  // tolerable for legitimate users who forget their PIN.
  static const int lockoutDurationSeconds = 60;
  static const int _passcodeHashVersion = 2;
  static const int _passcodeHashIterations = 3;
  static const int _passcodeSaltLength = 16;
  static const int _passcodeHashBytes = 32;
  static const int _passcodeMemoryPowerOf2 = 16;

  Future<SharedPreferences> get _prefs async =>
      _sharedPreferences ?? SharedPreferences.getInstance();

  Future<void> saveWallet({
    required String address,
    required String privateKey,
    String? mnemonic,
    String? walletName,
    WalletOrigin origin = WalletOrigin.derived,
    int? derivationIndex,
    DateTime? createdAt,
    Map<ChainFamily, String>? addressesByFamily,
  }) async {
    await _secureStore.write(key: _keyAddress, value: address);
    await _secureStore.write(key: _keyPrivateKey, value: privateKey);
    await _secureStore.write(
      key: _walletPrivateKeyKey(address),
      value: privateKey,
    );

    if (mnemonic != null) {
      await _secureStore.write(key: _keyMnemonic, value: mnemonic);
    }

    if (walletName != null) {
      await _secureStore.write(key: _keyWalletName, value: walletName);
    }

    final account = WalletAccount(
      address: address,
      name: walletName ?? 'Wallet',
      origin: origin,
      derivationIndex: derivationIndex,
      createdAt: createdAt ?? DateTime.now(),
      addressesByFamily: addressesByFamily,
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

  Future<String?> getWalletAddress() => _secureStore.read(key: _keyAddress);

  Future<String?> getPrivateKey() async {
    final address = await getWalletAddress();
    if (address != null) {
      final existing = await _secureStore.read(
        key: _walletPrivateKeyKey(address),
      );
      if (existing != null) return existing;
    }
    return _secureStore.read(key: _keyPrivateKey);
  }

  Future<String?> getPrivateKeyForAddress(String address) {
    return _secureStore.read(key: _walletPrivateKeyKey(address));
  }

  Future<String?> getMnemonic() => _secureStore.read(key: _keyMnemonic);

  Future<String?> getWalletName() => _secureStore.read(key: _keyWalletName);

  Future<void> saveBackendSession({
    required String walletAddress,
    required String token,
    required String expiresAt,
  }) {
    return _secureStore.write(
      key: _backendSessionKey(walletAddress),
      value: jsonEncode({'token': token, 'expiresAt': expiresAt}),
    );
  }

  Future<Map<String, String>?> getBackendSession(String walletAddress) async {
    final raw = await _secureStore.read(key: _backendSessionKey(walletAddress));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final token = decoded['token']?.toString();
      final expiresAt = decoded['expiresAt']?.toString();
      if (token == null ||
          token.isEmpty ||
          expiresAt == null ||
          expiresAt.isEmpty) {
        return null;
      }
      return {'token': token, 'expiresAt': expiresAt};
    } catch (_) {
      return null;
    }
  }

  Future<void> clearBackendSession(String walletAddress) {
    return _secureStore.delete(key: _backendSessionKey(walletAddress));
  }

  Future<void> saveNotificationDeviceRegistration({
    required String walletAddress,
    required String token,
    required String appVersion,
  }) {
    return _secureStore.write(
      key: _notificationDeviceKey(walletAddress),
      value: jsonEncode({'token': token, 'appVersion': appVersion}),
    );
  }

  Future<Map<String, String>?> getNotificationDeviceRegistration(
    String walletAddress,
  ) async {
    final raw = await _secureStore.read(
      key: _notificationDeviceKey(walletAddress),
    );
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final token = decoded['token']?.toString();
      final appVersion = decoded['appVersion']?.toString();
      if (token == null || token.isEmpty) {
        return null;
      }
      return {'token': token, 'appVersion': appVersion ?? ''};
    } catch (_) {
      return null;
    }
  }

  Future<void> clearNotificationDeviceRegistration(String walletAddress) {
    return _secureStore.delete(key: _notificationDeviceKey(walletAddress));
  }

  Future<void> setPushNotificationsEnabledForWallet(
    String walletAddress,
    bool enabled,
  ) {
    return _secureStore.write(
      key: _pushPreferenceKey(walletAddress),
      value: enabled ? '1' : '0',
    );
  }

  Future<bool?> getPushNotificationsEnabledForWallet(
    String walletAddress,
  ) async {
    final raw = await _secureStore.read(key: _pushPreferenceKey(walletAddress));
    if (raw == null || raw.isEmpty) return null;
    if (raw == '1') return true;
    if (raw == '0') return false;
    return null;
  }

  Future<void> deleteWallet() async {
    await _secureStore.delete(key: _keyAddress);
    await _secureStore.delete(key: _keyPrivateKey);
    await _secureStore.delete(key: _keyMnemonic);
    await _secureStore.delete(key: _keyWalletName);
  }

  Future<void> setActiveWallet(String? address) async {
    if (address == null) {
      await clearActiveWallet();
      return;
    }
    final wallet = await _findWallet(address);
    if (wallet == null) throw Exception('Wallet not found');
    final privateKey = await _secureStore.read(
      key: _walletPrivateKeyKey(address),
    );
    if (privateKey == null) throw Exception('Missing private key for wallet');
    await _secureStore.write(key: _keyAddress, value: address);
    await _secureStore.write(key: _keyPrivateKey, value: privateKey);
    await _secureStore.write(key: _keyWalletName, value: wallet.name);
    if (wallet.derivationIndex != null) {
      await _setCurrentDerivationIndex(wallet.derivationIndex!);
    }
  }

  Future<void> clearActiveWallet() async {
    await _secureStore.delete(key: _keyAddress);
    await _secureStore.delete(key: _keyPrivateKey);
    await _secureStore.delete(key: _keyWalletName);
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
      addressesByFamily: account.addressesByFamily,
    );
    await _saveWalletAccounts(accounts);
    final activeAddress = await getWalletAddress();
    if (activeAddress != null &&
        activeAddress.toLowerCase() == address.toLowerCase()) {
      await _secureStore.write(key: _keyWalletName, value: newName);
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
      final replacementPk = await _secureStore.read(
        key: _walletPrivateKeyKey(replacement.address),
      );
      if (replacementPk == null) {
        throw Exception('Replacement wallet private key is missing');
      }

      await _secureStore.write(key: _keyAddress, value: replacement.address);
      await _secureStore.write(key: _keyPrivateKey, value: replacementPk);
      await _secureStore.write(key: _keyWalletName, value: replacement.name);
      if (replacement.derivationIndex != null) {
        await _setCurrentDerivationIndex(replacement.derivationIndex!);
      }
    }

    accounts.removeAt(index);
    await _saveWalletAccounts(accounts);
    await _secureStore.delete(key: _walletPrivateKeyKey(address));
  }

  Future<List<WalletAccount>> getWalletAccounts() async {
    final prefs = await _prefs;
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
    final prefs = await _prefs;
    return prefs.getInt(_keyNextDerivationIndex) ?? 1;
  }

  Future<void> setNextDerivationIndex(int index) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyNextDerivationIndex, index);
  }

  Future<int?> getCurrentDerivationIndex() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyCurrentDerivationIndex);
  }

  Future<void> _setCurrentDerivationIndex(int index) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyCurrentDerivationIndex, index);
  }

  Future<void> _saveWalletAccounts(List<WalletAccount> accounts) async {
    final prefs = await _prefs;
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

  String _familyPrivateKeyKey(ChainFamily family, String address) =>
      'family_pk_${family.name}_${address.toLowerCase()}';

  Future<void> saveFamilyPrivateKey({
    required ChainFamily family,
    required String address,
    required String privateKey,
  }) => _secureStore.write(
    key: _familyPrivateKeyKey(family, address),
    value: privateKey,
  );

  Future<String?> getFamilyPrivateKey(ChainFamily family, String address) =>
      _secureStore.read(key: _familyPrivateKeyKey(family, address));

  String _backendSessionKey(String address) =>
      '$_keyBackendSessionPrefix${address.toLowerCase()}';

  String _notificationDeviceKey(String address) =>
      '$_keyNotificationDevicePrefix${address.toLowerCase()}';

  String _pushPreferenceKey(String address) =>
      '$_keyPushPreferencePrefix${address.toLowerCase()}';

  Future<void> savePasscode(String passcode) async {
    await _secureStore.write(
      key: _keyPasscode,
      value: jsonEncode(await _buildPasscodeRecord(passcode)),
    );
  }

  Future<bool> hasPasscode() async {
    final stored = await _secureStore.read(key: _keyPasscode);
    return stored != null && stored.isNotEmpty;
  }

  Future<bool> verifyPasscode(String passcode) async {
    final stored = await _secureStore.read(key: _keyPasscode);
    if (stored == null || stored.isEmpty) return false;

    final record = _decodePasscodeRecord(stored);
    if (record == null) {
      final isLegacyMatch = stored == passcode;
      if (isLegacyMatch) {
        await savePasscode(passcode);
      }
      return isLegacyMatch;
    }

    final derivedHash = await _derivePasscodeHashAsync(
      passcode: passcode,
      salt: record.salt,
      iterations: record.iterations,
      memoryPowerOf2: record.memoryPowerOf2,
    );
    return _constantTimeEquals(record.hash, derivedHash);
  }

  Future<void> deletePasscode() => _secureStore.delete(key: _keyPasscode);

  Future<int> getFailedAttempts() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyFailedAttempts) ?? 0;
  }

  Future<void> incrementFailedAttempts() async {
    final prefs = await _prefs;
    final current = prefs.getInt(_keyFailedAttempts) ?? 0;
    await prefs.setInt(_keyFailedAttempts, current + 1);
  }

  Future<void> resetFailedAttempts() async {
    final prefs = await _prefs;
    await prefs.setInt(_keyFailedAttempts, 0);
    await prefs.remove(_keyLockoutUntil);
  }

  Future<void> setLockout() async {
    final prefs = await _prefs;
    final lockoutTime = DateTime.now()
        .add(const Duration(seconds: lockoutDurationSeconds))
        .millisecondsSinceEpoch;
    await prefs.setInt(_keyLockoutUntil, lockoutTime);
  }

  Future<DateTime?> getLockoutUntil() async {
    final prefs = await _prefs;
    final lockoutMs = prefs.getInt(_keyLockoutUntil);
    if (lockoutMs == null) return null;
    final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutMs);
    if (DateTime.now().isAfter(lockoutTime)) {
      await prefs.remove(_keyLockoutUntil);
      await prefs.setInt(_keyFailedAttempts, 0);
      return null;
    }
    return lockoutTime;
  }

  Future<bool> isLockedOut() async => await getLockoutUntil() != null;

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyBiometricEnabled, enabled);
    if (!enabled) {
      await prefs.setBool(_keyFaceIdEnabled, false);
      await prefs.setBool(_keyFingerprintEnabled, false);
    }
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await _prefs;
    return (prefs.getBool(_keyBiometricEnabled) ?? false) ||
        (prefs.getBool(_keyFingerprintEnabled) ?? false) ||
        (prefs.getBool(_keyFaceIdEnabled) ?? false);
  }

  Future<void> setFaceIdEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyFaceIdEnabled, enabled);
    if (enabled) {
      await prefs.setBool(_keyBiometricEnabled, true);
    }
  }

  Future<bool> isFaceIdEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyFaceIdEnabled) ?? false;
  }

  Future<void> setFingerprintEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyFingerprintEnabled, enabled);
    if (enabled) {
      await prefs.setBool(_keyBiometricEnabled, true);
    }
  }

  Future<bool> isFingerprintEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyFingerprintEnabled) ?? false;
  }

  Future<void> setTwoFactorEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyTwoFactorEnabled, enabled);
  }

  Future<bool> isTwoFactorEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyTwoFactorEnabled) ?? false;
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyAutoLockMinutes, minutes);
  }

  Future<int> getAutoLockMinutes() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyAutoLockMinutes) ?? 1;
  }

  Future<void> setLockOnBackground(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyLockOnBackground, enabled);
  }

  Future<bool> isLockOnBackgroundEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyLockOnBackground) ?? true;
  }

  Future<void> setLanguage(String languageCode) async {
    final prefs = await _prefs;
    final normalized = LanguageUtils.normalizeLanguageCode(languageCode);
    await prefs.setString(_keyLanguage, normalized);
  }

  Future<String?> getLanguage() async {
    final prefs = await _prefs;
    final stored = prefs.getString(_keyLanguage);
    if (stored == null || stored.isEmpty) return null;
    return LanguageUtils.normalizeLanguageCode(stored);
  }

  Future<void> setCurrency(String currencyCode) async {
    final prefs = await _prefs;
    await prefs.setString(_keyCurrency, currencyCode);
  }

  Future<String> getCurrency() async {
    final prefs = await _prefs;
    return prefs.getString(_keyCurrency) ?? 'USD';
  }

  Future<bool> isFirstLaunch() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyFirstLaunch) ?? true;
  }

  Future<void> setFirstLaunchCompleted() async {
    final prefs = await _prefs;
    await prefs.setBool(_keyFirstLaunch, false);
  }

  Future<void> setEnabledChainFamilies(Set<ChainFamily> families) async {
    final prefs = await _prefs;
    final encoded = jsonEncode(families.map((f) => f.wireValue).toList());
    await prefs.setString(_keyEnabledChainFamilies, encoded);
  }

  /// Returns the persisted enabled families, or null if never set (new install).
  Future<Set<ChainFamily>?> getEnabledChainFamilies() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyEnabledChainFamilies);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChainFamilyCodec.fromWireValue(e as String?))
          .toSet();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    await _secureStore.deleteAll();
    final prefs = await _prefs;
    await prefs.clear();
  }

  Future<Map<String, dynamic>> _buildPasscodeRecord(String passcode) async {
    final saltBytes = List<int>.generate(
      _passcodeSaltLength,
      (_) => Random.secure().nextInt(256),
    );
    final salt = base64Encode(saltBytes);
    return {
      'version': _passcodeHashVersion,
      'algorithm': 'argon2id',
      'iterations': _passcodeHashIterations,
      'memoryPowerOf2': _passcodeMemoryPowerOf2,
      'salt': salt,
      'hash': await _derivePasscodeHashAsync(
        passcode: passcode,
        salt: salt,
        iterations: _passcodeHashIterations,
        memoryPowerOf2: _passcodeMemoryPowerOf2,
      ),
    };
  }

  _PasscodeRecord? _decodePasscodeRecord(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final version = decoded['version'];
      final iterations = decoded['iterations'];
      final memoryPowerOf2 = decoded['memoryPowerOf2'];
      final salt = decoded['salt'];
      final hash = decoded['hash'];
      if (version != _passcodeHashVersion ||
          iterations is! int ||
          memoryPowerOf2 is! int ||
          salt is! String ||
          hash is! String) {
        return null;
      }
      return _PasscodeRecord(
        iterations: iterations,
        memoryPowerOf2: memoryPowerOf2,
        salt: salt,
        hash: hash,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _derivePasscodeHashAsync({
    required String passcode,
    required String salt,
    required int iterations,
    required int memoryPowerOf2,
  }) async {
    try {
      return await rust_argon2.derivePasscodeHashArgon2(
        passcode: passcode,
        saltBase64: salt,
        iterations: iterations,
        memoryPowerOf2: memoryPowerOf2,
      );
    } catch (e) {
      debugPrint('Rust Argon2 failed, falling back to Dart: $e');
      return _derivePasscodeHashDart(
        passcode: passcode,
        salt: salt,
        iterations: iterations,
        memoryPowerOf2: memoryPowerOf2,
      );
    }
  }

  String _derivePasscodeHashDart({
    required String passcode,
    required String salt,
    required int iterations,
    required int memoryPowerOf2,
  }) {
    final parameters = dart_argon2.Argon2Parameters(
      dart_argon2.Argon2Parameters.ARGON2_id,
      Uint8List.fromList(base64Decode(salt)),
      version: dart_argon2.Argon2Parameters.ARGON2_VERSION_13,
      iterations: iterations,
      memoryPowerOf2: memoryPowerOf2,
    );
    final generator = dart_argon2.Argon2BytesGenerator()..init(parameters);
    final result = Uint8List(_passcodeHashBytes);
    generator.generateBytes(
      Uint8List.fromList(parameters.converter.convert(passcode)),
      result,
      0,
      result.length,
    );
    return base64Encode(result);
  }

  @visibleForTesting
  Future<String> derivePasscodeHashForTest({
    required String passcode,
    required String salt,
    required int iterations,
    required int memoryPowerOf2,
  }) {
    return _derivePasscodeHashAsync(
      passcode: passcode,
      salt: salt,
      iterations: iterations,
      memoryPowerOf2: memoryPowerOf2,
    );
  }

  @visibleForTesting
  String derivePasscodeHashDartForTest({
    required String passcode,
    required String salt,
    required int iterations,
    required int memoryPowerOf2,
  }) {
    return _derivePasscodeHashDart(
      passcode: passcode,
      salt: salt,
      iterations: iterations,
      memoryPowerOf2: memoryPowerOf2,
    );
  }

  bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    if (aBytes.length != bBytes.length) return false;
    var diff = 0;
    for (var i = 0; i < aBytes.length; i++) {
      diff |= aBytes[i] ^ bBytes[i];
    }
    return diff == 0;
  }
}

class _PasscodeRecord {
  const _PasscodeRecord({
    required this.iterations,
    required this.memoryPowerOf2,
    required this.salt,
    required this.hash,
  });

  final int iterations;
  final int memoryPowerOf2;
  final String salt;
  final String hash;
}
