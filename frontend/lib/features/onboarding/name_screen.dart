import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/native_bridge.dart';
import '../../core/widgets/glass_orb.dart';
import '../chat/chat_screen.dart';
import 'permissions_screen.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    await NativeBridge.prefsSet(kPrefUserName, n);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PermissionsScreen(
          onContinue: (ctx) => Navigator.of(ctx).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => ChatScreen(name: n)),
            (route) => false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GlassOrb(size: 110),
              const SizedBox(height: 28),
              const Text('What should I call you?',
                  style: TextStyle(fontSize: 24)),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                textAlign: TextAlign.center,
                onSubmitted: (_) => _next(),
                decoration: const InputDecoration(
                  hintText: 'Your name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: _next, child: const Text('Continue')),
            ],
          ),
        ),
      ),
    );
  }
}
