import 'dart:convert';
import 'dart:math';

import '../app_log.dart';
import '../native_bridge.dart';

class QuotaException implements Exception {
  const QuotaException({this.cooldown = 3600, this.permanent = false});
  final int cooldown;
  final bool permanent;
}

class ProviderException implements Exception {
  const ProviderException(this.status, [this.detail = '']);
  final int status;
  final String detail;

  @override
  String toString() => 'ProviderException($status) $detail';
}

class KeyUnavailableException implements Exception {
  const KeyUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _Entry {
  _Entry(this.id, this.key, this.status, this.until);
  final String id;
  final String key;
  String status; // ok | cooling | invalid
  int until;

  Map<String, Object?> toJson() =>
      {'id': id, 'key': key, 'status': status, 'until': until};

  static _Entry fromJson(Map<dynamic, dynamic> j) => _Entry(
        '${j['id']}',
        '${j['key']}',
        '${j['status']}',
        (j['until'] as num?)?.toInt() ?? 0,
      );
}

/// Keys kept on this phone (private app storage) when no backend is used.
/// Several keys per provider, automatic failover and manual switching.
class KeyStore {
  KeyStore._();
  static final KeyStore instance = KeyStore._();

  static const List<String> providers = [
    'groq', 'tavily', 'newsdata', 'serp', 'openweather', 'fish',
  ];
  static const String _prefKey = 'direct_keys';

  bool auto = true;
  bool _loaded = false;
  final Map<String, List<_Entry>> _keys = {
    for (final p in providers) p: <_Entry>[],
  };
  final Map<String, String?> _active = {};
  final Map<String, int> _calls = {for (final p in providers) p: 0};
  final Map<String, int> _fails = {for (final p in providers) p: 0};

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await NativeBridge.secureGet(_prefKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      auto = d['auto'] != false;
      final ps = d['providers'] as Map<String, dynamic>? ?? {};
      for (final p in providers) {
        final e = ps[p];
        if (e is Map) {
          _active[p] = e['active'] as String?;
          _keys[p] = [
            for (final k in (e['keys'] as List<dynamic>? ?? []))
              if (k is Map) _Entry.fromJson(k),
          ];
        }
      }
    } catch (_) {
      // unreadable store: start empty
    }
  }

  Future<void> _save() async {
    final data = {
      'auto': auto,
      'providers': {
        for (final p in providers)
          p: {
            'active': _active[p],
            'keys': [for (final e in _keys[p]!) e.toJson()],
          },
      },
    };
    await NativeBridge.secureSet(_prefKey, jsonEncode(data));
  }

  String _newId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  bool hasKey(String provider) =>
      (_keys[provider] ?? []).any((e) => e.status != 'invalid');

  Future<String> add(String provider, String key) async {
    await load();
    final e = _Entry(_newId(), key.trim(), 'ok', 0);
    _keys[provider]!.add(e);
    _active[provider] ??= e.id;
    await _save();
    return e.id;
  }

  Future<void> revoke(String provider, String id) async {
    await load();
    final list = _keys[provider]!;
    list.removeWhere((e) => e.id == id);
    if (_active[provider] == id) {
      _active[provider] = list.isEmpty ? null : list.first.id;
    }
    await _save();
  }

  Future<void> setActive(String provider, String id) async {
    await load();
    if (_keys[provider]!.any((e) => e.id == id)) {
      _active[provider] = id;
      await _save();
    }
  }

  Future<void> setAuto(bool v) async {
    await load();
    auto = v;
    await _save();
  }

  Future<void> mark(String provider, String id, bool ok) async {
    for (final e in _keys[provider]!) {
      if (e.id == id) {
        e.status = ok ? 'ok' : 'invalid';
        e.until = 0;
      }
    }
    await _save();
  }

  String? keyFor(String provider, String id) {
    for (final e in _keys[provider]!) {
      if (e.id == id) return e.key;
    }
    return null;
  }

  /// Ids, status and counters only. Key values are never exposed here.
  Map<String, dynamic> listing() => {
        'auto': auto,
        'providers': {
          for (final p in providers)
            p: {
              'active': _active[p],
              'calls': _calls[p],
              'failures': _fails[p],
              'keys': [
                for (final e in _keys[p]!) {'id': e.id, 'status': e.status},
              ],
            },
        },
      };

  bool _live(_Entry e, int now) {
    if (e.status == 'ok') return true;
    if (e.status == 'cooling' && now >= e.until) {
      e.status = 'ok';
      return true;
    }
    return false;
  }

  _Entry? _pick(String provider, Set<String> tried) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final keys = _keys[provider]!;
    if (!auto) {
      for (final e in keys) {
        if (e.id == _active[provider] && !tried.contains(e.id) && _live(e, now)) {
          return e;
        }
      }
      return null;
    }
    var start = keys.indexWhere((e) => e.id == _active[provider]);
    if (start < 0) start = 0;
    for (var i = 0; i < keys.length; i++) {
      final e = keys[(start + i) % keys.length];
      if (!tried.contains(e.id) && _live(e, now)) {
        _active[provider] = e.id;
        return e;
      }
    }
    return null;
  }

  Future<T> call<T>(String provider, Future<T> Function(String key) fn) async {
    await load();
    final tried = <String>{};
    while (true) {
      final e = _pick(provider, tried);
      if (e == null) {
        final cooling = (_keys[provider] ?? []).any((k) => k.status == 'cooling');
        throw KeyUnavailableException((_keys[provider] ?? []).isEmpty
            ? 'No $provider key yet. Add one in Settings, Manage API keys.'
            : cooling
                ? 'The $provider key is rate-limited or out of quota right now. Wait a minute or add another key.'
                : 'Your $provider key was rejected. Press Test in Manage API keys, or add another key.');
      }
      _calls[provider] = (_calls[provider] ?? 0) + 1;
      try {
        return await fn(e.key);
      } on QuotaException catch (q) {
        _fails[provider] = (_fails[provider] ?? 0) + 1;
        e.status = q.permanent ? 'invalid' : 'cooling';
        e.until = DateTime.now().millisecondsSinceEpoch + q.cooldown * 1000;
        tried.add(e.id);
        AppLog.add('$provider key ${e.id} marked ${e.status}');
        await _save();
        if (!auto) {
          throw KeyUnavailableException(
              'The $provider key failed. Switch to another key in Settings.');
        }
      }
    }
  }
}
