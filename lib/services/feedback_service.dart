import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import 'cashin_profile_auth_service.dart';
import 'http_client_service.dart';

class FeedbackAttachment {
  const FeedbackAttachment({
    required this.url,
    required this.name,
    required this.contentType,
    required this.size,
  });
  final String url;
  final String name;
  final String contentType;
  final int size;
  Map<String, Object> toJson() => {
    'url': url,
    'name': name,
    'contentType': contentType,
    'size': size,
  };
}

const feedbackFileTypes = <String, String>{
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'pdf': 'application/pdf',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
};

String validateFeedbackFile(String name, int size) {
  final type = name.contains('.')
      ? feedbackFileTypes[name.split('.').last.toLowerCase()]
      : null;
  if (type == null) {
    throw const FormatException(
      'Choose a JPG, PNG, WEBP, PDF, MP4 or MOV file.',
    );
  }
  if (size <= 0 || size > 15 * 1024 * 1024) {
    throw const FormatException(
      'Attachments must be non-empty and 15 MB or smaller.',
    );
  }
  if (name.length > 255) {
    throw const FormatException('The file name is too long.');
  }
  return type;
}

class FeedbackService {
  FeedbackService({
    http.Client? client,
    Future<String> Function(String)? sessionToken,
  }) : _client = client ?? HttpClientService().client,
       _sessionToken =
           sessionToken ?? CashinProfileAuthService().ensureWalletSession;

  final http.Client _client;
  final Future<String> Function(String) _sessionToken;

  Future<FeedbackAttachment> uploadAttachment({
    required String walletAddress,
    required String name,
    required Uint8List bytes,
  }) async {
    final contentType = validateFeedbackFile(name, bytes.length);
    final token = await _sessionToken(walletAddress);
    final request = http.MultipartRequest(
      'POST',
      AppEnvironment.api('/uploads/kyc', {'kind': 'feedback'}),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: name),
    );
    final response = await http.Response.fromStream(
      await _client.send(request),
    ).timeout(const Duration(seconds: 60));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['message'] ?? 'Unable to upload attachment. Please try again.',
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Upload did not return a file URL.');
    }
    return FeedbackAttachment(
      url: url,
      name: name,
      contentType: contentType,
      size: bytes.length,
    );
  }

  Future<void> submitFeedback({
    required String walletAddress,
    required String category,
    required String message,
    String? subject,
    String? contactEmail,
    String? appVersion,
    String? languageCode,
    List<FeedbackAttachment> attachments = const [],
  }) async {
    final uri = AppEnvironment.feedback('/submit');
    final token = attachments.isEmpty
        ? null
        : await _sessionToken(walletAddress);
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'walletAddress': walletAddress,
            'category': category,
            'subject': subject,
            'message': message,
            'contactEmail': contactEmail,
            'appVersion': appVersion,
            'languageCode': languageCode,
            'attachments': attachments.map((file) => file.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to submit feedback');
    }
  }
}
