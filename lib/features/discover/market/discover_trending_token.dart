class DiscoverTrendingToken {
  const DiscoverTrendingToken({
    required this.id,
    required this.symbol,
    required this.name,
    required this.imageUrl,
    required this.priceUsd,
    required this.changePercent24h,
  });

  final String id;
  final String symbol;
  final String name;
  final String imageUrl;
  final double priceUsd;
  final double changePercent24h;

  factory DiscoverTrendingToken.fromJson(Map<String, dynamic> json) {
    String requireTextField(String key) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw FormatException(
          'Discover trending token is missing required field: $key',
        );
      }
      return value;
    }

    double parseDoubleField(String key) {
      final value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value) ?? 0;
      }
      return 0;
    }

    return DiscoverTrendingToken(
      id: requireTextField('id'),
      symbol: requireTextField('symbol'),
      name: requireTextField('name'),
      imageUrl: requireTextField('imageUrl'),
      priceUsd: parseDoubleField('priceUsd'),
      changePercent24h: parseDoubleField('changePercent24h'),
    );
  }
}
