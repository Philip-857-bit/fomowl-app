/// Client-side validation for user-supplied custom-network RPC URLs.
///
/// Mirrors the backend SSRF host guard (`is_blocked_rpc_host` in
/// `settings.rs`) so the app rejects private/internal/malformed endpoints up
/// front with a clear message, instead of saving a network that the backend
/// will later refuse to use. The backend remains the authoritative guard.
library;

import 'dart:io';

/// Whether [host] points at a loopback / private / link-local / internal
/// address that must not be used as a public RPC endpoint. Hostnames that are
/// not IP literals (real DNS names) are allowed here and resolved later.
bool isBlockedRpcHost(String host) {
  final normalized = host.trim().replaceAll(RegExp(r'^\[|\]$'), '');
  if (normalized.isEmpty) return true;
  final lower = normalized.toLowerCase();

  if (lower == 'localhost' ||
      lower.endsWith('.localhost') ||
      lower.endsWith('.local') ||
      lower.endsWith('.internal')) {
    return true;
  }

  final addr = InternetAddress.tryParse(normalized);
  if (addr == null) {
    // Not an IP literal — treat as a DNS hostname (allowed; backend re-checks).
    return false;
  }

  final bytes = addr.rawAddress;
  if (addr.type == InternetAddressType.IPv4) {
    return _isBlockedV4(bytes);
  }

  // IPv6
  if (addr.isLoopback) return true; // ::1
  if (bytes.every((b) => b == 0)) return true; // ::
  if ((bytes[0] & 0xfe) == 0xfc) return true; // ULA fc00::/7
  if (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) return true; // fe80::/10
  // IPv4-mapped ::ffff:a.b.c.d
  final isMapped =
      bytes.length == 16 &&
      bytes.sublist(0, 10).every((b) => b == 0) &&
      bytes[10] == 0xff &&
      bytes[11] == 0xff;
  if (isMapped) {
    return _isBlockedV4(bytes.sublist(12));
  }
  return false;
}

bool _isBlockedV4(List<int> o) {
  if (o.length != 4) return true;
  if (o[0] == 127) return true; // loopback 127.0.0.0/8
  if (o[0] == 10) return true; // private 10.0.0.0/8
  if (o[0] == 172 && (o[1] & 0xf0) == 16) return true; // 172.16.0.0/12
  if (o[0] == 192 && o[1] == 168) return true; // 192.168.0.0/16
  if (o[0] == 169 && o[1] == 254) return true; // link-local 169.254.0.0/16
  if (o[0] == 100 && (o[1] & 0xc0) == 64) return true; // CGNAT 100.64.0.0/10
  if (o[0] == 0) return true; // 0.0.0.0/8
  if (o.every((b) => b == 255)) return true; // broadcast
  return false;
}

/// Validate a custom-network RPC URL. Returns an error message to display, or
/// `null` when the URL is acceptable (https, well-formed, public host).
String? validateCustomRpcUrl(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) {
    return 'RPC URL is required.';
  }
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'Enter a valid RPC URL.';
  }
  if (uri.scheme.toLowerCase() != 'https') {
    return 'RPC URL must use https://.';
  }
  if (isBlockedRpcHost(uri.host)) {
    return 'RPC host is not allowed (private or local address).';
  }
  return null;
}
