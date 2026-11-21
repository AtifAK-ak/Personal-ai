import 'package:flutter/material.dart';

import '../../core/native_bridge.dart';
import '../../core/theme.dart';

class _Perm {
  const _Perm(this.key, this.title, this.why);
  final String key;
  final String title;
  final String why;
}

const List<_Perm> _perms = [
  _Perm('microphone', 'Microphone', 'To hear your voice commands and make recordings.'),
  _Perm('camera', 'Camera', 'To take photos when you ask.'),
  _Perm('contacts', 'Contacts', 'To find people in your contacts when you ask.'),
  _Perm('notifications', 'Notifications', 'To show status alerts and read notifications aloud.'),
];

/// Explains each permission and lets the user grant it. Nothing is requested
/// until the user taps Allow.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.onContinue});
  final void Function(BuildContext context) onContinue;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  final Map<String, bool> _granted = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    for (final p in _perms) {
      final g = await NativeBridge.permissionStatus(p.key);
      if (!mounted) return;
      setState(() => _granted[p.key] = g);
    }
  }

  Future<void> _allow(String key) async {
    await NativeBridge.permissionRequest(key);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'ALEX only asks for what a feature needs. You can change these at any time.',
                    style: TextStyle(color: kMuted),
                  ),
                  const SizedBox(height: 12),
                  for (final p in _perms)
                    Card(
                      color: kCard,
                      child: ListTile(
                        title: Text(p.title),
                        subtitle: Text(p.why),
                        trailing: (_granted[p.key] ?? false)
                            ? const Icon(Icons.check_circle, color: kMint)
                            : OutlinedButton(
                                onPressed: () => _allow(p.key),
                                child: const Text('Allow'),
                              ),
                      ),
                    ),
                  TextButton(
                    onPressed: NativeBridge.openAppSettings,
                    child: const Text('Open Android app settings'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => widget.onContinue(context),
                  child: const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
