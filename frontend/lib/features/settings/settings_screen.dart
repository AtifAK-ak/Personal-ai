import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/backend_config.dart';
import '../../core/constants.dart';
import '../../core/native_bridge.dart';
import '../../core/theme.dart';
import '../onboarding/permissions_screen.dart';
import 'api_keys_screen.dart';
import 'diagnostics_screen.dart';
import 'voice_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Map<String, String> _presets = {
    'Normal Assistant': 'Natural, respectful and helpful. Friendly but professional.',
    'Close Friend': 'Warm, casual and supportive, with a little humor.',
    'Professional Assistant': 'Formal, organized and concise.',
    'Strict Mentor': 'Honest, direct feedback focused on improvement.',
    'Custom': 'Your own instructions, written below.',
  };

  String _preset = 'Normal Assistant';
  String _userName = '';
  final TextEditingController _custom = TextEditingController();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _token = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _custom.dispose();
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await NativeBridge.prefsGet(kPrefPersonaPreset);
    final c = await NativeBridge.prefsGet(kPrefPersonaCustom);
    final n = await NativeBridge.prefsGet(kPrefUserName);
    final u = await NativeBridge.prefsGet(kPrefBackendUrl);
    final t = await NativeBridge.secureGet(kPrefBackendToken);
    if (!mounted) return;
    setState(() {
      if (p != null && _presets.containsKey(p)) _preset = p;
      _custom.text = c ?? '';
      _userName = n ?? '';
      _url.text = u ?? '';
      _token.text = t ?? '';
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _savePersona() async {
    await NativeBridge.prefsSet(kPrefPersonaPreset, _preset);
    await NativeBridge.prefsSet(kPrefPersonaCustom, _custom.text);
    final cfg = await BackendConfig.load();
    if (cfg == null) {
      _snack('Saved on this phone. Connect the backend to use it.');
      return;
    }
    try {
      await ApiClient(cfg).putProfile({
        if (_userName.isNotEmpty) 'name': _userName,
        'persona_preset': _preset,
        'persona_custom': _custom.text,
      });
      _snack('Saved');
    } on Exception {
      _snack('Saved on this phone, but the backend did not accept it.');
    }
  }

  Future<void> _resetPersona() async {
    setState(() {
      _preset = 'Normal Assistant';
      _custom.clear();
    });
    await _savePersona();
  }

  Future<void> _saveBackend() async {
    await NativeBridge.prefsSet(kPrefBackendUrl, _url.text.trim());
    await NativeBridge.secureSet(kPrefBackendToken, _token.text.trim());
    _snack('Backend settings saved');
  }

  Future<void> _testBackend() async {
    await _saveBackend();
    final cfg = await BackendConfig.load();
    if (cfg == null) {
      _snack('Enter the backend address and token first');
      return;
    }
    try {
      final r = await ApiClient(cfg).health();
      _snack('Backend is reachable (${r['status']})');
    } on ApiException catch (e) {
      _snack('Backend answered with an error (${e.statusCode})');
    } on Exception {
      _snack('Could not reach the backend');
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('About', [
            Text('Owner: $kOwnerName'),
            const SizedBox(height: 4),
            Text('Your name: ${_userName.isEmpty ? '—' : _userName}'),
          ]),
          _section('AI Customization', [
            DropdownButton<String>(
              value: _preset,
              isExpanded: true,
              items: [
                for (final p in _presets.keys)
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _preset = v);
              },
            ),
            Text(_presets[_preset] ?? '', style: const TextStyle(color: kMuted)),
            const SizedBox(height: 10),
            TextField(
              controller: _custom,
              enabled: _preset == 'Custom',
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Write how ALEX should talk and behave with you…',
                border: OutlineInputBorder(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                      onPressed: _resetPersona, child: const Text('Reset')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                      onPressed: _savePersona, child: const Text('Save')),
                ),
              ],
            ),
          ]),
          const VoiceSection(),
          _section('Backend connection', [
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Backend address (https://…)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _token,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'App token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                      onPressed: _saveBackend, child: const Text('Save')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                      onPressed: _testBackend, child: const Text('Test')),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Optional: only needed if you host the backend yourself. Without it the app works directly from your phone.',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ]),
          _section('API keys', [
            const Text(
              'Add, test, revoke and switch the Groq, Tavily, Newsdata, Serp, OpenWeather and Fish Audio keys. '
              'Stored on this phone (or on your backend if you set one) and shown as dots.',
              style: TextStyle(color: kMuted),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ApiKeysScreen()),
              ),
              child: const Text('Manage API keys'),
            ),
          ]),
          _section('Diagnostics', [
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen()),
              ),
              child: const Text('View error log'),
            ),
          ]),
          _section('Permissions', [
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PermissionsScreen(
                    onContinue: (ctx) => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
              child: const Text('Manage permissions'),
            ),
          ]),
        ],
      ),
    );
  }
}
