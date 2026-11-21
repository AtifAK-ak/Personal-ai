import 'package:alex_ai/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash is shown, then the name prompt', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('alex/native'),
      (MethodCall call) async => null,
    );

    await tester.pumpWidget(const AlexApp());
    expect(find.text('ALEX AI'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('What should I call you?'), findsOneWidget);
  });
}
