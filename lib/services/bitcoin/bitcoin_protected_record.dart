import 'dart:convert';
import 'dart:typed_data';
import 'package:hex/hex.dart';
import '../../models/bitcoin_account_state.dart';

class BitcoinAccountSlot {
  final String walletIdentity;
  final BitcoinProductNetwork network;
  final int accountIndex;
  final BitcoinPurpose purpose;
  BitcoinAccountSlot({
    required String walletIdentity,
    required this.network,
    required this.accountIndex,
    required this.purpose,
  }) : walletIdentity = walletIdentity.trim().toLowerCase() {
    if (this.walletIdentity.isEmpty ||
        this.walletIdentity.length > 128 ||
        accountIndex < 0 ||
        accountIndex >= 0x80000000) {
      throw const FormatException('Invalid Bitcoin storage identity');
    }
  }
  String get storageKey =>
      'bitcoin_hd_v1_${Uri.encodeComponent(walletIdentity)}_${network.id}_${accountIndex}_${purpose.number}';
  Map<String, dynamic> toJson() => {
    'network': network.id,
    'accountIndex': accountIndex,
    'purpose': purpose.number,
  };
  factory BitcoinAccountSlot.fromJson(
    String walletIdentity,
    Map<String, dynamic> json,
  ) {
    final index = json['accountIndex'];
    if (index is! int) {
      throw const FormatException('Invalid Bitcoin storage identity');
    }
    return BitcoinAccountSlot(
      walletIdentity: walletIdentity,
      network: BitcoinProductNetwork.fromId(json['network']),
      accountIndex: index,
      purpose: BitcoinPurpose.fromNumber(json['purpose']),
    );
  }
  bool matches(BitcoinHdAccountMetadata account) =>
      account.network == network &&
      account.purpose == purpose &&
      account.accountIndex == accountIndex;
}

/// One atomic protected value binds public state, authenticated ciphertext and wrapping material.
/// Callers must dispose the wrapping bytes; this is software custody protected by platform storage.
class ProtectedBitcoinRecord {
  final String walletIdentity;
  final BitcoinPurposeAccountState state;
  final String encryptedVault;
  final Uint8List wrappingKey;
  final int revision;
  ProtectedBitcoinRecord({
    required this.walletIdentity,
    required this.state,
    required this.encryptedVault,
    required this.wrappingKey,
    this.revision = 0,
  }) {
    if (walletIdentity.isEmpty ||
        walletIdentity.length > 128 ||
        encryptedVault.isEmpty ||
        encryptedVault.length > 16384 ||
        wrappingKey.length != 32 ||
        revision < 0 ||
        revision >= 0x80000000) {
      throw const FormatException('Invalid protected Bitcoin record');
    }
  }
  factory ProtectedBitcoinRecord.decode(String encoded) {
    if (encoded.length > 65536) {
      throw const FormatException('Invalid protected Bitcoin record');
    }
    Object? raw;
    try {
      raw = jsonDecode(encoded);
    } catch (_) {
      throw const FormatException('Invalid protected Bitcoin record');
    }
    if (raw is! Map<String, dynamic> ||
        raw.length != 6 ||
        raw['version'] is! int ||
        raw['version'] != 1 ||
        raw['walletIdentity'] is! String ||
        raw['encryptedVault'] is! String ||
        raw['wrappingKeyHex'] is! String ||
        raw['revision'] is! int ||
        raw['state'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid protected Bitcoin record');
    }
    final key = raw['wrappingKeyHex'] as String;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
      throw const FormatException('Invalid protected Bitcoin wrapping key');
    }
    // Validate non-secret state first so a failed parse never leaves allocated wrapping bytes.
    final state = BitcoinPurposeAccountState.fromJson(
      raw['state'] as Map<String, dynamic>,
    );
    final bytes = Uint8List.fromList(HEX.decode(key));
    try {
      return ProtectedBitcoinRecord(
        walletIdentity: raw['walletIdentity'] as String,
        state: state,
        encryptedVault: raw['encryptedVault'] as String,
        wrappingKey: bytes,
        revision: raw['revision'] as int,
      );
    } catch (_) {
      bytes.fillRange(0, bytes.length, 0);
      rethrow;
    }
  }
  bool matches(BitcoinAccountSlot slot) =>
      walletIdentity == slot.walletIdentity && slot.matches(state.metadata);
  ProtectedBitcoinRecord withState(BitcoinPurposeAccountState newState) =>
      ProtectedBitcoinRecord(
        walletIdentity: walletIdentity,
        state: newState,
        encryptedVault: encryptedVault,
        wrappingKey: wrappingKey,
        revision: revision + 1,
      );
  String encode() => jsonEncode({
    'version': 1,
    'walletIdentity': walletIdentity,
    'state': state.toJson(),
    'encryptedVault': encryptedVault,
    'wrappingKeyHex': HEX.encode(wrappingKey),
    'revision': revision,
  });
  void dispose() => wrappingKey.fillRange(0, wrappingKey.length, 0);
  @override
  String toString() => 'ProtectedBitcoinRecord(REDACTED)';
}
