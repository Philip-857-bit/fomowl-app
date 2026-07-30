/// Tracks network state transitions that require a fresh wallet sync.
class ConnectivityRecovery {
  bool? _lastOnline;
  bool _refreshInFlight = false;
  bool _retryPending = false;

  bool get hasPendingRetry => _retryPending;

  bool shouldRefresh(bool online) {
    final recovered = _lastOnline == false && online;
    _lastOnline = online;
    if (!online) {
      _retryPending = false;
      return false;
    }
    if ((!recovered && !_retryPending) || _refreshInFlight) return false;
    _refreshInFlight = true;
    _retryPending = false;
    return true;
  }

  void finishRefresh({required bool succeeded}) {
    _refreshInFlight = false;
    _retryPending = !succeeded;
  }
}
