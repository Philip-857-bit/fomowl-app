// RPC resilience primitives extracted from `BlockchainService`:
// a per-endpoint circuit breaker and a lightweight performance-metrics
// collector. Kept self-contained so the service composes them rather than
// owning their state inline.

/// Per-endpoint circuit breaker with exponential backoff.
class CircuitBreakerState {
  int failureCount = 0;
  DateTime? lastFailureTime;
  Duration currentBackoff;
  final int failureThreshold;

  CircuitBreakerState({
    this.currentBackoff = const Duration(seconds: 30),
    this.failureThreshold = 3,
  });

  bool isOpen() {
    if (lastFailureTime == null) return false;
    final elapsed = DateTime.now().difference(lastFailureTime!);
    if (elapsed >= currentBackoff) {
      return false;
    }
    return failureCount >= failureThreshold;
  }

  void recordFailure(Duration maxBackoff) {
    failureCount++;
    lastFailureTime = DateTime.now();
    currentBackoff = Duration(
      seconds: (currentBackoff.inSeconds * 2)
          .clamp(30, maxBackoff.inSeconds)
          .toInt(),
    );
  }

  void reset(Duration initialBackoff) {
    failureCount = 0;
    lastFailureTime = null;
    currentBackoff = initialBackoff;
  }
}

/// Aggregated performance counters for discovery/price-refresh paths.
class PerformanceMetrics {
  int totalDiscoveryCalls = 0;
  int successfulDiscoveryCalls = 0;
  int failedDiscoveryCalls = 0;
  final List<Duration> priceRefreshLatencies = [];
  int priceRefreshCount = 0;
  int tokenMismatchCount = 0;
  int registryFallbackCount = 0;
  final Map<String, int> endpointFailureCount = {};

  double get discoverySuccessRate => totalDiscoveryCalls == 0
      ? 0.0
      : (successfulDiscoveryCalls / totalDiscoveryCalls) * 100;

  Duration get avgPriceRefreshLatency {
    if (priceRefreshLatencies.isEmpty) return Duration.zero;
    final total = priceRefreshLatencies.fold<Duration>(
      Duration.zero,
      (sum, d) => sum + d,
    );
    return total ~/ priceRefreshLatencies.length;
  }

  void recordDiscoveryCall({
    required bool success,
    required bool usedFallback,
  }) {
    totalDiscoveryCalls++;
    if (success) {
      successfulDiscoveryCalls++;
    } else {
      failedDiscoveryCalls++;
    }
    if (usedFallback) {
      registryFallbackCount++;
    }
  }

  void recordPriceRefresh({required Duration latency}) {
    priceRefreshCount++;
    if (priceRefreshLatencies.length >= 100) {
      priceRefreshLatencies.removeAt(0);
    }
    priceRefreshLatencies.add(latency);
  }

  void recordTokenMismatch() {
    tokenMismatchCount++;
  }

  void recordEndpointFailure(String endpoint) {
    endpointFailureCount[endpoint] = (endpointFailureCount[endpoint] ?? 0) + 1;
  }

  Map<String, dynamic> toJson() => {
    'totalDiscoveryCalls': totalDiscoveryCalls,
    'successfulDiscoveryCalls': successfulDiscoveryCalls,
    'failedDiscoveryCalls': failedDiscoveryCalls,
    'discoverySuccessRate': '${discoverySuccessRate.toStringAsFixed(1)}%',
    'priceRefreshCount': priceRefreshCount,
    'avgPriceRefreshLatencyMs': avgPriceRefreshLatency.inMilliseconds,
    'tokenMismatchCount': tokenMismatchCount,
    'registryFallbackCount': registryFallbackCount,
    'endpointFailures': endpointFailureCount,
  };
}
