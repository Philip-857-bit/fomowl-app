import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'storage_service.dart';

/// Biometric Service
/// Handles biometric authentication (Face ID, Fingerprint, etc.)
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final StorageService _storage = StorageService();

  /// Check if device supports biometric authentication
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Check if device has biometrics enrolled
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Check if Face ID is available
  Future<bool> hasFaceId() async {
    // Face ID has been disabled per user request
    return false;
  }

  /// Check if Fingerprint is available
  Future<bool> hasFingerprint() async {
    final biometrics = await getAvailableBiometrics();
    // On Android 11+, face/fingerprint are reported as strong/weak
    // Check for fingerprint type OR strong/weak (which includes fingerprint)
    return biometrics.contains(BiometricType.fingerprint) ||
           biometrics.contains(BiometricType.strong) ||
           biometrics.contains(BiometricType.weak);
  }

  /// Authenticate with biometrics
  Future<bool> authenticate({
    String localizedReason = 'Please authenticate to access your wallet',
  }) async {
    try {
      final canAuthenticate = await canCheckBiometrics();
      if (!canAuthenticate) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: localizedReason,
      );
    } on PlatformException {
      return false;
    }
  }

  /// Stop authentication
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } on PlatformException {
      // Ignore errors
    }
  }

  /// Enable biometric authentication
  Future<void> enableBiometric() async {
    await _storage.setBiometricEnabled(true);
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    await _storage.setBiometricEnabled(false);
  }

  /// Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    return await _storage.isBiometricEnabled();
  }

  /// Enable Face ID
  Future<void> enableFaceId() async {
    await _storage.setFaceIdEnabled(true);
  }

  /// Disable Face ID
  Future<void> disableFaceId() async {
    await _storage.setFaceIdEnabled(false);
  }

  /// Check if Face ID is enabled
  Future<bool> isFaceIdEnabled() async {
    return await _storage.isFaceIdEnabled();
  }

  /// Enable Fingerprint
  Future<void> enableFingerprint() async {
    await _storage.setFingerprintEnabled(true);
  }

  /// Disable Fingerprint
  Future<void> disableFingerprint() async {
    await _storage.setFingerprintEnabled(false);
  }

  /// Check if Fingerprint is enabled
  Future<bool> isFingerprintEnabled() async {
    return await _storage.isFingerprintEnabled();
  }

  /// Get biometric type name for display
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
    }
  }
}
