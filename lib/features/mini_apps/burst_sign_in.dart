/// A Burst sign-in may prove wallet ownership, but never submit a transaction.
class BurstSignInIdentity {
  const BurstSignInIdentity({
    required this.address,
    required this.networkKey,
    required this.origin,
  });

  final String address;
  final String networkKey;
  final String origin;

  bool matches(BurstSignInIdentity other) =>
      address.toLowerCase() == other.address.toLowerCase() &&
      networkKey == other.networkKey &&
      origin == other.origin;
}

/// Restricts signing to the existing backend's profile authentication challenge.
/// The backend still verifies and consumes its own nonce before issuing a JWT.
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
        r'^fomowl\.app wants you to sign in with your Ethereum account:\n'
        r'(0x[0-9a-fA-F]{40})\n\n'
        r'Sign in to OwlletPay\. This request will not trigger a blockchain transaction '
        r'or cost any gas fees\.\n\nNonce: ([0-9a-fA-F]{64})\nIssued At: ([^\n]+)$',
      ).firstMatch(message);
      if (challenge == null ||
          challenge.group(1)!.toLowerCase() != address ||
          DateTime.tryParse(challenge.group(3)!) == null) {
        throw const FormatException(
          'Only an Owllet backend sign-in challenge can be signed here.',
        );
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
