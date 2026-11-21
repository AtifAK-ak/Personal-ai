import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/backend_config.dart';
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

  static const List<(String, String, String)> _suggestions = [
    ('🔦', 'Flashlight on', 'Turn on the flashlight'),
    ('🌑', 'Flashlight off', 'Turn off the flashlight'),
    ('🔊', 'Volume up', 'Increase the volume'),
    ('🔉', 'Volume down', 'Decrease the volume'),
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
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

  Future<String> _reply(String text) async {
    final local = CommandParser.parse(text);
    if (local != null) return (await CommandRunner.run(local)).message;

    final cfg = await BackendConfig.load();
    if (cfg == null) {
      return 'Hello ${widget.name}! My AI brain is not connected yet. '
          'For now I can run device commands. Add the backend address and token '
          'in Settings to chat with the AI.';
    }
    try {
      final r = await ApiClient(cfg).chat(text);
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
    } on Exception {
      return 'Could not reach the backend. Check the address and token in Settings.';
    }
  }

  void _menu(String v) {
    if (v == 'settings') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );
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
          const GlassOrb(size: 150),
          const SizedBox(height: 18),
          Text('Welcome, ${widget.name}!',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'I’m Alex, your intelligent personal assistant.',
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
        title: const Row(
          children: [
            GlassOrb(size: 30),
            SizedBox(width: 12),
            Text('Alex AI'),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Demo mode · AI, search, news and weather are not connected yet',
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
                  const SizedBox(width: 8),
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
