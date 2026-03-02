enum WalletOrigin { derived, imported }

class WalletAccount {
  final String address;
  final String name;
  final WalletOrigin origin;
  final int? derivationIndex;
  final DateTime createdAt;

  const WalletAccount({
    required this.address,
    required this.name,
    required this.origin,
    this.derivationIndex,
    required this.createdAt,
  });

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    return WalletAccount(
      address: json['address'] as String,
      name: json['name'] as String? ?? 'Wallet',
      origin: WalletOrigin.values.firstWhere(
        (o) =>
            o.name == (json['origin'] as String? ?? WalletOrigin.derived.name),
        orElse: () => WalletOrigin.derived,
      ),
      derivationIndex: json['derivationIndex'] as int?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'address': address,
    'name': name,
    'origin': origin.name,
    'derivationIndex': derivationIndex,
    'createdAt': createdAt.toIso8601String(),
  };
}
