import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';

import '../models/token.dart';
import 'blockchain_service.dart';
import 'rpc_service.dart';
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
  final RpcService _rpcService = RpcService();
  static final ContractAbi _erc20ApprovalAbi = ContractAbi.fromJson('''[
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

  TokenApprovalService({
    WalletService? walletService,
    SwapService? swapService, // signature compat
  }) : _walletService = walletService ?? WalletService();

  Future<String> _resolveRpcUrl(BlockchainService blockchain) {
    return _rpcService
        .resolveWorkingRpcUrl(
          chainId: blockchain.activeChain.chainId,
          primaryRpcUrl: blockchain.activeChain.rpcUrl,
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            // Fallback to primary URL if resolution times out.
            return blockchain.activeChain.rpcUrl;
          },
        );
  }

  Future<BigInt?> estimateApprovalFeeWei({
    required Token token,
    required String ownerAddress,
    required BlockchainService blockchain,
    required String allowanceTarget,
  }) async {
    final tokenAddress = token.contractAddress;
    if (tokenAddress == null ||
        tokenAddress.isEmpty ||
        allowanceTarget.isEmpty) {
      return BigInt.zero;
    }

    final rpcUrl = await _resolveRpcUrl(blockchain);
    final client = Web3Client(rpcUrl, _httpClientService.client);
    try {
      final spenderAddr = EthereumAddress.fromHex(allowanceTarget);
      final tokenAddr = EthereumAddress.fromHex(tokenAddress);
      final ownerAddr = EthereumAddress.fromHex(ownerAddress);
      final contract = DeployedContract(_erc20ApprovalAbi, tokenAddr);
      final approveFunc = contract.function('approve');
      final approvalAmount = BigInt.two.pow(256) - BigInt.one;
      final approvalData = approveFunc.encodeCall([
        spenderAddr,
        approvalAmount,
      ]);
      final gasPrice = await client.getGasPrice().timeout(
        const Duration(seconds: 10),
      );
      final estimatedGas = await client
          .estimateGas(sender: ownerAddr, to: tokenAddr, data: approvalData)
          .timeout(const Duration(seconds: 10));
      final bufferedGas = BigInt.from((estimatedGas.toInt() * 1.1).ceil());
      return gasPrice.getInWei * bufferedGas;
    } catch (_) {
      return null;
    } finally {
      // client.dispose() intentionally removed — HttpClient is a shared singleton.
    }
  }

  /// Ensures the required ERC-20 allowance is in place, sending an approval
  /// transaction if necessary.
  ///
  /// [onApprovalNeeded] is called just before an approval transaction is
  /// broadcast. This lets the caller transition the UI to "approval pending"
  /// only when a tx is actually required (not when the allowance is already
  /// sufficient). This avoids the UX issue where users see "Approval Processing"
  /// even though they already have sufficient allowance.
  Future<TokenApprovalResult> ensureApproval({
    required Token token,
    required String amountWei,
    required String ownerAddress,
    required BlockchainService blockchain,
    required String allowanceTarget,
    VoidCallback? onApprovalNeeded,
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

    final rpcUrl = await _resolveRpcUrl(blockchain);
    final client = Web3Client(rpcUrl, _httpClientService.client);
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

      final contract = DeployedContract(_erc20ApprovalAbi, tokenAddr);
      final allowanceFunc = contract.function('allowance');
      final approveFunc = contract.function('approve');

      // Check current allowance with a tight timeout to prevent hangs on
      // slow/unreliable RPC nodes.
      final allowanceRes = await client
          .call(
            contract: contract,
            function: allowanceFunc,
            params: [ownerAddr, spenderAddr],
          )
          .timeout(const Duration(seconds: 10));

      final currentAllowance = allowanceRes.first as BigInt;

      if (currentAllowance >= requiredAmount) {
        return const TokenApprovalResult(approvalSatisfied: true);
      }

      // 3. Needs additional approval — notify caller so UI can transition.
      onApprovalNeeded?.call();

      final privateKeyHex = await _walletService.getPrivateKey(ownerAddress);
      if (privateKeyHex == null) {
        return const TokenApprovalResult(
          approvalSatisfied: false,
          error: 'No wallet found for token approval',
        );
      }
      final credentials = EthPrivateKey.fromHex(
        privateKeyHex.startsWith('0x')
            ? privateKeyHex.substring(2)
            : privateKeyHex,
      );
      if (credentials.address.hex.toLowerCase() !=
          ownerAddr.hex.toLowerCase()) {
        return const TokenApprovalResult(
          approvalSatisfied: false,
          error: 'Token approval wallet does not match the selected wallet',
        );
      }

      // Approve only the exact amount this swap needs, never the unlimited
      // 2^256-1. The spender comes from the backend quote; bounding the
      // allowance means a tampered/compromised spender can move at most this
      // one swap's amount, not drain the entire balance forever.
      final tx = Transaction.callContract(
        contract: contract,
        function: approveFunc,
        parameters: [spenderAddr, requiredAmount],
      );

      // Timeout for the actual approval transaction broadcast — prevents
      // indefinite hang when the RPC node accepts the request but is slow
      // to respond.
      final txHash = await client
          .sendTransaction(
            credentials,
            tx,
            chainId: blockchain.activeChain.chainId,
            fetchChainIdFromNetworkId: false,
          )
          .timeout(const Duration(seconds: 30));

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
