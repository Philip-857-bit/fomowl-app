import 'dart:core';

class PhishingCheckResult {
  const PhishingCheckResult({
    required this.isBlocked,
    this.reason,
    this.targetedBrand,
    this.threatCategory,
  });

  final bool isBlocked;
  final String? reason;
  final String? targetedBrand;
  final String? threatCategory;

  static const PhishingCheckResult safe = PhishingCheckResult(isBlocked: false);
}

class PhishingProtectionService {
  PhishingProtectionService._();
  static final PhishingProtectionService instance =
      PhishingProtectionService._();

  // Known high-risk and scam domain patterns / drainers
  static const Set<String> _knownMaliciousDomains = {
    'airdrop-claim-portal.com',
    'claim-airdrop-rewards.xyz',
    'eth-claim-rewards.com',
    'revoke-allowance-cash.com',
    'wallet-connect-dapps.com',
    'connect-wallets-dapp.net',
    'dapps-authenticator.com',
    'sync-wallets-web3.com',
    'resolve-wallet-issue.com',
    'dapp-migration-portal.com',
    'metamask-security-update.com',
    'uniswap-v4-airdrop.com',
    'solana-reward-distribution.xyz',
    'jup-airdrop-claim.net',
    'raydium-swap-claim.org',
    'pancakeswap-airdrop-claim.org',
    'openseea-rewards.com',
    'opensea-rewards-portal.com',
  };

  // Official high-value Web3 brands and their authoritative domains
  static const Map<String, List<String>> _protectedBrands = {
    'uniswap': ['uniswap.org', 'app.uniswap.org'],
    'pancakeswap': ['pancakeswap.finance'],
    'opensea': ['opensea.io', 'pro.opensea.io'],
    'magiceden': ['magiceden.io'],
    'metamask': ['metamask.io'],
    'phantom': ['phantom.app'],
    'etherscan': ['etherscan.io'],
    'bscscan': ['bscscan.com'],
    'solscan': ['solscan.io'],
    'tronscan': ['tronscan.org'],
    'jupiter': ['jup.ag'],
    '1inch': ['1inch.io', 'app.1inch.io'],
    'curve': ['curve.fi', 'curve.finance'],
    'aave': ['aave.com', 'app.aave.com'],
    'lido': ['lido.fi'],
    'blur': ['blur.io'],
    'sunswap': ['sunswap.com'],
    'sunpump': ['sunpump.meme'],
    'raydium': ['raydium.io'],
    'pump': ['pump.fun'],
    'coingecko': ['coingecko.com'],
    'coinmarketcap': ['coinmarketcap.com'],
    'fomowl': ['fomowl.com', 'owlletapp.com'],
  };

  // Suspicious keywords commonly attached to brand names by phishing drainers
  static const List<String> _scamKeywords = [
    'airdrop',
    'claim',
    'reward',
    'rewards',
    'gift',
    'bonus',
    'migrate',
    'migration',
    'validate',
    'validation',
    'sync',
    'drain',
    'rectify',
    'refund',
    'giveaway',
    'presale',
    'whitelist',
    'auth',
    'authenticate',
    'connect-wallet',
  ];

  /// Returns true if [host] matches any official protected Web3 domain.
  bool isKnownLegitimateDomain(String host) {
    final clean = _extractRootDomain(host);
    for (final domains in _protectedBrands.values) {
      if (domains.any((d) => host == d || host.endsWith('.$d') || clean == d)) {
        return true;
      }
    }
    return false;
  }

  /// Evaluates an incoming URL or URI for phishing, homoglyphs, or brand impersonation.
  PhishingCheckResult checkUri(Uri uri) {
    String host = uri.host.trim().toLowerCase();
    if (host.contains('%')) {
      try {
        host = Uri.decodeComponent(host);
      } catch (_) {}
    }
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
      return PhishingCheckResult.safe;
    }

