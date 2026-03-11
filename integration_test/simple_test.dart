import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/main.dart' as app;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots', (WidgetTester tester) async {
    await app.main();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
