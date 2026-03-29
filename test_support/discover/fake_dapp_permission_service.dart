import 'package:fomowl_wallet/features/discover/permissions/dapp_permission_service.dart';

class FakeDappPermissionService extends DappPermissionService {
  final Set<String> _approvals = <String>{};

  String _key(String origin, String walletAddress) =>
      '${origin.trim().toLowerCase()}|${walletAddress.trim().toLowerCase()}';

  @override
  Future<bool> hasConnectionApproval(
    String origin,
    String walletAddress,
  ) async {
    return _approvals.contains(_key(origin, walletAddress));
  }

  @override
  Future<void> grantConnectionApproval(
    String origin,
    String walletAddress,
  ) async {
    _approvals.add(_key(origin, walletAddress));
  }

  @override
  Future<void> revokeConnectionApproval(
    String origin,
    String walletAddress,
  ) async {
    _approvals.remove(_key(origin, walletAddress));
  }
}
