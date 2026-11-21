import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'features/onboarding/splash_screen.dart';

class AlexApp extends StatelessWidget {
  const AlexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildAlexTheme(),
      home: const SplashScreen(),
    );
  }
}
