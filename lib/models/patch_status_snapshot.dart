enum AppPatchStatus {
  idle,
  unavailable,
  checking,
  outdated,
  downloading,
  upToDate,
  restartRequired,
  failed,
}

class PatchStatusSnapshot {
  const PatchStatusSnapshot({
    required this.appVersion,
    required this.buildNumber,
    required this.patchNumber,
    required this.status,
    required this.lastCheckedAt,
    required this.lastError,
  });

  const PatchStatusSnapshot.initial({
    required this.appVersion,
    required this.buildNumber,
  }) : patchNumber = null,
       status = AppPatchStatus.idle,
       lastCheckedAt = null,
       lastError = null;

  final String appVersion;
  final String buildNumber;
  final int? patchNumber;
  final AppPatchStatus status;
  final DateTime? lastCheckedAt;
  final String? lastError;

  String get releaseVersion => '$appVersion+$buildNumber';

  String get reportVersion {
    final patch = patchNumber;
    if (patch == null || patch <= 0) {
      return releaseVersion;
    }
    return '$releaseVersion-p$patch';
  }

  String get displayVersionLabel {
    final patch = patchNumber;
    if (patch == null || patch <= 0) {
      return 'Owllet v$appVersion';
    }
    return 'Owllet v$appVersion | patch $patch';
  }

  PatchStatusSnapshot copyWith({
    String? appVersion,
    String? buildNumber,
    Object? patchNumber = _sentinel,
    AppPatchStatus? status,
    Object? lastCheckedAt = _sentinel,
    Object? lastError = _sentinel,
  }) {
    return PatchStatusSnapshot(
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      patchNumber: identical(patchNumber, _sentinel)
          ? this.patchNumber
          : patchNumber as int?,
      status: status ?? this.status,
      lastCheckedAt: identical(lastCheckedAt, _sentinel)
          ? this.lastCheckedAt
          : lastCheckedAt as DateTime?,
      lastError: identical(lastError, _sentinel)
          ? this.lastError
          : lastError as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'patchNumber': patchNumber,
      'status': status.name,
      'lastCheckedAt': lastCheckedAt?.toIso8601String(),
      'lastError': lastError,
    };
  }

  static PatchStatusSnapshot fromJson(Map<String, dynamic> json) {
    return PatchStatusSnapshot(
      appVersion: json['appVersion']?.toString() ?? '0.0.0',
      buildNumber: json['buildNumber']?.toString() ?? '0',
      patchNumber: switch (json['patchNumber']) {
        int value => value,
        String value => int.tryParse(value),
        _ => null,
      },
      status: AppPatchStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => AppPatchStatus.idle,
      ),
      lastCheckedAt: switch (json['lastCheckedAt']) {
        String value when value.isNotEmpty => DateTime.tryParse(value),
        _ => null,
      },
      lastError: json['lastError']?.toString(),
    );
  }
}

const Object _sentinel = Object();
