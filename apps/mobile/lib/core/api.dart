import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../features/converter/conversion.dart';

final apiProvider = Provider.autoDispose((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return Api(client, apiUrl);
});

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  final http.Client client;
  final String baseUrl;
  Api(this.client, this.baseUrl);

  Future<Conversion> convert(
    String input, {
    String target = 'appleMusic',
    String country = 'DE',
  }) async {
    try {
      final response = await client
          .post(
            Uri.parse(
              '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1/convert',
            ),
            headers: {
              'content-type': 'application/json',
              'accept': 'application/json',
            },
            body: jsonEncode({
              'input': input,
              'target': target,
              'country': country,
            }),
          )
          .timeout(const Duration(seconds: 25));
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw ApiException(
          body['error'] as String? ?? 'Der Dienst ist gerade nicht erreichbar.',
        );
      }
      return Conversion.fromJson(body);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'Die Suche dauert zu lange. Versuche es erneut.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Keine Verbindung zum Server. Versuche es erneut.',
      );
    } on FormatException {
      throw const ApiException(
        'Der Dienst hat eine ungültige Antwort gesendet.',
      );
    } on TypeError {
      throw const ApiException(
        'Der Dienst hat eine ungültige Antwort gesendet.',
      );
    }
  }
}
