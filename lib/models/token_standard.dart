enum TokenStandard { native, erc20, spl, trc20 }

extension TokenStandardCodec on TokenStandard {
  String get wireValue => switch (this) {
    TokenStandard.native => 'native',
    TokenStandard.erc20 => 'erc20',
    TokenStandard.spl => 'spl',
    TokenStandard.trc20 => 'trc20',
  };

  static TokenStandard fromWireValue(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'native' => TokenStandard.native,
      'spl' => TokenStandard.spl,
      'trc20' => TokenStandard.trc20,
      _ => TokenStandard.erc20,
    };
  }
}
