import '../../../services/bridge_service.dart';
import '../../../services/solana_swap_service.dart';
import '../../../services/swap_service.dart';
import '../../../services/tron_swap_service.dart';

/// Provider-neutral quote lifecycle state.
class SwapQuoteState {
  int requestId = 0;
  bool isCalculating = false;
  String pricing = '';
  String? statusMessage;
  double feeUsd = 0;
  double feeNative = 0;
  double platformFeeUsd = 0;
  SwapQuote? evmQuote;
  BridgeQuote? relayQuote;
  SolanaSwapQuote? solanaQuote;
  TronSwapQuote? tronQuote;
  bool isApproving = false;
  bool isSwapping = false;
  bool isFlowActive = false;

  int beginRequest() => ++requestId;

  void reset({bool preserveRequestId = false, bool clearStatusMessage = true}) {
    if (!preserveRequestId) requestId++;
    pricing = '';
    if (clearStatusMessage) statusMessage = null;
    evmQuote = null;
    relayQuote = null;
    solanaQuote = null;
    tronQuote = null;
    feeUsd = 0;
    feeNative = 0;
    platformFeeUsd = 0;
  }
}
