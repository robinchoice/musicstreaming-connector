import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../features/converter/conversion.dart';
import 'messages.dart';

// Kept for the app's lifetime, so the language set by localeProvider stays
final apiProvider = Provider((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return Api(client, apiUrl);
});

/// The last failed calls, newest first. Feedback sends them along.
final recentErrors = <String>[];

void _noteError(String path, Object status) {
  recentErrors.insert(
    0,
    '${path == '/song' ? 'GET' : 'POST'} /api/v1$path → $status',
  );
  if (recentErrors.length > 5) recentErrors.removeLast();
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

/// Below the minimum build of its platform the API answers 426, see apps/api/src/app.ts.
final updateRequiredProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(apiProvider).updateRequired(),
);

Map<String, String> get _appHeaders => buildNumber == 0
    ? const {}
    : {'x-app-platform': appPlatform, 'x-app-build': '$buildNumber'};

class Api {
  final http.Client client;
  final String baseUrl;
  Api(this.client, String baseUrl)
    : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  /// Language of error texts, set by localeProvider. The API answers in it too.
  AppLocale locale = AppLocale.de;

  Map<String, String> get _headers => {
    'accept': 'application/json',
    'accept-language': locale.name,
    ..._appHeaders,
  };

  Uri _url(String path) => Uri.parse('$baseUrl/api/v1$path');

  /// Asked once at launch. Offline or failing, the app just starts.
  Future<bool> updateRequired() async {
    if (buildNumber == 0) return false;
    try {
      final response = await client
          .get(_url('/app'), headers: _appHeaders)
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 426;
    } on Exception {
      return false;
    }
  }

  Future<Song> song(String input, {String country = 'DE'}) async {
    try {
      final response = await client
          .get(
            _url('/song')
                .replace(queryParameters: {'input': input, 'country': country}),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 25));
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        _noteError('/song', response.statusCode);
        throw ApiException(
          body['error'] as String? ?? locale.messages.serviceUnavailable,
        );
      }
      return Song.fromJson(body);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(locale.messages.searchTimeout);
    } on http.ClientException {
      _noteError('/song', 'offline');
      throw ApiException(locale.messages.offline);
    } on FormatException {
      throw ApiException(locale.messages.invalidAnswer);
    } on TypeError {
      throw ApiException(locale.messages.invalidAnswer);
    }
  }

  Future<void> sendFeedback(Map<String, dynamic> body) async {
    try {
      final response = await client
          .post(
            _url('/feedback'),
            headers: {'content-type': 'application/json', ..._headers},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode >= 400) {
        String? error;
        try {
          error =
              (jsonDecode(utf8.decode(response.bodyBytes))
                      as Map<String, dynamic>)['error']
                  as String?;
        } on FormatException {
          // Not from our API, e.g. a proxy page
        }
        throw ApiException(error ?? locale.messages.serviceUnavailable);
      }
    } on TimeoutException {
      throw ApiException(locale.messages.sendTimeout);
    } on http.ClientException {
      throw ApiException(locale.messages.offline);
    }
  }
}
