import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/feedback_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uploads through the existing authenticated multipart route', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/uploads/kyc');
      expect(request.url.queryParameters['kind'], 'feedback');
      expect(request.headers['Authorization'], 'Bearer test-session');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(request.bodyBytes, containsAllInOrder([0xff, 0xd8, 0xff]));
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'url': 'https://example.com/attachment'},
        }),
        200,
      );
    });
    final service = FeedbackService(
      client: client,
      sessionToken: (_) async => 'test-session',
    );
    final result = await service.uploadAttachment(
      walletAddress: 'wallet',
      name: 'screenshot.jpg',
      bytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
    );
    expect(result.contentType, 'image/jpeg');
    expect(result.size, 3);
  });
  test('submits attachment metadata with account authentication', () async {
    const attachment = FeedbackAttachment(
      url: 'https://example.com/file',
      name: 'screenshot.png',
      contentType: 'image/png',
      size: 100,
    );
    final service = FeedbackService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/feedback/submit');
        expect(request.headers['Authorization'], 'Bearer test-session');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['attachments'], [attachment.toJson()]);
        expect(body['message'], 'Something went wrong');
        return http.Response('{}', 201);
      }),
      sessionToken: (_) async => 'test-session',
    );
    await service.submitFeedback(
      walletAddress: 'wallet',
      category: 'bug',
      message: 'Something went wrong',
      attachments: [attachment],
    );
  });
  test('accepts supported attachments up to 15 MB', () {
    expect(
      validateFeedbackFile('Screenshot.PNG', 15 * 1024 * 1024),
      'image/png',
    );
    expect(validateFeedbackFile('recording.mov', 100), 'video/quicktime');
  });
  test('rejects empty, oversized and unsupported attachments', () {
    expect(() => validateFeedbackFile('empty.png', 0), throwsFormatException);
    expect(
      () => validateFeedbackFile('big.png', 15 * 1024 * 1024 + 1),
      throwsFormatException,
    );
    expect(() => validateFeedbackFile('file.html', 100), throwsFormatException);
    expect(() => validateFeedbackFile('png', 100), throwsFormatException);
  });
  test('serializes attachment details for feedback submissions', () {
    const attachment = FeedbackAttachment(
      url: 'https://example.com/file',
      name: 'screenshot.png',
      contentType: 'image/png',
      size: 100,
    );
    expect(attachment.toJson(), {
      'url': attachment.url,
      'name': attachment.name,
      'contentType': 'image/png',
      'size': 100,
    });
  });
}
