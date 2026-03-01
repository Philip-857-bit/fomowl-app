import 'dart:convert';

import 'package:http/http.dart' as http;

class FeedbackService {
  static const String _baseUrl = 'https://fomowl-backend.onrender.com/api/feedback';

  Future<void> submitFeedback({
    required String walletAddress,
    required String category,
    required String message,
    String? subject,
    String? contactEmail,
    String? appVersion,
    String? languageCode,
  }) async {
    final uri = Uri.parse('$_baseUrl/submit');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'walletAddress': walletAddress,
            'category': category,
            'subject': subject,
            'message': message,
            'contactEmail': contactEmail,
            'appVersion': appVersion,
            'languageCode': languageCode,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to submit feedback');
    }
  }
}
