import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/backend_config.dart';
import '../../core/constants.dart';
import '../../core/direct/key_store.dart';
import '../../core/direct/providers.dart';
import '../../core/native_bridge.dart';
import '../../core/theme.dart';
import '../../core/voices.dart';

/// Voice language, spoken replies on/off and the 7 voice models.
class VoiceSection extends StatefulWidget {
  const VoiceSection({super.key});

  @override
  State<VoiceSection> createState() => _VoiceSectionState();
}

class _VoiceSectionState extends State<VoiceSection> {
  static const Map<String, String> _locales = {
    'ur-PK': 'Urdu',
    'en-US': 'English',
    'hi-IN': 'Hindi',
  };

  String _locale = 'ur-PK';
  String _voice = 'aisha';
  bool _speak = true;
  final TextEditingController _ref = TextEditingController();

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await NativeBridge.prefsGet(kPrefLocale);
    final v = await NativeBridge.prefsGet(kPrefVoice);
    final s = await NativeBridge.prefsGet(kPrefSpeak);
    if (!mounted) return;
    setState(() {
      if (l != null && _locales.containsKey(l)) _locale = l;
      if (v != null && kVoices.any((x) => x.id == v)) _voice = v;
      _speak = s != '0';
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _useVoice(VoiceInfo v) async {
    setState(() => _voice = v.id);
    await NativeBridge.prefsSet(kPrefVoice, v.id);
    final cfg = await BackendConfig.load();
    if (cfg != null) {
      try {
        await ApiClient(cfg).putProfile({'voice': v.id});
      } on Exception {
        _snack('Saved on this phone, but the backend did not accept it.');
        return;
      }
    }
    _snack('${v.name} is now ALEX’s voice');
  }

  Future<void> _preview(VoiceInfo v) async {
    final cfg = await BackendConfig.load();
    try {
      if (cfg != null) {
        final bytes = await ApiClient(cfg).tts('Hello, I am ${v.name}.', v.id);
        await NativeBridge.playAudio(bytes);
        return;
      }
      final store = KeyStore.instance;
      await store.load();
      if (!store.hasKey('fish')) {
        _snack('Add a Fish Audio key (Manage API keys) to preview this voice.');
        return;
      }
      final ref = await NativeBridge.prefsGet('$kPrefVoiceRefPrefix${v.id}');
      final bytes = await store.call('fish', (k) => DirectProviders.fishTts(k, 'Hello, I am ${v.name}.', ref));
      await NativeBridge.playAudio(bytes);
    } on Exception {
      _snack('Preview failed. Check the Fish Audio key.');
    }
  }

  Future<void> _saveRef() async {
    final value = _ref.text.trim();
    if (value.isEmpty) return;
    await NativeBridge.prefsSet('$kPrefVoiceRefPrefix$_voice', value);
    _ref.clear();
    _snack('Voice ID saved for $_voice (hidden).');
  }

  Widget _card(VoiceInfo v) {
    final selected = v.id == _voice;
    final accent = v.female ? const Color(0xFFB45CFF) : const Color(0xFF2F8BFF);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _useVoice(v),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? kCyan : accent, width: 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent.withValues(alpha: 0.35), const Color(0xFF05071A)],
          ),
          boxShadow: [
            BoxShadow(
              color: (selected ? kCyan : accent).withValues(alpha: 0.4),
              blurRadius: selected ? 18 : 8,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 8,
              top: 8,
              child: Text(v.female ? '♀' : '♂', style: TextStyle(fontSize: 20, color: accent)),
            ),
            Positioned(
              right: 4,
              top: 2,
              child: IconButton(
                tooltip: 'Preview ${v.name}',
                icon: const Icon(Icons.play_circle_outline),
                onPressed: () => _preview(v),
              ),
            ),
            Center(child: Text(v.emoji, style: const TextStyle(fontSize: 54))),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Column(
                children: [
                  Text(v.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  Text('${v.female ? 'Female' : 'Male'} · ${v.trait}',
                      style: TextStyle(fontSize: 12, color: accent)),
                  Text(v.language, style: const TextStyle(fontSize: 11, color: kMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          const Text('Voice', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          DropdownButton<String>(
            value: _locale,
            isExpanded: true,
            items: [
              for (final e in _locales.entries)
                DropdownMenuItem(value: e.key, child: Text('I speak: ${e.value}')),
            ],
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _locale = v);
              await NativeBridge.prefsSet(kPrefLocale, v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Speak replies aloud'),
            value: _speak,
            onChanged: (v) async {
              setState(() => _speak = v);
              await NativeBridge.prefsSet(kPrefSpeak, v ? '1' : '0');
            },
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: [for (final v in kVoices) _card(v)],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ref,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Fish Audio voice ID for the selected voice',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _saveRef, child: const Text('Save')),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Without a Fish Audio key, replies use your phone’s own voice.',
            style: TextStyle(color: kMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
