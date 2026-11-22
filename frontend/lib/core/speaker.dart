import 'api_client.dart';
import 'backend_config.dart';
import 'constants.dart';
import 'direct/key_store.dart';
import 'direct/providers.dart';
import 'native_bridge.dart';

/// Speaks a reply. Uses the backend voice (Fish Audio) when it works,
/// otherwise the phone's own text-to-speech. Never throws.
class Speaker {
  Speaker._();

  static Future<void> speak(String text) async {
    try {
      if (await NativeBridge.prefsGet(kPrefSpeak) == '0') return;
      final locale = await NativeBridge.prefsGet(kPrefLocale) ?? 'en-US';
      final clipped = text.length > 500 ? text.substring(0, 500) : text;
      final cfg = await BackendConfig.load();
      if (cfg != null) {
        try {
          final voice = await NativeBridge.prefsGet(kPrefVoice) ?? 'aisha';
          final bytes = await ApiClient(cfg).tts(clipped, voice);
          if (bytes.isNotEmpty) {
            await NativeBridge.playAudio(bytes);
            return;
          }
        } on Exception {
          // fall back to the phone's own voice below
        }
      }
      if (cfg == null) {
        final store = KeyStore.instance;
        await store.load();
        if (store.hasKey('fish')) {
          try {
            final voice = await NativeBridge.prefsGet(kPrefVoice) ?? 'aisha';
            final ref = await NativeBridge.prefsGet('$kPrefVoiceRefPrefix$voice');
            final bytes = await store.call('fish', (k) => DirectProviders.fishTts(k, clipped, ref));
            if (bytes.isNotEmpty) {
              await NativeBridge.playAudio(bytes);
              return;
            }
          } on Exception {
            // fall back to the phone's own voice below
          }
        }
      }
      await NativeBridge.speak(clipped, locale);
    } on Exception {
      // speaking is optional
    }
  }
}
