import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../app_log.dart';
import 'groq_policy.dart';
import 'key_store.dart';

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
        final data = utf8.encode(jsonEncode(body));
        req.headers.contentType = ContentType.json;
        req.contentLength = data.length;
        req.add(data);
      }
      final res = await req.close().timeout(const Duration(seconds: 40));
      return (res.statusCode, await consolidateHttpClientResponseBytes(res));
    } finally {
      client.close();
    }
  }

  /// Key problems (401/403 invalid key, 402/429 quota or rate limit) are handled by
  /// key rotation and never by switching models.
  static void _keyErrors(int status) {
    if (status == 401 || status == 403) throw const QuotaException(permanent: true);
    if (status == 402) throw const QuotaException(cooldown: 6 * 3600);
    if (status == 429) throw const QuotaException(cooldown: 120);
  }

  static void _check(int status, [Uint8List? body]) {
    _keyErrors(status);
    if (status >= 400) throw ProviderException(status, _detail(body));
  }

  /// Pulls the human-readable message out of an error response.
  static String _detail(Uint8List? body) {
    if (body == null || body.isEmpty) return '';
    try {
      final d = jsonDecode(utf8.decode(body));
      if (d is Map) {
        final e = d['error'];
        if (e is Map && e['message'] != null) return _clip(e['message'], 160);
        if (d['message'] != null) return _clip(d['message'], 160);
      }
    } catch (_) {
      // not JSON
    }
    return '';
  }

  static String _clip(Object? v, int n) {
    final s = '${v ?? ''}';
    return s.length <= n ? s : s.substring(0, n);
  }

  static Map<String, dynamic> _json(Uint8List b) =>
      jsonDecode(utf8.decode(b)) as Map<String, dynamic>;

  static const String _groqBase = 'https://api.groq.com/openai/v1';
  static String? _model;
  static bool _jsonOk = true;

  static Map<String, String> _auth(String key) => {'Authorization': 'Bearer $key'};

  /// (code, message) from an error response.
  static (String, String) _errorInfo(Uint8List bytes) {
    try {
      final d = jsonDecode(utf8.decode(bytes));
      if (d is Map && d['error'] is Map) {
        final e = d['error'] as Map<dynamic, dynamic>;
        return ('${e['code'] ?? ''}', _clip(e['message'], 300));
      }
    } catch (_) {
      // not JSON
    }
    return ('', _clip(utf8.decode(bytes, allowMalformed: true), 200));
  }

  static String _content(Uint8List bytes) {
    final choices = _json(bytes)['choices'] as List<dynamic>;
    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>;
    return (message['content'] as String?) ?? '';
  }

  /// Model ids this key can use, or null when the list cannot be read.
  static Future<Set<String>?> _availableModels(String key) async {
    final (status, bytes) =
        await _send('GET', Uri.parse('$_groqBase/models'), headers: _auth(key));
    _keyErrors(status);
    if (status >= 400) return null;
    return (_json(bytes)['data'] as List<dynamic>? ?? [])
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => '${m['id']}')
        .toSet();
  }

  /// Real chat completion in JSON mode. null = the model works.
  static Future<ModelProblem?> _validate(String key, String model) async {
    final (status, bytes) = await _send(
      'POST',
      Uri.parse('$_groqBase/chat/completions'),
      headers: _auth(key),
      body: {
        'model': model,
        'messages': [
          {'role': 'system', 'content': 'Reply with a JSON object.'},
          {'role': 'user', 'content': 'Return {"ok": true} as JSON.'},
        ],
        'temperature': 0,
        'response_format': {'type': 'json_object'},
      },
    );
    _keyErrors(status);
    if (status == 200) {
      try {
        return jsonDecode(_content(bytes)) is Map ? null : ModelProblem.json;
      } catch (_) {
        return ModelProblem.json;
      }
    }
    final (code, msg) = _errorInfo(bytes);
    final kind = GroqPolicy.classify(status, code, msg);
    if (kind != null) return kind;
    throw ProviderException(status, msg);
  }

  /// Primary first, then the backup. The order of the /models list is never used.
  static Future<void> _select(String key) async {
    final available = await _availableModels(key);
    final candidates =
        kGroqModels.where((m) => available == null || available.contains(m)).toList();
    if (candidates.isEmpty) {
      throw ProviderException(
          0, 'None of ${kGroqModels.join(', ')} is available for this key.');
    }
    String? jsonFallback;
    for (final m in candidates) {
      final problem = await _validate(key, m);
      AppLog.add('Groq model check $m: ${problem?.name ?? 'ok'}');
      if (problem == null) {
        _model = m;
        _jsonOk = true;
        return;
      }
      if (problem == ModelProblem.json) jsonFallback ??= m;
    }
    if (jsonFallback != null) {
      AppLog.add('No Groq model passed the JSON test; using $jsonFallback without JSON mode');
      _model = jsonFallback;
      _jsonOk = false;
      return;
    }
    throw const ProviderException(0, 'No configured Groq model passed the availability check.');
  }

  static Future<String> groqChat(
    String key,
    List<Map<String, String>> messages, {
    bool json = false,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (_model == null) await _select(key);
      final (status, bytes) = await _send(
        'POST',
        Uri.parse('$_groqBase/chat/completions'),
        headers: _auth(key),
        body: {
          'model': _model!,
          'messages': messages,
          'temperature': 0.6,
          if (json && _jsonOk) 'response_format': {'type': 'json_object'},
        },
      );
      _keyErrors(status);
      if ((status == 400 || status == 404) && attempt == 0) {
        final (code, msg) = _errorInfo(bytes);
        final kind = GroqPolicy.classify(status, code, msg);
        if (kind != null) {
          AppLog.add('Groq model $_model rejected (${kind.name}): $msg');
          _model = null;
          continue;
        }
      }
      _check(status, bytes);
      return _content(bytes);
    }
    throw const ProviderException(0, 'Groq model selection failed.');
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
