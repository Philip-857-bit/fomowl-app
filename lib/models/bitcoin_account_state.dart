import 'chain.dart';

enum BitcoinProductNetwork {
  mainnet('mainnet'),
  testnet4('testnet4');

  const BitcoinProductNetwork(this.id);
  final String id;
  String get networkKey => NetworkKey.bitcoin(id);
  static BitcoinProductNetwork fromId(Object? value) => switch (value) {
    'mainnet' => mainnet,
    'testnet4' => testnet4,
    _ => throw const FormatException('Invalid Bitcoin account network'),
  };
}

enum BitcoinPurpose {
  bip84(84),
  bip86(86);

  const BitcoinPurpose(this.number);
  final int number;
  static BitcoinPurpose fromNumber(Object? value) {
    if (value is! int) {
      throw const FormatException('Invalid Bitcoin account purpose');
    }
    return switch (value) {
      84 => bip84,
      86 => bip86,
      _ => throw const FormatException('Invalid Bitcoin account purpose'),
    };
  }
}

enum BitcoinKeychain { receive, change }

int _childIndex(Object? value) {
  if (value is! int || value < 0 || value >= 0x80000000) {
    throw const FormatException('Invalid Bitcoin account index');
  }
  return value;
}

int? _optionalIndex(Object? value) => value == null ? null : _childIndex(value);
Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid Bitcoin account state');
  }
  return value;
}

/// Public HD identity. The host still verifies its cryptographic validity with Rust.
/// XPUBs stay in protected storage because they reveal complete account activity.
class BitcoinHdAccountMetadata {
  final BitcoinProductNetwork network;
  final BitcoinPurpose purpose;
  final int accountIndex;
  final String masterFingerprint;
  final String accountXpub;
  BitcoinHdAccountMetadata({
    required this.network,
    required this.purpose,
    required this.accountIndex,
    required this.masterFingerprint,
    required this.accountXpub,
  }) {
    _childIndex(accountIndex);
    if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(masterFingerprint) ||
        !accountXpub.startsWith(
          network == BitcoinProductNetwork.mainnet ? 'xpub' : 'tpub',
        ) ||
        accountXpub.length > 128 ||
        RegExp(r'\s').hasMatch(accountXpub)) {
      throw const FormatException('Invalid Bitcoin public account metadata');
    }
  }
  factory BitcoinHdAccountMetadata.fromJson(Map<String, dynamic> json) =>
      BitcoinHdAccountMetadata(
        network: BitcoinProductNetwork.fromId(json['network']),
        purpose: BitcoinPurpose.fromNumber(json['purpose']),
        accountIndex: _childIndex(json['accountIndex']),
        masterFingerprint: json['masterFingerprint'] is String
            ? json['masterFingerprint'] as String
            : '',
        accountXpub: json['accountXpub'] is String
            ? json['accountXpub'] as String
            : '',
      );
  Map<String, dynamic> toJson() => {
    'network': network.id,
    'purpose': purpose.number,
    'accountIndex': accountIndex,
    'masterFingerprint': masterFingerprint,
    'accountXpub': accountXpub,
  };
  @override
  bool operator ==(Object other) =>
      other is BitcoinHdAccountMetadata &&
      other.network == network &&
      other.purpose == purpose &&
      other.accountIndex == accountIndex &&
      other.masterFingerprint == masterFingerprint &&
      other.accountXpub == accountXpub;
  @override
  int get hashCode => Object.hash(
    network,
    purpose,
    accountIndex,
    masterFingerprint,
    accountXpub,
  );
  @override
  String toString() =>
      'BitcoinHdAccountMetadata(${network.id}, ${purpose.number}, $accountIndex)';
}

