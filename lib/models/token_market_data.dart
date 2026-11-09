class TokenMarketData {
  final double? priceUsd;
  final double? marketCapUsd;
  final double? totalSupply;
  final double? circulatingSupply;
  final String? genesisDate;
  final double? changePercent24h;

  const TokenMarketData({
    this.priceUsd,
    this.marketCapUsd,
    this.totalSupply,
    this.circulatingSupply,
    this.genesisDate,
    this.changePercent24h,
  });
}
