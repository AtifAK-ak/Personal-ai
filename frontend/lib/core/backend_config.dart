import 'dart:math';

import 'constants.dart';
import 'native_bridge.dart';

/// Backend address, app token and this device's anonymous user id.
class BackendConfig {
  const BackendConfig({
    required this.url,
    required this.token,
    required this.userId,
  });

  final String url;
  final String token;
  final String userId;

  static Future<String> userIdOrCreate() async {
    final saved = await NativeBridge.prefsGet(kPrefUserId);
    if (saved != null && saved.length >= 8) return saved;
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    final id = List.generate(24, (_) => chars[rnd.nextInt(chars.length)]).join();
    await NativeBridge.prefsSet(kPrefUserId, id);
    return id;
  }

  /// Returns null while the backend is not configured in Settings.
  static Future<BackendConfig?> load() async {
    final url = (await NativeBridge.prefsGet(kPrefBackendUrl))?.trim() ?? '';
    final token = (await NativeBridge.prefsGet(kPrefBackendToken))?.trim() ?? '';
    if (url.isEmpty || token.isEmpty) return null;
    return BackendConfig(
      url: url.endsWith('/') ? url.substring(0, url.length - 1) : url,
      token: token,
      userId: await userIdOrCreate(),
    );
  }
}