    // 1. Check direct known malicious blocklist
    if (_knownMaliciousDomains.contains(host)) {
      return PhishingCheckResult(
        isBlocked: true,
        threatCategory: 'Malicious Drainer',
        reason:
            'Security Alert: This domain ($host) has been identified as a confirmed phishing or crypto drainer site.',
      );
    }

    // 2. Punycode & Homoglyph detection (e.g. Cyrillic lookalikes "xn--..." or decoded non-ascii)
    if (host.contains('xn--') || _containsConfusableHomoglyphs(host)) {
      return PhishingCheckResult(
        isBlocked: true,
        threatCategory: 'Homograph Phishing Attack',
        reason: 'Security Alert: This domain uses deceptive international character substitution (homograph attack) mimicking a legitimate website.',
      );
    }

    // 3. If host is in the known legitimate whitelist, it is safe
    if (isKnownLegitimateDomain(host)) {
      return PhishingCheckResult.safe;
    }

    // 4. Brand Typosquatting and Impersonation detection
    final cleanHost = _extractRootDomain(host);
    for (final entry in _protectedBrands.entries) {
      final brand = entry.key;
      final legitDomains = entry.value;

      if (legitDomains.any((d) => host == d || host.endsWith('.$d'))) {
        continue;
      }

      // Check if domain contains the brand name accompanied by suspicious scam keywords
      final hasBrand = cleanHost.contains(brand);
      if (hasBrand) {
        for (final keyword in _scamKeywords) {
          if (cleanHost.contains(keyword)) {
            return PhishingCheckResult(
              isBlocked: true,
              targetedBrand: brand,
              threatCategory: 'Brand Impersonation / Phishing',
              reason:
                  'Security Alert: This website ($host) appears to be a fraudulent site impersonating ${brand.toUpperCase()} with deceptive keywords ($keyword).',
            );
          }
        }

        // Brand name with hyphens (e.g. uniswap-app.com or app-uniswap.com)
        if (cleanHost.contains('$brand-') || cleanHost.contains('-$brand')) {
          return PhishingCheckResult(
            isBlocked: true,
            targetedBrand: brand,
            threatCategory: 'Brand Impersonation',
            reason:
                'Security Alert: This domain ($host) mimics ${brand.toUpperCase()} using a spoofed domain structure.',
          );
        }
      }

      // Levenshtein edit-distance check for typosquatting (e.g. un1swap, openseea, pancakesvvap)
      final hostNameOnly = cleanHost.split('.').first;
      if (hostNameOnly.length >= 4 &&
          (hostNameOnly.length - brand.length).abs() <= 2) {
        final distance = _levenshtein(hostNameOnly, brand);
        if (distance == 1) {
          return PhishingCheckResult(
            isBlocked: true,
            targetedBrand: brand,
            threatCategory: 'Typosquatting Phishing',
            reason:
                'Security Alert: This domain ($host) is a lookalike domain typosquatting on ${brand.toUpperCase()}.',
          );
        }
      }
    }

    return PhishingCheckResult.safe;
  }

  /// Extracts the base root domain without subdomains (e.g. 'sub.uniswap.org' -> 'uniswap.org')
  static String _extractRootDomain(String host) {
    final parts = host.split('.');
    if (parts.length <= 2) return host;
    return parts.sublist(parts.length - 2).join('.');
  }

  /// Checks for Cyrillic and Greek unicode homoglyphs frequently used to spoof Latin letters
  static bool _containsConfusableHomoglyphs(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // Cyrillic range: 0x0400 - 0x04FF
      // Greek range: 0x0370 - 0x03FF
      if ((code >= 0x0400 && code <= 0x04FF) ||
          (code >= 0x0370 && code <= 0x03FF)) {
        return true;
      }
    }
    return false;
  }

  /// Computes Levenshtein edit distance between two strings
  static int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        int minVal = v0[j + 1] + 1;
        if (v1[j] + 1 < minVal) minVal = v1[j] + 1;
        if (v0[j] + cost < minVal) minVal = v0[j] + cost;
        v1[j + 1] = minVal;
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }
}
