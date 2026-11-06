import 'dart:convert';

import 'package:http/http.dart' as http;

/// Validates the native account token and restores profile identity without
/// persisting a session that the user chose not to remember.
class BurstAccountVerifier {
  const BurstAccountVerifier({
    required this.readToken,
    required this.logout,
    required this.signIn,
    required this.fetchProfile,
    required this.readCachedProfile,
    required this.saveTransientProfile,
  });
  final Future<String?> Function() readToken;
  final Future<void> Function() logout;
  final Future<bool> Function() signIn;
  final Future<http.Response> Function(String token) fetchProfile;
  final Future<Map<String, dynamic>?> Function() readCachedProfile;
  final Future<void> Function(Map<String, dynamic>) saveTransientProfile;

  Future<void> ensureAccount() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      var token = await readToken();
      if (token == null || token.isEmpty) {
        if (!await signIn()) {
          throw StateError('Sign in to your Owllet account to use Burst.');
        }
        token = await readToken();
      }
      if (token == null || token.isEmpty) break;
      final response = await fetchProfile(token);
      if (await readToken() != token) {
        throw StateError('Your Owllet account changed. Open Burst again.');
      }
      if (response.statusCode == 401) {
        await logout();
        continue;
      }
      if (response.statusCode != 200) {
        throw StateError(
          'Your Owllet account could not be verified. Try again.',
        );
      }
      final decoded = jsonDecode(response.body);
      final profile = decoded is Map ? (decoded['data'] ?? decoded) : null;
      if (profile is! Map<String, dynamic> ||
          profile['id'] is! String ||
          (profile['id'] as String).isEmpty) {
        throw StateError('Your Owllet account could not be verified.');
      }
      final cached = await readCachedProfile();
      if (await readToken() != token) {
        throw StateError('Your Owllet account changed. Open Burst again.');
      }
      if (cached?['id'] != profile['id']) await saveTransientProfile(profile);
      return;
    }
    throw StateError('Sign in to your Owllet account again.');
  }
}
