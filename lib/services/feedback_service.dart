import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';

class FeedbackService {
  Future<void> submitFeedback({
    required String walletAddress,
    required String category,
    required String message,
    String? subject,
    String? contactEmail,
    String? appVersion,
    String? languageCode,
  }) async {
    final uri = AppEnvironment.feedback('/submit');
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
