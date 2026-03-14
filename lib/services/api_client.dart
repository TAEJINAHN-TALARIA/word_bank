import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Base URL of the Word Bank backend.
/// 빌드 시 --dart-define=BACKEND_URL=https://your-server.com 으로 지정하세요.
/// - Android 에뮬레이터 (기본값): http://10.0.2.2:3000
/// - iOS 시뮬레이터:              flutter run --dart-define=BACKEND_URL=http://localhost:3000
/// - 프로덕션:                    flutter build apk --dart-define=BACKEND_URL=https://your-server.com
const kBackendBaseUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

class LookupResult {
  final String word;
  final String? phonetic;
  final String meaningText; // formatted string for storage
  final Map<String, dynamic> payload;

  const LookupResult({
    required this.word,
    this.phonetic,
    required this.meaningText,
    required this.payload,
  });
}

/// Calls the backend /api/lookup and returns a [LookupResult].
///
/// Throws [LookupNotFoundException] if the word is not found.
/// Throws [LookupQuotaExceededException] if the free monthly limit is reached.
/// Throws [http.ClientException] or [SocketException] on network errors.
/// Throws [Exception] on unexpected server errors.
Future<LookupResult> lookupWord({
  required String word,
  required String definitionLanguage,
  String? exampleLanguage,
}) async {
  final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

  final uri = Uri.parse('$kBackendBaseUrl/api/lookup');
  final body = <String, String>{
    'word': word,
    'language': definitionLanguage,
  };
  if (exampleLanguage != null) {
    body['exampleLanguage'] = exampleLanguage;
  }

  final headers = <String, String>{
    'Content-Type': 'application/json',
    if (idToken != null) 'Authorization': 'Bearer $idToken',
  };

  final response = await http
      .post(uri, headers: headers, body: jsonEncode(body))
      .timeout(const Duration(seconds: 15));

  final data = jsonDecode(response.body) as Map<String, dynamic>;

  if (response.statusCode == 200) {
    if (data['error'] == 'not_found') {
      throw LookupNotFoundException();
    }
    return LookupResult(
      word: data['word'] as String? ?? word,
      phonetic: data['phonetic'] as String?,
      meaningText: _formatMeanings(data),
      payload: data,
    );
  }

  if (response.statusCode == 429) {
    if (data['error'] == 'quota_exceeded') {
      throw LookupQuotaExceededException(
        count: data['count'] as int? ?? 0,
        limit: data['limit'] as int? ?? 50,
      );
    }
    throw LookupRateLimitException();
  }

  throw Exception('Server error ${response.statusCode}');
}

String _formatMeanings(Map<String, dynamic> data) {
  final meanings = data['meanings'] as List? ?? [];
  final buffer = StringBuffer();
  for (final meaning in meanings) {
    final m = meaning as Map<String, dynamic>;
    final pos = m['pos'] as String? ?? '';
    final definitions = (m['definitions'] as List?)?.cast<String>() ?? [];
    final examples = (m['examples'] as List?)?.cast<String>() ?? [];
    final synonyms = (m['synonyms'] as List?)?.cast<String>() ?? [];
    final antonyms = (m['antonyms'] as List?)?.cast<String>() ?? [];

    buffer.writeln('[$pos]');
    if (definitions.isNotEmpty) {
      for (final def in definitions) {
        buffer.writeln('- $def');
      }
    }

    if (examples.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Examples:');
      for (final ex in examples) {
        buffer.writeln('- $ex');
      }
    }

    if (synonyms.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Synonyms: ${synonyms.join(', ')}');
    }
    if (antonyms.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Antonyms: ${antonyms.join(', ')}');
    }

    buffer.writeln();
  }
  return buffer.toString().trim();
}

class LookupNotFoundException implements Exception {}

class LookupRateLimitException implements Exception {}

class LookupQuotaExceededException implements Exception {
  final int count;
  final int limit;
  const LookupQuotaExceededException({required this.count, required this.limit});
}
