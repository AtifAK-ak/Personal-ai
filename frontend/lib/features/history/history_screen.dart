import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../chat/chat_message.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.messages});
  final List<ChatMessage> messages;

  String _t(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat history')),
      body: messages.isEmpty
          ? const Center(
              child: Text('No conversations yet.',
                  style: TextStyle(color: kMuted)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                return Card(
                  color: kCard,
                  child: ListTile(
                    title: Text(m.text),
                    subtitle: Text('${m.fromUser ? 'You' : 'ALEX AI'} • ${_t(m.time)}'),
                  ),
                );
              },
            ),
    );
  }
}
