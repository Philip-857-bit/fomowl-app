/// A Burst sign-in may prove wallet ownership, but never submit a transaction.
class BurstSignInIdentity {
  const BurstSignInIdentity({
    required this.address,
    required this.networkKey,
    required this.origin,
    required this.profileId,
  });

  final String address;
  final String networkKey;
  final String origin;
  final String profileId;

  bool matches(BurstSignInIdentity other) =>
      address.toLowerCase() == other.address.toLowerCase() &&
      networkKey == other.networkKey &&
      origin == other.origin &&
      profileId == other.profileId;
}

/// Native-only approval for linking a wallet to an existing account. The full
/// account credential never enters this class or the hosted mini app.
class BurstSignInController {
  bool _busy = false;

  Future<Map<String, dynamic>> sign({
    required String miniAppId,
    required Map<String, dynamic> payload,
    required Future<BurstSignInIdentity> Function() readIdentity,
    required Future<bool> Function(String message, String address) confirm,
    required Future<bool> Function() authenticate,
    required Future<String> Function(String address, String message)
    signMessage,
  }) async {
    if (_busy) throw StateError('A Burst sign-in request is already open.');
    if (miniAppId != 'burst') {
      throw const FormatException(
        'Message signing is not enabled for this mini app.',
      );
    }
    _busy = true;
    try {
      final identity = await readIdentity();
      final address = identity.address.trim().toLowerCase();
      if (!RegExp(r'^0x[0-9a-f]{40}$').hasMatch(address) ||
          address == '0x${'0' * 40}' ||
          !RegExp(r'^evm:[1-9][0-9]*$').hasMatch(identity.networkKey)) {
        throw const FormatException(
          'Select an EVM wallet before signing in to Burst.',
        );
      }
      final message = payload['message'];
      final requestedAddress = payload['address'];
      if (message is! String ||
          message.length > 4096 ||
          requestedAddress is! String ||
          requestedAddress.trim().toLowerCase() != address ||
          payload.keys.any((key) => key != 'message' && key != 'address')) {
        throw const FormatException('Invalid Burst sign-in request.');
      }
      final challenge = RegExp(
        r'^Owllet Burst wallet connection\nAccount: ([^\n]+)\nWallet: '
        r'(0x[0-9a-fA-F]{40})\nChallenge: ([0-9a-fA-F-]{36})\n\n'
        r'Link this wallet to your existing Owllet account for Burst\. No transaction or gas fee\.'
        r'\nExpires At: ([^\n]+)$',
      ).firstMatch(message);
      final expiresAt = challenge == null
          ? null
          : DateTime.tryParse(challenge.group(4)!);
      if (challenge == null ||
          (identity.profileId.isNotEmpty &&
              challenge.group(1) != identity.profileId) ||
          challenge.group(2)!.toLowerCase() != address ||
          expiresAt == null) {
        throw const FormatException(
          'Only an Owllet backend sign-in challenge can be signed here.',
        );
      }
      if (!expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
        throw const FormatException('The sign-in challenge has expired.');
      }
      Future<void> requireCurrent() async {
        if (!identity.matches(await readIdentity())) {
          throw StateError(
            'Wallet, network or page changed. Open Burst again.',
          );
        }
      }

      if (!await confirm(message, address)) {
        throw const FormatException('Burst sign-in was cancelled.');
      }
      await requireCurrent();
      if (!await authenticate()) {
        throw const FormatException(
          'Wallet authentication is required to sign in.',
        );
      }
      await requireCurrent();
      final signature = await signMessage(address, message);
      await requireCurrent();
      final normalized = signature.startsWith('0x')
          ? signature
          : '0x$signature';
      if (!RegExp(r'^0x[0-9a-fA-F]{130}$').hasMatch(normalized)) {
        throw const FormatException(
          'The wallet returned an invalid sign-in signature.',
        );
      }
      return <String, dynamic>{
        'ok': true,
        'address': address,
        'signature': normalized,
      };
    } finally {
      _busy = false;
    }
  }
}
