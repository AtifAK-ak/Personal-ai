import 'dart:convert';

import '../constants.dart';
import '../native_bridge.dart';
import '../persona.dart';
import 'key_store.dart';
import 'providers.dart';

/// The assistant's brain running on the phone (no backend). Same logic as the
/// backend /chat: one LLM call picks an intent, data is fetched, a second call answers.
class DirectBrain {
  DirectBrain._();

  static const String _kMemory = 'direct_memory';
  static const String _kHistory = 'direct_history';

  static Future<bool> available() async {
    await KeyStore.instance.load();
    return KeyStore.instance.hasKey('groq');
  }

  static Future<List<dynamic>> _readList(String key) async {
    final raw = await NativeBridge.prefsGet(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final d = jsonDecode(raw);
      return d is List ? d : [];
    } catch (_) {
      return [];
    }
  }

  static Map<String, dynamic> _parse(String text) {
    dynamic data;
    try {
      data = jsonDecode(text);
    } catch (_) {
      final a = text.indexOf('{');
      final b = text.lastIndexOf('}');
      if (a != -1 && b > a) {
        try {
          data = jsonDecode(text.substring(a, b + 1));
        } catch (_) {
          data = null;
        }
      }
    }
    if (data is Map<String, dynamic>) return data;
    return {'intent': 'chat', 'reply': text.trim()};
  }

  static Future<Map<String, Object?>?> _gather(
    KeyStore s,
    String intent,
    Map<String, dynamic> plan,
  ) async {
    if (intent == 'weather') {
      final city = '${plan['city'] ?? ''}'.trim();
      if (city.isEmpty) return null;
      return {'weather': await s.call('openweather', (k) => DirectProviders.weather(k, city))};
    }
    final query = '${plan['query'] ?? ''}'.trim();
    if (intent == 'news') {
      final lang = ['en', 'ur', 'hi'].contains(plan['language']) ? '${plan['language']}' : 'en';
      return {'news': await s.call('newsdata', (k) => DirectProviders.newsdata(k, query, lang))};
    }
    if (query.isEmpty) return null;
    try {
      return {'search': await s.call('tavily', (k) => DirectProviders.tavily(k, query))};
    } on KeyUnavailableException {
      return {'search': await s.call('serp', (k) => DirectProviders.serp(k, query))};
    }
  }

  /// Returns {reply, device_action} like the backend.
  static Future<Map<String, dynamic>> chat(String message, {required String userName}) async {
    final store = KeyStore.instance;
    await store.load();
    final memory = (await _readList(_kMemory)).map((e) => '$e').toList();
    final history = (await _readList(_kHistory))
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => {'role': '${m['role']}', 'content': '${m['content']}'})
        .toList();
    final preset = await NativeBridge.prefsGet(kPrefPersonaPreset) ?? 'Normal Assistant';
    final custom = await NativeBridge.prefsGet(kPrefPersonaCustom) ?? '';

    final system = buildSystemPrompt(
      owner: kOwnerName,
      userName: userName,
      preset: preset,
      custom: custom,
      memory: memory,
    );
    final recent = history.length > 10 ? history.sublist(history.length - 10) : history;
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
      ...recent,
      {'role': 'user', 'content': message},
    ];

    final raw = await store.call('groq', (k) => DirectProviders.groqChat(k, messages, json: true));
    final plan = _parse(raw);
    var intent = '${plan['intent']}';
    if (!['chat', 'weather', 'news', 'search', 'device'].contains(intent)) intent = 'chat';
    var reply = '${plan['reply'] ?? ''}'.trim();
    Map<String, dynamic>? device;
    if (intent == 'device' && plan['device'] is Map) {
      device = Map<String, dynamic>.from(plan['device'] as Map);
    }

    if (intent == 'weather' || intent == 'news' || intent == 'search') {
      Map<String, Object?>? found;
      try {
        found = await _gather(store, intent, plan);
      } on Exception {
        reply = 'I could not fetch that information right now.';
      }
      if (found != null) {
        final plainSystem = buildSystemPrompt(
          owner: kOwnerName,
          userName: userName,
          preset: preset,
          custom: custom,
          memory: memory,
          plain: true,
        );
        final follow = <Map<String, String>>[
          {'role': 'system', 'content': plainSystem},
          {
            'role': 'user',
            'content': '$message\n\nUse only this data to answer briefly:\n${jsonEncode(found)}',
          },
        ];
        try {
          final r2 = await store.call('groq', (k) => DirectProviders.groqChat(k, follow));
          if (r2.trim().isNotEmpty) reply = r2.trim();
        } on Exception {
          // keep the first reply
        }
      }
    }

    final facts = plan['remember'];
    if (facts is List) {
      for (final f in facts.take(3)) {
        final s = '$f'.trim();
        if (s.isNotEmpty && s.length <= 200 && !memory.contains(s)) memory.add(s);
      }
    }
    final newHistory = [
      ...history,
      {'role': 'user', 'content': message},
      {'role': 'assistant', 'content': reply},
    ];
    await NativeBridge.prefsSet(
      _kHistory,
      jsonEncode(newHistory.length > 20 ? newHistory.sublist(newHistory.length - 20) : newHistory),
    );
    await NativeBridge.prefsSet(
      _kMemory,
      jsonEncode(memory.length > 100 ? memory.sublist(memory.length - 100) : memory),
    );
    return {'reply': reply, 'device_action': device};
  }
}
