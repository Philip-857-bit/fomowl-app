import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/chain.dart';
import '../../services/blockchain_service.dart';
import '../../services/nft_service.dart';
import '../../services/transaction_monitor.dart';
import '../../services/wallet_service.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/entrance_motion.dart';
import '../transaction/transaction_processing_screen.dart';
import 'widgets/send/address_input_field.dart';
import 'widgets/send/send_header.dart';
import 'widgets/send/send_primary_button.dart';

class SendNftScreen extends StatefulWidget {
  const SendNftScreen({super.key});

  @override
  State<SendNftScreen> createState() => _SendNftScreenState();
}

class _SendNftScreenState extends State<SendNftScreen> {
  final TextEditingController _addressController = TextEditingController();
  final WalletService _walletService = WalletService();
  final TransactionMonitor _transactionMonitor = TransactionMonitor();

  NftAsset? _nft;
  String? _fromAddress;
  bool _isLoadingFee = true;
  bool _feeFailed = false;
  bool _isSubmitting = false;
  int _amount = 1;
  double _gasPriceGwei = 0;
  double _gasFeeNative = 0;
  double _gasFeeUsd = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nft != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is NftAsset) {
      _nft = args;
      unawaited(_loadFromAddressAndFee());
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  EvmChain? _chainForNft(BlockchainService blockchain, NftAsset nft) {
    if (nft.chainId > 0) {
      for (final chain in blockchain.allChains) {
        if (chain.chainId == nft.chainId) return chain;
      }
    }
    final nftChainName = nft.chainName.trim().toLowerCase();
    for (final chain in blockchain.allChains) {
      if (chain.name.trim().toLowerCase() == nftChainName) return chain;
    }
    return null;
  }

  Future<void> _loadFromAddressAndFee() async {
    final family = _nft?.isSolana == true
        ? ChainFamily.solana
        : ChainFamily.evm;
    final address = await _walletService.getWalletAddressForFamily(family);
    if (!mounted) return;
    setState(() {
      _fromAddress = address;
      if (_nft?.isCompressed == true) {
        _gasFeeNative = 0.000005;
        _gasPriceGwei = 0;
        _isLoadingFee = false;
        _feeFailed = false;
      }
    });
    if (_nft?.isCompressed == true) return;
    await _estimateFee();
  }

  Future<void> _estimateFee() async {
    final nft = _nft;
    final fromAddress = _fromAddress;
    if (nft == null || fromAddress == null || fromAddress.isEmpty) {
      if (mounted) setState(() => _isLoadingFee = false);
      return;
    }
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final chain = _chainForNft(blockchain, nft);
    final toAddress = _addressController.text.trim();
    if (chain == null ||
        nft.contractAddress.trim().isEmpty ||
        nft.tokenId.trim().isEmpty ||
        !_isValidEvmAddress(toAddress)) {
      if (mounted) {
        setState(() {
          _isLoadingFee = false;
          _feeFailed = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingFee = true;
      _feeFailed = false;
    });

    try {
      double nativePrice = 0;
      final coinId = chain.coinGeckoId;
      if (coinId != null && coinId.isNotEmpty) {
        final prices = await blockchain.getTokenPrices([coinId]);
        nativePrice = prices[coinId] ?? 0;
      }
      final fee = await _walletService.estimateNftTransferFee(
        fromAddress: fromAddress,
        toAddress: toAddress,
        contractAddress: nft.contractAddress,
        tokenId: BigInt.parse(nft.tokenId),
        tokenType: nft.tokenType,
        amount: BigInt.from(_amount),
        rpcUrl: chain.rpcUrl,
        nativePriceUsd: nativePrice,
      );
      if (!mounted) return;
      setState(() {
        _gasPriceGwei = fee['gasGwei'] ?? 0;
        _gasFeeNative = fee['totalFeeEth'] ?? 0;
        _gasFeeUsd = fee['totalFeeUsd'] ?? 0;
        _isLoadingFee = false;
        _feeFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingFee = false;
        _feeFailed = true;
      });
    }
  }

  bool _isValidEvmAddress(String address) {
    return RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address);
  }

  String _shortAddress(String? address) {
    if (address == null || address.length < 10) return address ?? '--';
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _shortHash(String hash) {
    if (hash.length <= 10) return hash;
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
  }

  String _formatGwei(double value) {
    if (value >= 10) return value.toStringAsFixed(1);
    if (value >= 1) return value.toStringAsFixed(2);
    return value.toStringAsFixed(4);
  }

  String _formatNative(double value, String symbol) {
    final formatted = value
        .toStringAsFixed(value >= 0.0001 ? 8 : 10)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$formatted $symbol';
  }

  String? _transactionDetailsUrl(String hash, EvmChain chain) {
    if (!RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(hash)) return null;
    final explorerUrl = chain.explorerUrl?.trim();
    if (explorerUrl == null || explorerUrl.isEmpty) return null;
    final normalized = explorerUrl.endsWith('/')
        ? explorerUrl.substring(0, explorerUrl.length - 1)
        : explorerUrl;
    return '$normalized/tx/$hash';
  }

  TransactionProgressController _openProgressFlow() {
    final controller = TransactionProgressController(
      flow: TransactionProgressFlow.transfer,
    );
    unawaited(
      Navigator.of(context)
          .pushNamed(
            '/transaction-processing',
            arguments: TransactionProcessingArguments(
              controller: controller,
              terminalRouteName: '/shell',
              clearStackOnTerminalRoute: true,
            ),
          )
          .whenComplete(controller.dispose),
    );
    return controller;
  }

  Future<void> _sendNft() async {
    if (_isSubmitting) return;
    final nft = _nft;
    if (nft == null) {
      ToastUtils.showError('NFT details are missing.');
      return;
    }
    final toAddress = _addressController.text.trim();
    final isCompressedSolana = nft.isSolana && nft.isCompressed;
    final validRecipient = isCompressedSolana
        ? RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(toAddress)
        : _isValidEvmAddress(toAddress);
    if (!validRecipient) {
      ToastUtils.showError(
        isCompressedSolana
            ? 'Enter a valid Solana address.'
            : 'Enter a valid Ethereum address.',
      );
      return;
    }
    if ((!isCompressedSolana && nft.contractAddress.trim().isEmpty) ||
        nft.tokenId.trim().isEmpty) {
      ToastUtils.showError('This NFT is missing transfer metadata.');
      return;
    }
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final chain = isCompressedSolana ? null : _chainForNft(blockchain, nft);
    if (!isCompressedSolana && chain == null) {
      ToastUtils.showError('This NFT network is not available in the wallet.');
      return;
    }
    final fromAddress =
        _fromAddress ??
        await _walletService.getWalletAddressForFamily(
          isCompressedSolana ? ChainFamily.solana : ChainFamily.evm,
        );
    if (fromAddress == null || fromAddress.isEmpty) {
      ToastUtils.showError(
        isCompressedSolana
            ? 'No Solana wallet address found.'
            : 'No EVM wallet address found.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final progressController = _openProgressFlow();
    progressController.setPreparing();

    try {
      progressController.setSwapSubmitting();
      final txHash = isCompressedSolana
          ? await _walletService.sendCompressedNft(
              assetId: nft.tokenId,
              fromAddress: fromAddress,
              toAddress: toAddress,
            )
          : await _walletService.sendNftTransaction(
              contractAddress: nft.contractAddress,
              fromAddress: fromAddress,
              toAddress: toAddress,
              tokenId: BigInt.parse(nft.tokenId),
              tokenType: nft.tokenType,
              amount: BigInt.from(_amount),
              rpcUrl: chain!.rpcUrl,
              chainId: chain.chainId,
            );
      final detailsUrl = isCompressedSolana
          ? 'https://explorer.solana.com/tx/$txHash'
          : _transactionDetailsUrl(txHash, chain!);
      progressController.setSwapPending(
        reference: _shortHash(txHash),
        detailsUrl: detailsUrl,
      );
      final confirmed = await _transactionMonitor.waitForConfirmation(
        txHash: txHash,
        blockchain: blockchain,
        networkKey: isCompressedSolana
            ? NetworkKey.solana('mainnet')
            : NetworkKey.evm(chain!.chainId),
        evmChain: chain,
      );
      if (!mounted) return;
      if (confirmed) {
        progressController.setSuccess(
          reference: _shortHash(txHash),
          detailsUrl: detailsUrl,
        );
        unawaited(
          blockchain.refreshWalletTokens(
            fromAddress,
            chainId: isCompressedSolana ? null : chain!.chainId,
          ),
        );
      } else {
        progressController.setError(
          'The transfer was submitted but is still waiting for confirmation.',
          reference: _shortHash(txHash),
          detailsUrl: detailsUrl,
        );
      }
    } catch (e) {
      if (mounted) {
        progressController.setError(
          AppErrorUtils.userMessage(e, fallback: 'NFT transfer failed.'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nft = _nft;
    final blockchain = Provider.of<BlockchainService>(context);
    final chain = nft == null ? null : _chainForNft(blockchain, nft);
    final canChooseAmount = nft != null && nft.count > 1;
    final feeText = _isLoadingFee
        ? 'Estimating...'
        : _feeFailed
        ? 'Estimation failed'
        : nft?.isCompressed == true
        ? '≈ ${_formatNative(_gasFeeNative, 'SOL')}'
        : _gasFeeNative > 0 && chain != null
        ? '${_formatNative(_gasFeeNative, chain.symbol)} (${_formatGwei(_gasPriceGwei)} Gwei)'
        : 'Enter recipient to estimate';
    final feeUsdText = _gasFeeUsd > 0
        ? '\$${_gasFeeUsd.toStringAsFixed(2)}'
        : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SendHeader(title: 'Send NFT', onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (nft == null)
                      _StateMessage(
                        icon: Icons.error_outline,
                        title: 'NFT details missing',
                        message: 'Go back and select an NFT again.',
                      )
                    else ...[
                      EntranceMotion(child: _NftTransferPreview(nft: nft)),
                      const SizedBox(height: 24),
                      AddressInputField(
                        controller: _addressController,
                        isInterTransfer: false,
                        onQrTap: () =>
                            Navigator.pushNamed(context, '/qr-scanner'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _estimateFee,
                        icon: const Icon(Icons.speed_rounded, size: 18),
                        label: const Text('Estimate fee'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accentRed,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (canChooseAmount) ...[
                        _AmountSelector(
                          amount: _amount,
                          maxAmount: nft.count,
                          onChanged: (value) {
                            setState(() => _amount = value);
                            unawaited(_estimateFee());
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      _DetailsPanel(
                        rows: [
                          _DetailRow('From', _shortAddress(_fromAddress)),
                          _DetailRow('Network', chain?.name ?? nft.chainName),
                          _DetailRow('Standard', nft.tokenType),
                          _DetailRow('Quantity', _amount.toString()),
                          _DetailRow('Token ID', '#${nft.tokenId}'),
                          _DetailRow('Network fee', feeText, feeUsdText),
                        ],
                      ),
                      if (chain == null) ...[
                        const SizedBox(height: 16),
                        const _StateMessage(
                          icon: Icons.info_outline,
                          title: 'Unsupported network',
                          message:
                              'This NFT belongs to a network that is not configured in the wallet.',
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: IgnorePointer(
                ignoring: _isSubmitting || nft == null || chain == null,
                child: Opacity(
                  opacity: _isSubmitting || nft == null || chain == null
                      ? 0.5
                      : 1,
                  child: SendPrimaryButton(onPressed: _sendNft),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NftTransferPreview extends StatelessWidget {
  const _NftTransferPreview({required this.nft});

  final NftAsset nft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 88,
              height: 88,
              child: nft.imageUrl.isNotEmpty
                  ? Image.network(
                      nft.imageUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 256,
                      cacheHeight: 256,
                      errorBuilder: (_, _, _) => const _NftImageFallback(),
                    )
                  : const _NftImageFallback(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nft.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nft.collection,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${nft.count}x on ${nft.chainName}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NftImageFallback extends StatelessWidget {
  const _NftImageFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04)),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textSecondary.withValues(alpha: 0.42),
          size: 32,
        ),
      ),
    );
  }
}

class _AmountSelector extends StatelessWidget {
  const _AmountSelector({
    required this.amount,
    required this.maxAmount,
    required this.onChanged,
  });

  final int amount;
  final int maxAmount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quantity',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Available: $maxAmount',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.52),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: amount > 1 ? () => onChanged(amount - 1) : null,
            icon: const Icon(Icons.remove_rounded),
            color: Colors.white,
            disabledColor: Colors.white24,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$amount',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: amount < maxAmount ? () => onChanged(amount + 1) : null,
            icon: const Icon(Icons.add_rounded),
            color: Colors.white,
            disabledColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.rows});

  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0)
              Divider(color: Colors.white.withValues(alpha: 0.06), height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    rows[index].label,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.48),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        rows[index].value,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (rows[index].subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          rows[index].subtitle,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value, [this.subtitle = '']);

  final String label;
  final String value;
  final String subtitle;
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