/// Monotonic host discovery/allocation state; no private material or static wallet address.
class BitcoinPurposeAccountState {
  final BitcoinHdAccountMetadata metadata;
  final int? lastUsedExternal;
  final int? lastUsedInternal;
  final int nextExternal;
  final int nextInternal;
  final DateTime? lastScan;
  BitcoinPurposeAccountState({
    required this.metadata,
    this.lastUsedExternal,
    this.lastUsedInternal,
    this.nextExternal = 0,
    this.nextInternal = 0,
    this.lastScan,
  }) {
    _childIndex(nextExternal);
    _childIndex(nextInternal);
    _optionalIndex(lastUsedExternal);
    _optionalIndex(lastUsedInternal);
    if (lastUsedExternal != null && nextExternal <= lastUsedExternal! ||
        lastUsedInternal != null && nextInternal <= lastUsedInternal!) {
      throw const FormatException('Bitcoin address index rollback');
    }
  }
  factory BitcoinPurposeAccountState.fromJson(Map<String, dynamic> json) {
    final rawScan = json['lastScan'];
    final scan = rawScan is String ? DateTime.tryParse(rawScan) : null;
    if (rawScan != null && scan == null) {
      throw const FormatException('Invalid Bitcoin scan timestamp');
    }
    return BitcoinPurposeAccountState(
      metadata: BitcoinHdAccountMetadata.fromJson(_object(json['metadata'])),
      lastUsedExternal: _optionalIndex(json['lastUsedExternal']),
      lastUsedInternal: _optionalIndex(json['lastUsedInternal']),
      nextExternal: _childIndex(json['nextExternal']),
      nextInternal: _childIndex(json['nextInternal']),
      lastScan: scan,
    );
  }
  BitcoinPurposeAccountState advance({
    int? lastUsedExternal,
    int? lastUsedInternal,
    int? nextExternal,
    int? nextInternal,
    DateTime? lastScan,
  }) {
    final external = lastUsedExternal ?? this.lastUsedExternal;
    final internal = lastUsedInternal ?? this.lastUsedInternal;
    final nextReceive = nextExternal ?? this.nextExternal;
    final nextChange = nextInternal ?? this.nextInternal;
    if (nextReceive < this.nextExternal ||
        nextChange < this.nextInternal ||
        (this.lastUsedExternal != null &&
            (external == null || external < this.lastUsedExternal!)) ||
        (this.lastUsedInternal != null &&
            (internal == null || internal < this.lastUsedInternal!)) ||
        (lastScan != null &&
            this.lastScan != null &&
            lastScan.isBefore(this.lastScan!))) {
      throw StateError('Bitcoin account state cannot move backwards');
    }
    return BitcoinPurposeAccountState(
      metadata: metadata,
      lastUsedExternal: external,
      lastUsedInternal: internal,
      nextExternal: nextReceive,
      nextInternal: nextChange,
      lastScan: lastScan ?? this.lastScan,
    );
  }

  Map<String, dynamic> toJson() => {
    'metadata': metadata.toJson(),
    'lastUsedExternal': lastUsedExternal,
    'lastUsedInternal': lastUsedInternal,
    'nextExternal': nextExternal,
    'nextInternal': nextInternal,
    'lastScan': lastScan?.toUtc().toIso8601String(),
  };
  @override
  String toString() =>
      'BitcoinPurposeAccountState(${metadata.purpose.number}, REDACTED)';
}

class BitcoinWalletAccountState {
  final String walletIdentity;
  final BitcoinProductNetwork network;
  final int accountIndex;
  final Map<BitcoinPurpose, BitcoinPurposeAccountState> accounts;
  BitcoinWalletAccountState({
    required this.walletIdentity,
    required this.network,
    required this.accountIndex,
    required Map<BitcoinPurpose, BitcoinPurposeAccountState> accounts,
  }) : accounts = Map.unmodifiable(accounts) {
    _childIndex(accountIndex);
    if (walletIdentity.isEmpty ||
        walletIdentity.length > 128 ||
        accounts.isEmpty ||
        accounts.length > 2) {
      throw const FormatException('Invalid Bitcoin wallet identity');
    }
    final fingerprint = accounts.values.first.metadata.masterFingerprint;
    final xpubs = <String>{};
    for (final entry in accounts.entries) {
      if (entry.key != entry.value.metadata.purpose ||
          entry.value.metadata.network != network ||
          entry.value.metadata.accountIndex != accountIndex ||
          entry.value.metadata.masterFingerprint != fingerprint ||
          !xpubs.add(entry.value.metadata.accountXpub)) {
        throw const FormatException('Bitcoin HD account identity mismatch');
      }
    }
  }
  factory BitcoinWalletAccountState.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 || json['walletIdentity'] is! String) {
      throw const FormatException('Invalid Bitcoin wallet state');
    }
    final accounts = _object(json['accounts']);
    final parsed = <BitcoinPurpose, BitcoinPurposeAccountState>{};
    for (final entry in accounts.entries) {
      final purpose = BitcoinPurpose.fromNumber(int.tryParse(entry.key));
      if (entry.key != purpose.number.toString()) {
        throw const FormatException('Invalid Bitcoin account purpose');
      }
      parsed[purpose] = BitcoinPurposeAccountState.fromJson(
        _object(entry.value),
      );
    }
    return BitcoinWalletAccountState(
      walletIdentity: json['walletIdentity'] as String,
      network: BitcoinProductNetwork.fromId(json['network']),
      accountIndex: _childIndex(json['accountIndex']),
      accounts: parsed,
    );
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'walletIdentity': walletIdentity,
    'network': network.id,
    'accountIndex': accountIndex,
    'accounts': accounts.map(
      (purpose, state) => MapEntry(purpose.number.toString(), state.toJson()),
    ),
  };
  @override
  String toString() =>
      'BitcoinWalletAccountState(${network.id}, $accountIndex, REDACTED)';
}
