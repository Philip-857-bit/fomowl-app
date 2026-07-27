import 'limit_order_expiry.dart';

/// Ephemeral, UI-independent state for composing a limit order.
class LimitOrderDraft {
  bool isBuyMode = false;
  bool hasManualSideSelection = false;
  LimitExpiryOption expiryOption = LimitExpiryOption.hours24;
  DateTime? customExpiryDate;
  int selectedPriceAdjustment = 0;
  bool isPositiveAdjustment = false;

  bool applySuggestedSide(bool suggestedBuyMode) {
    if (hasManualSideSelection || isBuyMode == suggestedBuyMode) return false;
    isBuyMode = suggestedBuyMode;
    return true;
  }

  bool selectSide(bool buyMode) {
    if (isBuyMode == buyMode && hasManualSideSelection) return false;
    isBuyMode = buyMode;
    hasManualSideSelection = true;
    resetPriceAdjustment();
    return true;
  }

  void selectExpiry(LimitExpiryOption option, {DateTime? customDate}) {
    expiryOption = option;
    customExpiryDate = option == LimitExpiryOption.custom ? customDate : null;
  }

  void toggleAdjustmentDirection() {
    isPositiveAdjustment = !isPositiveAdjustment;
    resetPriceAdjustment();
  }

  void resetPriceAdjustment() {
    selectedPriceAdjustment = 0;
  }
}
