import 'chain.dart';

enum WalletOrigin { derived, imported }

class WalletAccount {
  final String address;
  final String name;
  final WalletOrigin origin;
  final int? derivationIndex;
  final String? seedGroupId;
  final DateTime createdAt;
  final Map<ChainFamily, String> addressesByFamily;
  final bool supportsBitcoin;

  WalletAccount({
    required this.address,
    required this.name,
    required this.origin,
    this.derivationIndex,
    this.seedGroupId,
    required this.createdAt,
    bool supportsBitcoin = false,
    Map<ChainFamily, String>? addressesByFamily,
  }) : supportsBitcoin = supportsBitcoin && origin == WalletOrigin.derived,
       addressesByFamily = Map.unmodifiable(
         _normalizeAddressesByFamily(address, addressesByFamily),
       );

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as String? ?? '';
    return WalletAccount(
      address: address,
      name: json['name'] as String? ?? 'Wallet',
      origin: WalletOrigin.values.firstWhere(
        (o) =>
            o.name == (json['origin'] as String? ?? WalletOrigin.derived.name),
        orElse: () => WalletOrigin.derived,
      ),
      derivationIndex: json['derivationIndex'] as int?,
      seedGroupId: (json['seedGroupId'] as String?)?.trim().isNotEmpty == true
          ? (json['seedGroupId'] as String).trim()
          : null,
      supportsBitcoin: json['supportsBitcoin'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      addressesByFamily: _parseAddressesByFamily(
        json['addressesByFamily'],
        address,
      ),
    );
  }

  bool supportsFamily(ChainFamily family) => family == ChainFamily.bitcoin
      ? supportsBitcoin && origin == WalletOrigin.derived
      : getWalletAddressForFamily(family) != null;

  String? getWalletAddressForFamily(ChainFamily family) {
    if (family == ChainFamily.bitcoin) return null;
    final mapped = addressesByFamily[family]?.trim();
    if (mapped != null && mapped.isNotEmpty) {
      return mapped;
    }
    if (family == ChainFamily.evm && address.trim().startsWith('0x')) {
      return address;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'address': address,
    'supportsBitcoin': supportsBitcoin && origin == WalletOrigin.derived,
    'addressesByFamily': addressesByFamily.map(
      (family, familyAddress) => MapEntry(family.wireValue, familyAddress),
    ),
    'name': name,
    'origin': origin.name,
    'derivationIndex': derivationIndex,
    if (seedGroupId != null && seedGroupId!.isNotEmpty)
      'seedGroupId': seedGroupId,
    'createdAt': createdAt.toIso8601String(),
  };

  static Map<ChainFamily, String> _normalizeAddressesByFamily(
    String address,
    Map<ChainFamily, String>? addressesByFamily,
  ) {
    final normalized = <ChainFamily, String>{};
    addressesByFamily?.forEach((family, familyAddress) {
      final trimmed = familyAddress.trim();
      if (family != ChainFamily.bitcoin && trimmed.isNotEmpty) {
        normalized[family] = trimmed;
      }
    });
    final evmAddress = address.trim();
    if (evmAddress.isNotEmpty && evmAddress.startsWith('0x')) {
      normalized.putIfAbsent(ChainFamily.evm, () => evmAddress);
    }
    return normalized;
  }

  static Map<ChainFamily, String> _parseAddressesByFamily(
    Object? raw,
    String legacyAddress,
  ) {
    final parsed = <ChainFamily, String>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        final family = ChainFamilyCodec.fromWireValue(key?.toString());
        final address = value?.toString().trim();
        if (family != ChainFamily.bitcoin &&
            address != null &&
            address.isNotEmpty) {
          parsed[family] = address;
        }
      });
    }
    return _normalizeAddressesByFamily(legacyAddress, parsed);
  }
}
