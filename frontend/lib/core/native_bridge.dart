import 'dart:typed_data';

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

  // ---- voice ---------------------------------------------------------
  static Future<String> listen(String locale) async =>
      await _call<String>('speech.listen', {'locale': locale}) ?? '';

  static Future<void> stopListening() async {
    await _call<bool>('speech.stop');
  }

  static Future<void> speak(String text, String lang) async {
    await _call<bool>('tts.speak', {'text': text, 'lang': lang});
  }

  static Future<void> playAudio(Uint8List bytes) async {
    await _call<bool>('audio.play', {'bytes': bytes});
  }

  static Future<void> stopSpeaking() async {
    await _call<bool>('audio.stop');
  }

  // ---- device --------------------------------------------------------
  static Future<Map<dynamic, dynamic>?> battery() =>
      _call<Map<dynamic, dynamic>>('device.battery');

  static Future<bool> openPanel(String name) async =>
      await _call<bool>('device.panel', {'name': name}) ?? false;

  static Future<bool> mediaKey(String action) async =>
      await _call<bool>('media.key', {'action': action}) ?? false;

  static Future<bool> openCamera() async =>
      await _call<bool>('camera.open') ?? false;

  static Future<bool> openMaps(String query, {bool navigate = false}) async =>
      await _call<bool>('maps.open', {'query': query, 'navigate': navigate}) ?? false;

  static Future<bool> webSearch(String query) async =>
      await _call<bool>('web.search', {'query': query}) ?? false;

  static Future<List<Map<String, String>>> searchContacts(String query) async {
    final raw = await _call<List<dynamic>>('contacts.search', {'query': query});
    if (raw == null) return [];
    return [
      for (final e in raw)
        if (e is Map)
          {
            'name': (e['name'] ?? '').toString(),
            'number': (e['number'] ?? '').toString(),
          },
    ];
  }

  static Future<bool> dial(String number) async =>
      await _call<bool>('contacts.dial', {'number': number}) ?? false;

  /// action: start | stop | pause | resume. start/stop return the file path.
  static Future<String?> record(String action) async {
    final r = await _call<Object>('record.$action');
    return r is String ? r : null;
  }
}
