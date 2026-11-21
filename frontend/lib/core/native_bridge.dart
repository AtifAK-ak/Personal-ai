import 'package:flutter/services.dart';

/// Single entry point to the Kotlin layer (channel "alex/native").
/// See docs/NATIVE_CHANNEL.md. If the native side is missing (for example in
/// unit tests) the calls return null/false instead of crashing.
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _ch = MethodChannel('alex/native');

  static Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    }
  }

  static Future<String> ping() async =>
      await _call<String>('ping') ?? 'Native layer not available';

  static Future<bool> flashlight(bool on) async =>
      await _call<bool>('flashlight', {'on': on}) ?? false;

  /// action: up | down | mute | unmute | set. Returns the media volume in percent.
  static Future<int?> volume(String action, {int? percent}) => _call<int>(
        'volume',
        {'action': action, if (percent != null) 'percent': percent},
      );

  /// Opens an installed app by name. Returns the app's label.
  static Future<String?> openApp(String name) =>
      _call<String>('app.open', {'name': name});

  static Future<String?> prefsGet(String key) =>
      _call<String>('prefs.get', {'key': key});

  static Future<void> prefsSet(String key, String value) async {
    await _call<bool>('prefs.set', {'key': key, 'value': value});
  }

  static Future<bool> permissionStatus(String name) async =>
      await _call<bool>('permission.status', {'name': name}) ?? false;

  static Future<bool> permissionRequest(String name) async =>
      await _call<bool>('permission.request', {'name': name}) ?? false;

  static Future<void> openAppSettings() async {
    await _call<bool>('permission.openSettings');
  }
}
