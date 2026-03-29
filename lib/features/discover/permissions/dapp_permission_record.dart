class DappPermissionRecord {
  const DappPermissionRecord({
    required this.origin,
    required this.walletAddress,
    required this.connectedAt,
  });

  final String origin;
  final String walletAddress;
  final DateTime connectedAt;

  factory DappPermissionRecord.fromJson(Map<String, dynamic> json) {
    return DappPermissionRecord(
      origin: (json['origin'] ?? '').toString(),
      walletAddress: (json['walletAddress'] ?? '').toString().toLowerCase(),
      connectedAt:
          DateTime.tryParse((json['connectedAt'] ?? '').toString())?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() => {
    'origin': origin,
    'walletAddress': walletAddress,
    'connectedAt': connectedAt.toUtc().toIso8601String(),
  };
}
