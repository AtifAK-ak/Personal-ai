import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/native_bridge.dart';
import '../../core/widgets/glass_orb.dart';
import '../chat/chat_screen.dart';
import 'name_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    final saved = await NativeBridge.prefsGet(kPrefUserName);
    if (!mounted) return;
    final Widget next = (saved != null && saved.trim().isNotEmpty)
        ? ChatScreen(name: saved.trim())
        : const NameScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassOrb(size: 180),
            SizedBox(height: 36),
            Text('ALEX AI', style: TextStyle(fontSize: 34, letterSpacing: 3)),
            SizedBox(height: 8),
            Text('Your personal voice assistant'),
          ],
        ),
      ),
    );
  }
}
