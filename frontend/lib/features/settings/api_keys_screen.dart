import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/backend_config.dart';
import '../../core/constants.dart';
import '../../core/key_backend.dart';
import '../../core/native_bridge.dart';
import '../../core/theme.dart';

/// Manages the API keys that live on the backend (admin endpoints).
/// Key values are never shown: the backend only returns ids and status.
class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  static const Map<String, String> _names = {
    'groq': 'Groq',
    'tavily': 'Tavily',
    'newsdata': 'Newsdata.io',
    'serp': 'Serp',
    'openweather': 'OpenWeather',
    'fish': 'Fish Audio',
  };

  final TextEditingController _admin = TextEditingController();
  final Map<String, TextEditingController> _newKey = {
    for (final k in _names.keys) k: TextEditingController(),
  };
  Map<String, dynamic>? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _admin.dispose();
    for (final c in _newKey.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _remote = false;

  Future<void> _init() async {
    final cfg = await BackendConfig.load();
    final tok = await NativeBridge.prefsGet(kPrefAdminToken);
    if (!mounted) return;
    setState(() {
      _remote = cfg != null;
      _admin.text = tok ?? '';
    });
    if (!_remote || (tok != null && tok.isNotEmpty)) await _load();
  }

  Future<KeyBackend?> _backend() async {
    if (!_remote) return LocalKeyBackend();
    final cfg = await BackendConfig.load();
    if (cfg == null) {
      _snack('Connect the backend first (Settings, Backend connection).');
      return null;
    }
    final token = _admin.text.trim();
    if (token.isEmpty) {
      _snack('Enter the admin token.');
      return null;
    }
    await NativeBridge.prefsSet(kPrefAdminToken, token);
    return RemoteKeyBackend(
        ApiClient(BackendConfig(url: cfg.url, token: token, userId: cfg.userId)));
  }

  Future<T?> _guard<T>(Future<T> Function(KeyBackend b) action) async {
    final b = await _backend();
    if (b == null) return null;
    try {
      return await action(b);
    } on ApiException catch (e) {
      _snack(e.statusCode == 401
          ? 'Wrong admin token.'
          : 'Backend error (${e.statusCode}).');
    } on Exception {
      _snack('Something went wrong. Check your internet and try again.');
    }
    return null;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _guard((b) => b.list());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (d != null) _data = d;
    });
  }

  Future<void> _addKey(String provider) async {
    final c = _newKey[provider]!;
    final value = c.text.trim();
    if (value.length < 8) {
      _snack('That key looks too short.');
      return;
    }
    final ok = await _guard((b) async {
      await b.add(provider, value);
      return true;
    });
    if (ok == true) {
      c.clear();
      _snack('Key added.');
      await _load();
    }
  }

  Future<void> _useKey(String provider, String id) async {
    final ok = await _guard((b) async {
      await b.use(provider, id);
      return true;
    });
    if (ok == true) await _load();
  }

  Future<void> _testKey(String provider, String id) async {
    final ok = await _guard((b) => b.test(provider, id));
    if (ok != null) {
      _snack(ok ? 'Key works.' : 'Key failed the test.');
      await _load();
    }
  }

  Future<void> _revokeKey(String provider, String id) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke this key?'),
        content: const Text('It will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Revoke')),
        ],
      ),
    );
    if (sure != true) return;
    final ok = await _guard((b) async {
      await b.revoke(provider, id);
      return true;
    });
    if (ok == true) await _load();
  }

  Future<void> _setAuto(bool v) async {
    final ok = await _guard((b) async {
      await b.setAuto(v);
      return true;
    });
    if (ok == true) await _load();
  }

  Widget _provider(String provider, Map<String, dynamic> info) {
    final keys = (info['keys'] as List<dynamic>? ?? []).whereType<Map<dynamic, dynamic>>().toList();
    final active = info['active'];
    final working = keys.where((k) => k['status'] == 'ok').length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_names[provider] ?? provider, style: const TextStyle(fontSize: 17)),
              const Spacer(),
              Text('$working/${keys.length} working', style: const TextStyle(color: kMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < keys.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: keys[i]['id'] == active ? kMint : kLine),
              ),
              child: Row(
                children: [
                  Text('Key ${i + 1}'),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('●●●●●●●●●●', style: TextStyle(letterSpacing: 2))),
                  Text('${keys[i]['status']}', style: const TextStyle(color: kMuted, fontSize: 12)),
                  IconButton(
                    tooltip: 'Use this key',
                    icon: Icon(keys[i]['id'] == active ? Icons.radio_button_checked : Icons.radio_button_off),
                    onPressed: () => _useKey(provider, '${keys[i]['id']}'),
                  ),
                  IconButton(
                    tooltip: 'Test',
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: () => _testKey(provider, '${keys[i]['id']}'),
                  ),
                  IconButton(
                    tooltip: 'Revoke',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _revokeKey(provider, '${keys[i]['id']}'),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newKey[provider],
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Paste a new key',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => _addKey(provider), child: const Text('Add')),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final providers = (data?['providers'] as Map<String, dynamic>?) ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('API keys')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _remote
                ? 'Keys are stored on your backend.'
                : 'No backend set: keys are stored on this phone only, and the app talks to the services directly.',
            style: const TextStyle(color: kMuted),
          ),
          const SizedBox(height: 10),
          if (_remote) ...[
            TextField(
              controller: _admin,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Admin token (ALEX_ADMIN_TOKEN)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            onPressed: _loading ? null : _load,
            child: Text(_loading ? 'Loading…' : 'Load keys'),
          ),
          const SizedBox(height: 12),
          if (data != null) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-switch'),
              subtitle: const Text('Use the next key when one runs out'),
              value: data['auto'] == true,
              onChanged: _setAuto,
            ),
            for (final name in _names.keys)
              if (providers[name] is Map<String, dynamic>)
                _provider(name, providers[name] as Map<String, dynamic>),
          ],
        ],
      ),
    );
  }
}
