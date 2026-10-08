import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';

import '../models/token.dart';
import 'blockchain_service.dart';
import 'swap_service.dart';
import 'wallet_service.dart';
import 'http_client_service.dart';
import 'evm_transaction_service.dart';

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

/// Handles on-chain allowance checks and Rust-signed ERC-20 approvals.
class TokenApprovalService {
  final WalletService _walletService;
  final Web3Client Function(String rpcUrl)? _web3ClientFactory;
  final HttpClientService _httpClientService = HttpClientService();
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
    Web3Client Function(String rpcUrl)? web3ClientFactory,
  }) : _walletService = walletService ?? WalletService(),
       _web3ClientFactory = web3ClientFactory;

  Web3Client _clientForRpc(String rpcUrl) =>
      _web3ClientFactory?.call(rpcUrl) ??
      Web3Client(rpcUrl, _httpClientService.client);

  /// Live estimate of the native gas cost of a swap on the active EVM chain,
  /// in wei, used to size the MAX-swap gas buffer so it reflects ACTUAL current
  /// gas (cheap when the network is quiet) instead of a flat over-reservation.
  /// [swapGasUnits] approximates a DEX swap's gas; a 1.3x safety margin is
  /// applied. Returns null on any RPC failure so the caller can fall back.
  Future<BigInt?> estimateNativeSwapGasWei({
    required BlockchainService blockchain,
    int swapGasUnits = 250000,
  }) async {
    final client = _clientForRpc(blockchain.activeChain.rpcUrl);
    try {
      final gasPrice = await client.getGasPrice().timeout(
        const Duration(seconds: 8),
      );
      final units = BigInt.from((swapGasUnits * 1.3).ceil());
      return gasPrice.getInWei * units;
    } catch (_) {
      return null;
    }
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

    final client = _clientForRpc(blockchain.activeChain.rpcUrl);
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

    final client = _clientForRpc(blockchain.activeChain.rpcUrl);
    EvmSigningAccount? signingAccount;
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

      signingAccount = await _walletService.getEvmSigningAccountForAddress(
        ownerAddress,
        mismatchMessage:
            'Token approval wallet does not match the selected wallet',
      );
      final account = signingAccount;

      // Approve only the exact amount this swap needs, never the unlimited
      // 2^256-1. The spender comes from the backend quote; bounding the
      // allowance means a tampered/compromised spender can move at most this
      // one swap's amount, not drain the entire balance forever.
      final data = approveFunc.encodeCall([spenderAddr, requiredAmount]);

      // Timeout for the actual approval transaction broadcast — prevents
      // indefinite hang when the RPC node accepts the request but is slow
      // to respond.
      // Keep the previous 30-second deadline around fee/nonce resolution,
      // estimation, signing, and broadcast as one operation.
      final txHash = await (() async {
        final gasPrice = await client.getGasPrice();
        final nonce = await client.getTransactionCount(
          ownerAddr,
          atBlock: const BlockNum.pending(),
        );
        final gasLimit = await client.estimateGas(
          sender: ownerAddr,
          to: tokenAddr,
          data: data,
          gasPrice: gasPrice,
        );
        return EvmTransactionService.broadcastLegacy(
          client: client,
          account: account,
          chainId: blockchain.activeChain.chainId,
          to: tokenAddr,
          valueWei: BigInt.zero,
          gasPriceWei: gasPrice.getInWei,
          gasLimit: gasLimit.toInt(),
          data: data,
          nonce: nonce,
        );
      })().timeout(const Duration(seconds: 30));

      return TokenApprovalResult(
        approvalSatisfied: true,
        approvalSubmitted: true,
        transactionHash: txHash,
      );
    } catch (e) {
      return TokenApprovalResult(approvalSatisfied: false, error: e.toString());
    } finally {
      await signingAccount?.close();
      // client.dispose() intentionally removed — HttpClient is a shared singleton.
    }
  }
}
