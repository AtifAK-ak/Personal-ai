import 'package:alex_ai/core/direct/key_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fails over to the next key when one is out of quota', () async {
    final s = KeyStore.instance;
    await s.load();
    await s.add('groq', 'aaaaaaaa1');
    await s.add('groq', 'bbbbbbbb2');
    final used = <String>[];
    final r = await s.call<String>('groq', (k) async {
      used.add(k);
      if (k == 'aaaaaaaa1') throw const QuotaException();
      return 'ok';
    });
    expect(r, 'ok');
    expect(used, ['aaaaaaaa1', 'bbbbbbbb2']);
    expect(s.listing().toString().contains('aaaaaaaa1'), isFalse);
  });

  test('no key means unavailable', () async {
    final s = KeyStore.instance;
    await s.load();
    expect(
      () => s.call<String>('tavily', (k) async => 'x'),
      throwsA(isA<KeyUnavailableException>()),
    );
  });
}
