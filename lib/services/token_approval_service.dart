import 'package:web3dart/web3dart.dart';

import '../models/token.dart';
import 'blockchain_service.dart';
import 'swap_service.dart';
import 'wallet_service.dart';
import 'http_client_service.dart';

class TokenApprovalResult {
  final bool approvalSatisfied;
  final bool approvalSubmitted;
  final String? transactionHash;
  final String? error;

  const TokenApprovalResult({
    required this.approvalSatisfied,
    this.approvalSubmitted = false,
    this.transactionHash,
    this.error,
  });

  bool get hasError => error != null;
}

/// Handles ERC20 allowance checks and approval transactions fully on-chain via Web3Dart
class TokenApprovalService {
  final WalletService _walletService;
  final HttpClientService _httpClientService = HttpClientService();

  TokenApprovalService({
    WalletService? walletService,
    SwapService? swapService, // signature compat
  }) : _walletService = walletService ?? WalletService();

  Future<TokenApprovalResult> ensureApproval({
    required Token token,
    required String amountWei,
    required String ownerAddress,
    required BlockchainService blockchain,
    required String allowanceTarget,
  }) async {
    final tokenAddress = token.contractAddress;
    if (tokenAddress == null || tokenAddress.isEmpty) {
      // Native token (ETH/MATIC) doesn't need ERC20 approval
      return const TokenApprovalResult(approvalSatisfied: true);
    }

    if (allowanceTarget.isEmpty) {
      return const TokenApprovalResult(
        approvalSatisfied: false,
        error: 'Missing allowance target from DEX provider',
      );
    }

    final client = Web3Client(
      blockchain.activeChain.rpcUrl,
      _httpClientService.client,
    );
    try {
      final spenderAddr = EthereumAddress.fromHex(allowanceTarget);
      final tokenAddr = EthereumAddress.fromHex(tokenAddress);
      final ownerAddr = EthereumAddress.fromHex(ownerAddress);

      final requiredAmount = BigInt.tryParse(amountWei) ?? BigInt.zero;
      if (requiredAmount <= BigInt.zero) {
        return const TokenApprovalResult(
          approvalSatisfied: false,
          error: 'Invalid token amount',
        );
      }

      final abi = ContractAbi.fromJson('''[
        {
          "constant": true,
          "inputs": [
            {"name": "owner", "type": "address"},
            {"name": "spender", "type": "address"}
          ],
          "name": "allowance",
          "outputs": [{"name": "", "type": "uint256"}],
          "type": "function"
        },
        {
          "constant": false,
          "inputs": [
            {"name": "spender", "type": "address"},
            {"name": "amount", "type": "uint256"}
          ],
          "name": "approve",
          "outputs": [{"name": "", "type": "bool"}],
          "type": "function"
        }
      ]''', 'ERC20');

      final contract = DeployedContract(abi, tokenAddr);
      final allowanceFunc = contract.function('allowance');
      final approveFunc = contract.function('approve');

      final allowanceRes = await client.call(
        contract: contract,
        function: allowanceFunc,
        params: [ownerAddr, spenderAddr],
      );

      final currentAllowance = allowanceRes.first as BigInt;

      if (currentAllowance >= requiredAmount) {
        return const TokenApprovalResult(approvalSatisfied: true);
      }

      // 3. Needs additional approval
      final credentials = await _walletService.getCredentials();

      final tx = Transaction.callContract(
        contract: contract,
        function: approveFunc,
        parameters: [spenderAddr, BigInt.two.pow(256) - BigInt.one],
      );

      final txHash = await client.sendTransaction(
        credentials,
        tx,
        chainId: blockchain.activeChain.chainId,
        fetchChainIdFromNetworkId: false,
      );

      return TokenApprovalResult(
        approvalSatisfied: true,
        approvalSubmitted: true,
        transactionHash: txHash,
      );
    } catch (e) {
      return TokenApprovalResult(approvalSatisfied: false, error: e.toString());
    } finally {
      // client.dispose() intentionally removed — HttpClient is a shared singleton.
    }
  }
}
