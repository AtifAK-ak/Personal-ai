import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_log.dart';
import '../../core/theme.dart';

/// Shows what the app did (model checks, key failures, chat errors). No secrets.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  @override
  Widget build(BuildContext context) {
    final lines = AppLog.lines;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: lines.join('\n')));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Copied')));
            },
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(AppLog.clear),
          ),
        ],
      ),
      body: lines.isEmpty
          ? const Center(
              child: Text('Nothing logged yet.', style: TextStyle(color: kMuted)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final l in lines.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SelectableText(l, style: const TextStyle(fontSize: 13)),
                  ),
              ],
            ),
    );
  }
}
