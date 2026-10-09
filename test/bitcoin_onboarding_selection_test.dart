import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/screens/onboarding/blockchain_selection_screen.dart';
import 'package:fomowl_wallet/services/blockchain_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';

class SelectionWallet extends Fake implements WalletService {
  final WalletOrigin origin;
  SelectionWallet(this.origin);
  @override
  Future<String?> getCurrentWalletAddress() async => '0xwallet';
  @override
  Future<List<WalletAccount>> getWalletAccounts() async => [
    WalletAccount(
      address: '0xwallet',
      name: 'Fixture',
      origin: origin,
      createdAt: DateTime.utc(2026),
    ),
  ];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  Future<void> show(
    WidgetTester tester,
    WalletOrigin origin,
    bool available,
  ) async {
    final blockchain = BlockchainService()
      ..configureBitcoinAvailability(available: available);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: blockchain,
        child: MaterialApp(
          home: BlockchainSelectionScreen(
            walletService: SelectionWallet(origin),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'seed-backed onboarding exposes Bitcoin when rollout is available',
    (tester) async {
      await show(tester, WalletOrigin.derived, true);
      expect(find.text('Bitcoin'), findsOneWidget);
    },
  );
  testWidgets('private-key imports do not advertise Bitcoin capability', (
    tester,
  ) async {
    await show(tester, WalletOrigin.imported, true);
    expect(find.text('Bitcoin'), findsNothing);
  });
  testWidgets('disabled rollout hides Bitcoin even for seed wallets', (
    tester,
  ) async {
    await show(tester, WalletOrigin.derived, false);
    expect(find.text('Bitcoin'), findsNothing);
  });
}
