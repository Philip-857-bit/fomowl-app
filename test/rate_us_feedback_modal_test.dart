import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/widgets/rate_us_feedback_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'feedback form offers optional attachments and validates the message',
    (tester) async {
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => RateUsFeedbackModal(
                    onRateNow: () async {},
                    onMaybeLater: () async {},
                    onClose: () async {},
                    onSubmitFeedback: (_, _) async {
                      submitted = true;
                    },
                  ),
                ),
                child: const Text('Open Feedback'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Feedback'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send Feedback'));
      await tester.tap(find.text('Send Feedback'));
      await tester.pumpAndSettle();
      expect(find.text('Attach screenshot or file'), findsOneWidget);
      expect(find.textContaining('15 MB each'), findsOneWidget);
      await tester.ensureVisible(find.text('Send'));
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your feedback message.'), findsOneWidget);
      expect(submitted, isFalse);
    },
  );

  testWidgets(
    'RateUsFeedbackModal renders 5 gold rating stars and handles interaction',
    (tester) async {
      bool rated = false;
      bool maybeLater = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => RateUsFeedbackModal(
                        onRateNow: () async => rated = true,
                        onMaybeLater: () async => maybeLater = true,
                        onClose: () async {},
                        onSubmitFeedback: (_, _) async {},
                      ),
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Heading and text
      expect(find.text('Enjoying Owllet?'), findsOneWidget);
      expect(
        find.textContaining("We'd love to hear your feedback"),
        findsOneWidget,
      );

      // Verify the 5 Gold Rating Stars
      // There are 5 stars in the rating row + 1 star in the 'Rate us Now' button = 6 total star icons
      final starIcons = find.byIcon(Icons.star_rounded);
      expect(starIcons, findsNWidgets(6));

      // Buttons
      expect(find.text('Rate us Now'), findsOneWidget);
      expect(find.text('Maybe Later'), findsOneWidget);
      expect(find.text('Send Feedback'), findsOneWidget);

      // Tap 'Rate us Now'
      await tester.tap(find.text('Rate us Now'));
      await tester.pumpAndSettle();
      expect(rated, isTrue);
      expect(maybeLater, isFalse);
    },
  );
}
