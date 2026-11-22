import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'key_store.dart';

const String kGroqModel =
    String.fromEnvironment('GROQ_MODEL', defaultValue: 'llama-3.3-70b-versatile');
const String kFishModel =
    String.fromEnvironment('FISH_MODEL', defaultValue: 's2.1-pro');

/// Direct calls from the phone to the services (used when no backend is set).
class DirectProviders {
  DirectProviders._();

  static Future<(int, Uint8List)> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.openUrl(method, uri);
      for (final e in headers.entries) {
        req.headers.set(e.key, e.value);
      }
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(const Duration(seconds: 40));
      return (res.statusCode, await consolidateHttpClientResponseBytes(res));
    } finally {
      client.close();
    }
  }

  static void _check(int status) {
    if (status == 401 || status == 403) throw const QuotaException(permanent: true);
    if (status == 402) throw const QuotaException(cooldown: 6 * 3600);
    if (status == 429) throw const QuotaException(cooldown: 120);
    if (status >= 400) throw ProviderException(status);
  }

  static String _clip(Object? v, int n) {
    final s = '${v ?? ''}';
    return s.length <= n ? s : s.substring(0, n);
  }

  static Map<String, dynamic> _json(Uint8List b) =>
      jsonDecode(utf8.decode(b)) as Map<String, dynamic>;

  static Future<String> groqChat(
    String key,
    List<Map<String, String>> messages, {
    bool json = false,
  }) async {
    final (status, bytes) = await _send(
      'POST',
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {'Authorization': 'Bearer $key'},
      body: {
        'model': kGroqModel,
        'messages': messages,
        'temperature': 0.6,
        if (json) 'response_format': {'type': 'json_object'},
      },
    );
    _check(status);
    final choices = _json(bytes)['choices'] as List<dynamic>;
    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>;
    return (message['content'] as String?) ?? '';
  }

  static Future<bool> _groqModels(String key) async {
    final (status, _) = await _send('GET', Uri.parse('https://api.groq.com/openai/v1/models'),
        headers: {'Authorization': 'Bearer $key'});
    _check(status);
    return true;
  }

  static Future<Map<String, Object?>> tavily(String key, String query) async {
    final (status, bytes) = await _send(
      'POST',
      Uri.parse('https://api.tavily.com/search'),
      headers: {'Authorization': 'Bearer $key'},
      body: {'query': query, 'max_results': 4, 'include_answer': true},
    );
    _check(status);
    final d = _json(bytes);
    final results = (d['results'] as List<dynamic>? ?? []).whereType<Map<dynamic, dynamic>>();
    return {
      'answer': d['answer'],
      'results': [
        for (final r in results.take(4))
          {
            'title': r['title'],
            'url': r['url'],
            'content': _clip(r['content'], 300),
          },
      ],
    };
  }

  static Future<List<Map<String, Object?>>> serp(String key, String query) async {
    final (status, bytes) = await _send(
        'GET', Uri.https('serpapi.com', '/search.json', {'q': query, 'api_key': key}));
    _check(status);
    final results = (_json(bytes)['organic_results'] as List<dynamic>? ?? [])
        .whereType<Map<dynamic, dynamic>>();
    return [
      for (final r in results.take(4))
        {'title': r['title'], 'url': r['link'], 'content': r['snippet']},
    ];
  }

  static Future<bool> _serpAccount(String key) async {
    final (status, _) =
        await _send('GET', Uri.https('serpapi.com', '/account.json', {'api_key': key}));
    _check(status);
    return true;
  }

  static Future<List<Map<String, Object?>>> newsdata(
      String key, String query, String language) async {
    final (status, bytes) = await _send(
      'GET',
      Uri.https('newsdata.io', '/api/1/latest', {
        'apikey': key,
        'language': language,
        if (query.isNotEmpty) 'q': query,
      }),
    );
    _check(status);
    final results = (_json(bytes)['results'] as List<dynamic>? ?? [])
        .whereType<Map<dynamic, dynamic>>();
    return [
      for (final r in results.take(5)) {'title': r['title'], 'source': r['source_id']},
    ];
  }

  static Future<Map<String, Object?>> weather(String key, String city) async {
    final (status, bytes) = await _send(
      'GET',
      Uri.https('api.openweathermap.org', '/data/2.5/weather',
          {'q': city, 'appid': key, 'units': 'metric'}),
    );
    if (status == 404) throw const ProviderException(404);
    _check(status);
    final d = _json(bytes);
    final main = (d['main'] as Map<dynamic, dynamic>?) ?? {};
    final wind = (d['wind'] as Map<dynamic, dynamic>?) ?? {};
    final w = (d['weather'] as List<dynamic>? ?? []);
    return {
      'city': d['name'],
      'temp_c': main['temp'],
      'feels_like_c': main['feels_like'],
      'humidity': main['humidity'],
      'wind_m_s': wind['speed'],
      'description': w.isNotEmpty && w.first is Map ? (w.first as Map)['description'] : null,
    };
  }

  static Future<Uint8List> fishTts(String key, String text, String? referenceId) async {
    final (status, bytes) = await _send(
      'POST',
      Uri.parse('https://api.fish.audio/v1/tts'),
      headers: {'Authorization': 'Bearer $key', 'model': kFishModel},
      body: {
        'text': text,
        'format': 'mp3',
        if (referenceId != null && referenceId.isNotEmpty) 'reference_id': referenceId,
      },
    );
    _check(status);
    return bytes;
  }

  /// Cheap live check of one key. True when the key works.
  static Future<bool> probe(String provider, String key) async {
    try {
      switch (provider) {
        case 'groq':
          return await _groqModels(key);
        case 'tavily':
          await tavily(key, 'test');
          return true;
        case 'newsdata':
          await newsdata(key, 'test', 'en');
          return true;
        case 'serp':
          return await _serpAccount(key);
        case 'openweather':
          await weather(key, 'London');
          return true;
        case 'fish':
          await fishTts(key, 'Hi', null);
          return true;
        default:
          return false;
      }
    } on Exception {
      return false;
    }
  }
}
