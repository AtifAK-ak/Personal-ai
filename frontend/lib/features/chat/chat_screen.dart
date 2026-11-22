import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/backend_config.dart';
import '../../core/constants.dart';
import '../../core/direct/direct_brain.dart';
import '../../core/direct/key_store.dart';
import '../../core/native_bridge.dart';
import '../../core/speaker.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_orb.dart';
import '../commands/command_parser.dart';
import '../commands/command_runner.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.name});
  final String name;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  final List<ChatMessage> _archive = [];
  bool _busy = false;
  bool _listening = false;
  bool _connected = false;

  static const List<(String, String, String)> _suggestions = [
    ('🔦', 'Flashlight on', 'Turn on the flashlight'),
    ('🔋', 'Battery', 'What is my battery level?'),
    ('🔊', 'Volume up', 'Increase the volume'),
    ('🕘', 'Time and date', 'What time is it?'),
  ];

  @override
  void initState() {
    super.initState();
    _checkBackend();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkBackend() async {
    final cfg = await BackendConfig.load();
    final direct = await DirectBrain.available();
    if (!mounted) return;
    setState(() => _connected = cfg != null || direct);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    final userMsg = ChatMessage(text, fromUser: true, time: DateTime.now());
    setState(() {
      _messages.add(userMsg);
      _archive.add(userMsg);
      _busy = true;
    });

    final reply = await _reply(text);
    if (!mounted) return;
    final aiMsg = ChatMessage(reply, fromUser: false, time: DateTime.now());
    setState(() {
      _messages.add(aiMsg);
      _archive.add(aiMsg);
      _busy = false;
    });
    Speaker.speak(reply);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String> _finish(Map<String, dynamic> r) async {
    var reply = (r['reply'] as String?) ?? '';
    final action = r['device_action'];
    if (action is Map<String, dynamic>) {
      final cmd = CommandParser.fromAction(action);
      if (cmd != null) {
        final res = await CommandRunner.run(cmd);
        reply = reply.isEmpty ? res.message : '$reply\n${res.message}';
      }
    }
    return reply.isEmpty ? '…' : reply;
  }

  Future<String> _reply(String text) async {
    final local = CommandParser.parse(text);
    if (local != null) return (await CommandRunner.run(local)).message;

    try {
      final cfg = await BackendConfig.load();
      if (cfg != null) return await _finish(await ApiClient(cfg).chat(text));
      if (await DirectBrain.available()) {
        return await _finish(await DirectBrain.chat(text, userName: widget.name));
      }
    } on KeyUnavailableException catch (e) {
      return e.message;
    } on Exception {
      return 'Could not reach the AI. Check your internet connection and your keys in Settings.';
    }
    return 'Hello ${widget.name}! My AI brain is not connected yet. '
        'For now I can run device commands. Add your Groq key in Settings, Manage API keys, to chat with the AI.';
  }

  Future<void> _listen() async {
    if (_listening) {
      await NativeBridge.stopListening();
      return;
    }
    await NativeBridge.stopSpeaking();
    if (!await NativeBridge.permissionStatus('microphone')) {
      final ok = await NativeBridge.permissionRequest('microphone');
      if (!ok) {
        _snack('Microphone permission is needed to hear you.');
        return;
      }
    }
    final locale = await NativeBridge.prefsGet(kPrefLocale) ?? 'en-US';
    if (!mounted) return;
    setState(() => _listening = true);
    try {
      final text = await NativeBridge.listen(locale);
      if (text.trim().isNotEmpty) await _send(text);
    } on PlatformException catch (e) {
      _snack(e.message ?? 'Could not listen');
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    await _checkBackend();
  }

  void _menu(String v) {
    if (v == 'settings') {
      _openSettings();
    } else if (v == 'history') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => HistoryScreen(messages: List.of(_archive))),
      );
    } else if (v == 'new') {
      setState(() => _messages.clear());
    }
  }

  Widget _welcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _listen,
            child: GlassOrb(size: 170, listening: _listening),
          ),
          const SizedBox(height: 18),
          Text('Welcome, ${widget.name}!',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            _listening
                ? 'Listening… speak now'
                : 'I’m Alex, your personal assistant. Tap the orb and talk.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          const Text('What can I help you with today?',
              style: TextStyle(fontSize: 18, color: kMint)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              for (final s in _suggestions)
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _send(s.$3),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kLine),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.$1, style: const TextStyle(fontSize: 22)),
                        const Spacer(),
                        Text(s.$2, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    return Align(
      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: m.fromUser ? kCard : const Color(0xFF241A5C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: m.fromUser ? kLine : const Color(0xFF5A3FD0)),
        ),
        child: Text(m.text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GlassOrb(size: 30, listening: _listening),
            const SizedBox(width: 12),
            const Text('Alex AI'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => _menu('new'),
          ),
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => _menu('history'),
          ),
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'history', child: Text('Chat history')),
              PopupMenuItem(value: 'new', child: Text('New chat')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_connected)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'AI brain not connected · add your Groq key in Settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFF0A24A), fontSize: 12.5),
                ),
              ),
            Expanded(
              child: _messages.isEmpty
                  ? _welcome()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _bubble(_messages[i]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: _send,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Message ALEX…',
                        filled: true,
                        fillColor: kCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(color: kLine),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: _listening ? 'Stop listening' : 'Speak',
                    onPressed: _listen,
                    icon: Icon(_listening ? Icons.stop_circle : Icons.mic,
                        color: _listening ? Colors.redAccent : kCyan),
                  ),
                  IconButton.filled(
                    onPressed: _busy ? null : () => _send(_input.text),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
