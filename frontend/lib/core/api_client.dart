import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'backend_config.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// Talks to the FastAPI backend over HTTPS. See docs/API.md.
class ApiClient {
  ApiClient(this.config);
  final BackendConfig config;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Object? body,
  ]) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.openUrl(method, Uri.parse('${config.url}$path'));
      req.headers.set('Authorization', 'Bearer ${config.token}');
      req.headers.set('X-User-Id', config.userId);
      req.headers.contentType = ContentType.json;
      if (body != null) req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(const Duration(seconds: 60));
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode >= 400) throw ApiException(res.statusCode, text);
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// Generic call, used by the admin screen.
  Future<Map<String, dynamic>> request(String method, String path, [Object? body]) =>
      _request(method, path, body);

  Future<Map<String, dynamic>> health() => _request('GET', '/health');

  Future<Map<String, dynamic>> chat(String message) =>
      _request('POST', '/chat', {'message': message});

  Future<Map<String, dynamic>> putProfile(Map<String, Object?> profile) =>
      _request('PUT', '/user/profile', profile);

  /// Returns MP3 bytes for [text] in the given backend voice id.
  Future<Uint8List> tts(String text, String voice) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.openUrl('POST', Uri.parse('${config.url}/tts'));
      req.headers.set('Authorization', 'Bearer ${config.token}');
      req.headers.set('X-User-Id', config.userId);
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode({'text': text, 'voice': voice})));
      final res = await req.close().timeout(const Duration(seconds: 60));
      if (res.statusCode >= 400) {
        throw ApiException(res.statusCode, 'tts failed');
      }
      return await consolidateHttpClientResponseBytes(res);
    } finally {
      client.close();
    }
  }
}
